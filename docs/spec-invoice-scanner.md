# Spec — App iOS de escaneo de facturas DGI para análisis de gastos

> Nota de terminología: "Material Design" es el sistema de diseño de Android/Google. Para iOS usamos **Human Interface Guidelines (HIG)** de Apple — SwiftUI con componentes nativos (listas, navegación, Swift Charts), sin librerías de UI de terceros. Es la referencia de diseño para todo este documento.
>
> Nota de idioma: la prosa de este spec está en español, pero todo identificador de código Swift (clases, propiedades, funciones, casos de enum) está en inglés, siguiendo `CLAUDE.md`. Los términos del dominio DGI sin equivalente real en inglés (CUFE, RUC, ITBMS, ISC, DGI) se mantienen tal cual.

## 1. Objetivo

App iOS (Swift) que escanea facturas electrónicas de Panamá (sistema DGI/SFEP), extrae los datos estructurados, los guarda localmente, y permite analizar gastos dentro de la app — con exportación opcional a Excel/OneDrive para quien lo quiera.

**Principios de diseño que gobiernan todas las decisiones de este documento:**
- **Local-first.** El núcleo de la app funciona sin ninguna cuenta externa. Todo lo demás es opcional, encima de esa base.
- **Sin IA, sin servidor propio.** No hay backend del desarrollador en ningún punto del pipeline. Categorización manual, no automática.
- **Barebones.** Preferir la solución más simple que resuelve el problema real, no la más "completa".
- Esto además tiene una consecuencia legal deliberada: al no haber backend centralizando datos de otros usuarios, el desarrollador nunca es "responsable del tratamiento" bajo la Ley 81 de Panamá — cada usuario es dueño de su propio dato local y de su propia cuenta de nube si la conecta.

---

## 2. Arquitectura en capas

```
Escanear QR / CUFE manual / gasto manual
              ↓
   Parsear (DGI) o construir registro manual
              ↓
   Guardar en SwiftData ← ÚNICO paso obligatorio (tronco)
              ↓
   ┌──────────┼──────────────┬────────────────────┐
   ↓          ↓               ↓                    ↓
Capa 1     Capa 0          Capa 2               Capa 3
(ver en    (backup local   (exportar a          (sync automático
la app,    automático,     archivo elegido      a OneDrive, opcional,
completa   silencioso,     por el usuario,       requiere login MS;
por sí     sin cuenta)     manual, append-only)  incluye respaldo
sola)                                            manual reusando
                                                  la misma conexión)
```

- **Capa 1** y **Capa 0** son parte del núcleo — no requieren ninguna cuenta ni configuración.
- **Capa 2** y **Capa 3** son interruptores independientes entre sí, no secuenciales. Un usuario puede activar cualquier combinación, ninguna, o todas.
- Todas leen del mismo SwiftData como única fuente de verdad. Ninguna capa "de destino" es fuente de verdad de nada.

---

## 3. Modelo de datos (SwiftData)

### 3.1 Entidad principal: `Expense`

Unifica facturas DGI y gastos manuales bajo un mismo modelo. **La llave primaria es un `UUID` generado en el dispositivo, no el CUFE** — porque los gastos manuales no tienen CUFE.

```swift
@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var cufe: String?              // nil if manual expense; unique when present (see 6. deduplication)
    var documentType: String       // "INVOICE" | "UNSUPPORTED" (mapped from DGI's literal "FACTURA" text during parsing; see 7)
    var referencedCufe: String?    // for credit notes: CUFE of the invoice being voided/reduced (partial support, see 7)

    var issueDate: Date?
    var authorizationDate: Date?

    var issuerRuc: String?
    var issuerName: String         // written directly by the user for manual expenses
    var invoiceNumber: String?

    var items: [InvoiceItem]       // empty for simple manual expenses

    var totalAmount: Decimal
    var totalItbms: Decimal
    var paymentMethod: String?
    var totalPaid: Decimal?

    var category: String?          // inherited from Merchant by RUC, or set directly for manual expenses

    var source: ExpenseSource      // .dgi | .manual
    var scanDate: Date             // local timestamp of when this was saved in the app

    // Layer 2 state (manual export)
    var layer2ExportedAt: Date?

    // Layer 3 state (OneDrive sync)
    var layer3SyncState: SyncState
}

enum ExpenseSource: String, Codable {
    case dgi
    case manual
}

enum SyncState: String, Codable {
    case pending
    case synced
    case modifiedLocally
}
```

### 3.2 Entidad de línea de ítem: `InvoiceItem`

```swift
@Model
final class InvoiceItem {
    var lineNumber: Int
    var code: String?
    var itemDescription: String
    var quantity: Decimal
    var unitPrice: Decimal
    var unitDiscount: Decimal
    var amount: Decimal
    var itbms: Decimal
    var isc: Decimal?
    var freight: Decimal?
    var insurance: Decimal?
    var total: Decimal
}
```

### 3.3 Entidad de negocio: `Merchant`

Tabla de categorización manual, independiente de las facturas — vive por RUC, no por factura.

```swift
@Model
final class Merchant {
    @Attribute(.unique) var ruc: String
    var name: String
    var category: String?   // nil = sin categorizar, aparece en la pantalla de pendientes
}
```

Cuando se guarda un `Expense` con un `issuerRuc` que no existe todavía en `Merchant`, se crea automáticamente con `category = nil`.

### 3.4 Cola offline: `PendingLookup`

```swift
@Model
final class PendingLookup {
    var cufe: String
    var firstAttemptDate: Date
    var attemptCount: Int
}
```

### 3.5 Borrados pendientes en OneDrive: `PendingRemoteDeletion`

```swift
@Model
final class PendingRemoteDeletion {
    var expenseId: UUID
}
```

Un `Expense` siempre se borra en duro del almacenamiento local. Si `layer3EverConnected` es `true`, además se crea un `PendingRemoteDeletion` con el `id` del gasto borrado, para que el sync (sección 13.3) elimine el archivo remoto. Si es `false`, no se crea nada.

`layer3EverConnected` es un `Bool` en `UserDefaults` que pasa a `true` en el primer login exitoso y nunca se borra: ni al desconectar ni al cambiar de cuenta. Así, quien nunca conectó OneDrive no acumula registros que no se van a procesar.

### 3.6 Nota sobre CloudKit

Se evaluó sincronizar SwiftData vía CloudKit como mecanismo de backup universal, y se descartó a favor de reusar la conexión de la Capa 3 para el respaldo manual (ver sección 13.4) — decisión explícita del usuario. **No está en el alcance de este spec.** Si en el futuro se reconsidera, la restricción a tener en cuenta es que todos los campos del modelo tendrían que ser opcionales o con valor por defecto (requisito de cómo CloudKit resuelve conflictos) — no aplica al modelo tal como está descrito arriba.

---

## 4. Pipeline de captura (tres vías, sin OCR ni fotos)

```
1. Escanear QR (vía principal)
      ↓ falla / dañado / no disponible
2. CUFE manual (el usuario teclea el código)
      ↓ no hay factura del todo (comercio informal, no dio factura)
3. Gasto manual completo (sin CUFE)
```

**No hay OCR ni fotos de facturas en el diseño.** Se descartó deliberadamente:
- El QR no se degrada por el tamaño del ticket (un súper con 60 ítems tiene el mismo QR pequeño que un ticket de 2 ítems) — el problema de "factura larga" no existe en la vía principal.
- Los fallbacks 2 y 3 ya cubren el 100% de los casos donde el QR falla, sin necesitar interpretar texto libre con IA.
- Evita mandar fotos de facturas a servicios externos (privacidad) y evita la complejidad de reconocer decenas de layouts de recibo distintos sin IA.
- Consecuencia directa: no hay ningún dato de imagen que proteger ni que declarar en las políticas de privacidad de las tiendas.

### 4.1 Vía 1 — Escaneo QR

- `VisionKit` con `DataScannerViewController` (iOS 16+) para escaneo en vivo desde cámara.
- Para facturas compartidas como PDF (correo, descarga): `PDFKit` renderiza la página a `CGImage`, luego `Vision` con `VNDetectBarcodesRequest` lee el QR desde esa imagen. Mismo código de extracción de CUFE en ambos casos.
- Del contenido del QR se extrae únicamente el parámetro `chFE` (el CUFE). **Los parámetros `jwt` y `digestValue` se descartan** — confirmado que el endpoint corto (`/Consultas/FacturasPorCUFE/{cufe}`) devuelve exactamente el mismo HTML que la URL completa del QR, sin necesitarlos.

### 4.2 Vía 2 — CUFE manual

Pantalla simple con un campo de texto (máx. 66 caracteres) + botón "Consultar". Corre la misma validación y el mismo pipeline de parseo que la Vía 1, saltándose solo el paso de lectura del QR.

### 4.3 Vía 3 — Gasto manual completo

Formulario simple: nombre del negocio (texto libre, o seleccionar uno existente de `Merchant` si coincide), monto total, fecha, categoría, método de pago (directo, sin pasar por RUC ya que no hay RUC). Se guarda como `Expense` con `source = .manual`, `cufe = nil`, `items = []`.

Método de pago para gastos manuales es una selección de una lista fija (`ManualPaymentMethod`): Efectivo, Tarjeta, Transferencia, Yappy, Banca en línea, Otro — no texto libre. `Expense.paymentMethod` sigue siendo `String?` porque el parser DGI llena ese mismo campo con texto tomado del HTML (5.6); el enum solo restringe lo que el usuario puede teclear a mano.

A diferencia de las vías 1 y 2 (datos de la DGI, se asumen correctos), un gasto manual lo tecleó el usuario y puede tener errores — por eso es el único tipo de `Expense` editable después de guardado. La edición es campo por campo desde el detalle del gasto (pantalla 2, sección 15) cuando `cufe == nil` — nombre, fecha de pago, monto, categoría y método de pago se editan cada uno por separado, con su propio ícono y su propio banner de confirmación (sección 15) — no reabriendo el formulario completo de vía 3, que queda solo para crear. No pasa por la verificación blanda de duplicados (6.2) al editar.

### 4.4 Confirmación antes de guardar (vías 1 y 2)

Después de un parseo exitoso, antes de insertar el `Expense`, se muestra una pantalla de revisión con los datos parseados (negocio, RUC, ítems, totales) y un campo para asignarle un alias al negocio (con sugerencias de `Merchant` existentes por RUC o nombre). El usuario confirma o descarta — nada se guarda automáticamente. Vía 3 no necesita esto porque ya es un formulario que se revisa antes de tocar Guardar.

---

## 5. Parseo DGI

### 5.1 Endpoint

```
GET https://dgi-fep.mef.gob.pa/Consultas/FacturasPorCUFE/{cufe}
```

Confirmado con pruebas reales (fixtures adjuntas a este spec, ver sección 16): no requiere JWT, no requiere el reCAPTCHA que sí protege el formulario web normal (ese reCAPTCHA es solo del lado del flujo de UI — el botón "Consultar" tiene `class="g-recaptcha"` — no del endpoint GET directo). **Esto es un comportamiento no garantizado del servidor, no una API documentada — puede cambiar sin aviso.**

### 5.2 Validación local (antes de cualquier request)

El regex real que usa la propia DGI en la validación de su formulario, expuesto en el HTML (atributo `data-val-regex-pattern` del input `CUFE`):

```
^(FE[0-9]{2}[1-2]{1}([0-9A-Z]|[-]){20}-[0-9A-Z]{6}([12]\d{3}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01]))\d{13}0[1-4]{1}[1-2]{1}\d{10})$
```

Longitud fija: 66 caracteres (`maxlength="66"`, `data-val-length="66"`). Si el CUFE no pasa esta validación, **no se hace ningún request de red** — estado `.invalidFormat` inmediato.

### 5.3 El HTML es estático (server-rendered)

Confirmado con pruebas reales — todo el contenido viene en el `GET` inicial, sin JS asíncrono cargando el detalle (el flujo AJAX con `OnSuccessBuscar` solo aplica al formulario interactivo de búsqueda; la respuesta del endpoint por path ya trae el HTML embebido dentro de `#facturaHTML`). `URLSession` + **SwiftSoup** (paquete SPM) alcanza. No se necesita `WKWebView`.

### 5.4 Selectores — Patrón A: pares dt/dd

Dentro de `dl.dl-vertical`, pares `<dt class="small">ETIQUETA</dt><dd>VALOR</dd>`. Se busca el `dt` por texto y se toma el `dd` inmediatamente siguiente.

**El texto del `dt` es literal del sitio de la DGI, en español — no se traduce, tiene que coincidir exactamente con lo que aparece en el HTML real.**

| Campo (`Expense`) | Texto del `dt` a buscar (literal, DGI) | Dónde |
|---|---|---|
| `documentType` | — | `<h4><strong>` dentro del panel superior (dice "FACTURA" en una factura válida) |
| `invoiceNumber` | — | `<h5>` con el texto "No. {numero}" en el mismo panel superior |
| `cufe` | "CÓDIGO ÚNICO DE FACTURA ELECTRÓNICA [CUFE]" | Panel superior |
| `authorizationDate` | "FECHA AUTORIZACIÓN" | Panel superior |
| `issuerRuc` | "RUC" | Panel "EMISOR" |
| (DV, no persistido) | "DV" | Panel "EMISOR" |
| `issuerName` | "NOMBRE" | Panel "EMISOR" |
| (dirección, no persistida) | "DIRECCIÓN" | Panel "EMISOR" |
| (teléfono, no persistido) | "TELÉFONO" | Panel "EMISOR" |

### 5.5 Selectores — Patrón B: tabla de ítems

`#detalle table tbody tr`, celdas identificadas por **el atributo `data-title`, nunca por el texto del `<th>` del encabezado** — no coinciden.

⚠️ **Trampa confirmada**: el header dice "Precio Unitario" pero `data-title="Precio"`. Dice "Descuento Unitario" pero `data-title="Descuento"`. Y el más importante: **dice "ITBMS" en el header pero `data-title="Impuesto"`**. Mapear por header en vez de por `data-title` produce un `nil` silencioso justo en el campo de impuesto.

| Campo (`InvoiceItem`) | `data-title` real (literal, DGI) |
|---|---|
| `lineNumber` | `Linea` |
| `code` | `Código` |
| `itemDescription` | `Descripción` |
| `quantity` | `Cantidad` |
| `unitPrice` | `Precio` |
| `unitDiscount` | `Descuento` |
| `amount` | `Monto` |
| `itbms` | `Impuesto` |
| `isc` | `ISC` |
| `freight` | `Acarreo` |
| `insurance` | `Seguro` |
| `total` | `Total` |

### 5.6 Selectores — Patrón C: totales del footer

Texto plano dentro de `<td>`, sin `dt`/`data-title`, con un `<div>` inline al lado: `Valor Total: <div>12.10</div>`. Se busca el `<td>` cuyo texto empiece con el label y se lee el `<div>` anidado.

| Label a buscar (prefijo literal, DGI) | Campo (`Expense`) |
|---|---|
| "Descuentos:" | (descuento total, no persistido) |
| "Valor Total:" | `totalAmount` |
| "ITBMS Total:" | `totalItbms` |
| "Efectivo:" (o el método presente) | indica `paymentMethod` + su monto |
| "TOTAL PAGADO:" | `totalPaid` |
| "Vuelto:" | (no persistido) |

`paymentMethod` no tiene valor propio en el HTML — se infiere por cuál fila de método aparece con monto (solo se ha confirmado el caso "Efectivo" en la fixture real; no hay ejemplo capturado todavía de una factura pagada con tarjeta — revisar cuando aparezca un caso real).

### 5.7 Tabla de estados / decisión

| Condición | Estado resultante | Acción |
|---|---|---|
| CUFE no pasa el regex de 5.2 | `.invalidFormat` | No se hace request. Mostrar error inmediato al usuario. |
| Request OK, pero `#detalle` no aparece en el HTML (`#facturaHTML` vacío) | `.notFound` | Cubre tanto "CUFE no existe" como "CUFE con formato válido pero inexistente" — confirmado con las fixtures que el servidor devuelve exactamente el mismo HTML vacío en ambos casos (probado con un CUFE de 66 caracteres válido en formato pero con un dígito alterado, y con un CUFE de solo 3 caracteres). Indistinguibles, tratar como un solo estado. |
| Request OK, `#detalle` presente, pero tipo de documento ≠ "FACTURA" | `.unsupported` | Cubre notas de crédito y otros tipos. Si se logra extraer `referencedCufe`, ofrecer al usuario la acción manual de marcar/eliminar la factura original relacionada (ver sección 7). |
| Request OK, `#detalle` presente, tipo = "FACTURA" | éxito | Parsear normal con 5.4/5.5/5.6. |
| Error de red (timeout, sin conexión, DNS) | `.networkError` | Va a la cola offline (sección 8), **no** activa ningún fallback de parseo. |

---

## 6. Deduplicación

### 6.1 Facturas DGI (con CUFE)

`cufe` tiene restricción de unicidad en el modelo. **Antes de crear un `Expense` nuevo con CUFE, buscar si ya existe un registro con ese mismo CUFE.** Si existe, no crear uno nuevo — mostrar el existente. Esto es necesario precisamente porque la llave primaria es `UUID` (para acomodar gastos manuales) y no bloquea duplicados por nombre de archivo como en un diseño anterior descartado (ver 13.3).

### 6.2 Gastos manuales y CUFE manual repetido por error

No hay identificador único posible aquí. Verificación blanda: mismo `issuerRuc`/`issuerName` + misma fecha + mismo monto total → mostrar aviso "esto se parece a un gasto que ya tienes, ¿lo agregas igual?" — nunca bloquear silenciosamente, podría ser una compra real coincidente.

---

## 7. Notas de crédito — soporte parcial (límite conocido de v1)

El sistema DGI emite las devoluciones/anulaciones como un tipo de documento separado ("Nota de Crédito"), con su propio CUFE, que referencia el CUFE de la factura original. **No hay un HTML real de una nota de crédito capturado todavía para confirmar los selectores exactos** — cuando se consiga uno (la próxima devolución real), revisar y actualizar esta sección.

Comportamiento v1: cualquier documento cuyo tipo no sea "FACTURA" cae en `.unsupported` (ver 5.7). Si el parser logra identificar un CUFE de referencia en ese HTML (`referencedCufe`), se ofrece al usuario la opción manual de marcar la factura original como reembolsada o eliminarla — pero no hay soporte automático de resta de montos en v1.

---

## 8. Cola offline

Cuando una consulta a la DGI falla por error de red (no por CUFE inválido/inexistente), el CUFE se guarda en `PendingLookup` en vez de perderse.

**Reintento**: no usar `BGTaskScheduler` (poco confiable, oportunista según decisión de Apple/batería). En su lugar:
- Revisar conectividad **cada vez que la app vuelve a primer plano** (`scenePhase == .active` o equivalente) — si hay red, reintentar automáticamente todos los `PendingLookup`.
- Botón manual "Reintentar ahora" en una pantalla de "Pendientes", como respaldo.

Al resolver exitosamente, se crea el `Expense` correspondiente (pasando por la deduplicación de la sección 6 y el registro de `Merchant` de la sección 9) y se borra el `PendingLookup`. A diferencia de las vías 1 y 2 en su flujo interactivo, esto **no** pasa por la pantalla de revisión de 4.4 — el reintento corre en segundo plano, sin garantía de que el usuario esté mirando la pantalla en ese momento. El `Merchant` sí se crea igual, para poder categorizarlo y ponerle alias después desde su detalle o desde "Negocios sin categorizar".

---

## 9. Categorización

**Sin IA, sin servidor.** Puramente manual, basada en la tabla `Merchant` (sección 3.3):

1. Al guardar un `Expense` con `issuerRuc` nuevo, se crea automáticamente un `Merchant` con `category = nil`.
2. Pantalla "Negocios sin categorizar": lista de `Merchant` con `category == nil`, el usuario le asigna categoría (texto libre o de una lista corta que el usuario mismo mantiene). Incluye también los `Expense` manuales (`cufe == nil`) sin categoría propia — un gasto manual nunca crea un `Merchant`, así que sin esto no aparecería en ningún lado para recordarle al usuario categorizarlo.
3. Todos los `Expense` de ese RUC heredan la categoría a partir de ahí (vía join, no se duplica el dato en cada factura — `Expense.category` se resuelve leyendo `Merchant.category` por `issuerRuc`; para gastos manuales sin RUC, se asigna directo en `Expense.category`).
4. La categoría también se puede corregir desde el detalle de un gasto (pantalla 2, sección 15) — si el gasto tiene RUC, el cambio aplica a `Merchant.category` y por lo tanto a todas sus facturas a la vez, no solo a la que se está viendo.
5. Las gráficas de la Capa 1 agrupan por esta categoría. Lo no categorizado cae en un bucket "Sin categorizar" hasta que el usuario lo arregle.

### 9.1 Alias del negocio (nombre visible)

El `NOMBRE` que trae la factura de la DGI es la razón social registrada en el RUC, que muchas veces no coincide con el nombre comercial que el usuario reconoce (ej. un negocio operado bajo el RUC de una inmobiliaria distinta). `Merchant` tiene un campo opcional `alias`, editable por el usuario; toda la UI muestra `alias ?? name` en vez del `NOMBRE` crudo de la DGI.

---

## 10. Capa 0 — Backup local automático (silencioso, todos)

- Un archivo CSV completo (mismo esquema de la sección 11) en la carpeta `Documents` propia de la app.
- `UIFileSharingEnabled = true` en `Info.plist` — así aparece solo en la app Files (`En mi iPhone`) y al conectar por cable a una Mac, sin que el usuario tenga que exportar nada.
- Se **regenera completo** (no append) después de cada guardado nuevo — el costo es insignificante porque son registros de texto (~1KB por factura), no fotos.
- Objetivo: sobrevivir a un cambio de teléfono donde el usuario configura "como nuevo" en vez de restaurar backup (pasa seguido) — cosa que el backup normal de iCloud/iTunes no garantiza cubrir.
- Distinto de la Capa 2: esta no requiere ninguna interacción del usuario, siempre vive en el mismo lugar fijo.
- No se excluye del backup estándar de iOS/iCloud (decisión consciente: el riesgo de perder el historial financiero pesa más que el riesgo marginal de seguridad de un backup cifrado de Apple).

---

## 11. Esquema CSV (congelado — cualquier cambio requiere versionado, ver 11.1)

Una fila por ítem (denormalizado), con los campos de cabecera repetidos en cada línea para que no haga falta un join en Excel/Power Query. Los nombres de columna son los mismos identificadores en inglés usados en el modelo (sección 3); los campos a nivel de ítem llevan el prefijo `item` para no chocar con los campos a nivel de factura.

| Columna | Ejemplo | Notas |
|---|---|---|
| `id` | UUID | |
| `cufe` | FE0120...746379 | vacío en gastos manuales |
| `documentType` | INVOICE | |
| `issueDate` | 19/09/2026 | |
| `authorizationDate` | 19/09/2026 14:52:59 | vacío en gastos manuales |
| `issuerRuc` | 2029164-1-744562 | vacío en gastos manuales |
| `issuerName` | JV PANAMA S.A. | |
| `category` | Comida | resuelto vía `Merchant`, o directo si es manual |
| `invoiceNumber` | 0000074637 | |
| `lineNumber` | 1 | 1 fila fija si es gasto manual sin ítems |
| `itemCode` | 248 | |
| `itemDescription` | Cafe Americano 12 Oz | |
| `quantity` | 2.00 | |
| `unitPrice` | 3.35 | |
| `unitDiscount` | 0.00 | |
| `itemAmount` | 6.70 | |
| `itemItbms` | 0.00 | |
| `itemTotal` | 6.70 | |
| `totalAmount` | 12.10 | |
| `totalItbms` | 0.00 | |
| `paymentMethod` | Efectivo | |
| `totalPaid` | 20.10 | |
| `source` | dgi | dgi \| manual |
| `scanDate` | timestamp local | |
| `referencedCufe` | (vacío en v1) | reservado para notas de crédito, sección 7 |

### 11.1 Versionado de esquema

Constante `schemaVersion: Int` en código. Se guarda junto con cada archivo (bookmark de Capa 2, o metadata local) la versión con la que fue creado. Si no coincide con la constante actual al momento de escribir:
- **Se regenera el archivo completo desde SwiftData** (misma función que usa la Capa 0).
- **No** se resetea el estado de exportación (`layer2ExportedAt` / `layer3SyncState`) — son dos operaciones independientes. Regenerar el archivo no borra el registro de qué ya se sincronizó, porque la regeneración ya reflejó todo correctamente desde la fuente de verdad.

---

## 12. Capa 2 — Exportación manual a archivo elegido por el usuario

1. Primera exportación: `UIDocumentPickerViewController` (modo exportar) — el usuario elige dónde guardar (Files local, iCloud Drive, cualquier proveedor montado como Files provider).
2. Se guarda un **security-scoped bookmark** (`URL.bookmarkData`) persistido (ej. `UserDefaults`) para poder re-escribir sin volver a pedir permiso.
3. Exportaciones siguientes: **append**, no dump completo — solo se agregan los `Expense` donde `layer2ExportedAt == nil`. Al escribir con éxito, se marca `layer2ExportedAt = Date()` en esos registros.
4. Formato: CSV (no `.xlsx` real — no hay librería madura en Swift para escribir xlsx con formato; CSV lo abre cualquier programa sin fricción).
5. **Manejo de bookmark inválido**: se deja fallar el `try` de resolución/escritura de forma natural (no verificar existencia por adelantado en cada exportación). En el `catch`, mostrar primero un aviso corto ("No encontramos tu archivo anterior, elige dónde guardar") y **después** el picker — nunca mostrar el picker sin contexto, se ve como un bug.

```swift
func exportExpenses() {
    do {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
        guard url.startAccessingSecurityScopedResource() else { throw ExportError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        let handle = try FileHandle(forWritingTo: url)
        handle.seekToEndOfFile()
        // if the file is empty, write the header first
        // write new rows (layer2ExportedAt == nil)
        handle.closeFile()
        // mark layer2ExportedAt = Date() on the exported records
    } catch {
        showReconnectionNotice()
        showDocumentPicker()
    }
}
```

---

## 13. Capa 3 — Sync opcional a OneDrive (requiere login Microsoft)

### 13.1 Prerequisito manual (no es código)

Registrar la app en **Microsoft Entra** (portal entra.microsoft.com). La cuenta Microsoft personal del desarrollador ya traía un tenant por defecto (Default Directory), sin suscripción de Azure ni tarjeta. Verificado el 2026-10-06; es comportamiento de Microsoft que puede cambiar. Tipo de cuenta soportada: solo cuentas personales de Microsoft (authority `consumers`). Nombre de la app: `Cuentas Claras`, fijo antes del primer uso porque determina el nombre de la carpeta en el OneDrive del usuario.

### 13.2 Auth

- **MSAL para iOS**, scope `Files.ReadWrite.AppFolder` (reemplaza `Files.ReadWrite`).
- Flujo **PKCE, sin client secret embebido** en el binario (los SDKs móviles de Microsoft/Google soportan esto nativamente — si algún tutorial pide meter un secret en el código Swift, es la señal de que es el flujo equivocado).
- Token: lo administra la caché de MSAL en Keychain con `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no configurable. No se sincroniza a otros dispositivos. Grupo de keychain propio (igual al bundle ID), sin keychain compartido.
- **Riesgo conocido**: `Files.ReadWrite.AppFolder` figura como preview en la documentación de Microsoft desde hace años, limitado a cuentas personales, sin planes anunciados de extenderlo. Comportamiento no garantizado, igual que 5.1.

### 13.3 Sync de facturas individuales

Un archivo por `Expense`, nombrado por su `id` (UUID) — **no por CUFE**, para que gastos manuales encajen igual.

```
PUT /me/drive/special/approot:/Facturas/{uuid}.csv:/content
```

El `PUT` por ruta crea la carpeta intermedia si no existe (`Facturas/` en 13.3, `Backups/` en 13.4); no hace falta crearla antes. Verificado en dispositivo el 2026-10-06; comportamiento no documentado, puede cambiar, igual que 5.1.

Propagación de cambios vía el campo `layer3SyncState`, más la cola `PendingRemoteDeletion` (sección 3.5) para los borrados:

| Origen | Acción en el próximo ciclo de sync |
|---|---|
| `Expense` en `.pending` (nuevo) | `PUT` crear archivo nuevo → pasa a `.synced` |
| `Expense` en `.modifiedLocally` (editado después de ya sincronizado) | `PUT` sobreescribe el mismo archivo (mismo UUID) → pasa a `.synced` |
| `PendingRemoteDeletion` (gasto ya borrado localmente) | `DELETE /me/drive/special/approot:/Facturas/{uuid}.csv`; con respuesta 2xx o 404 (el archivo ya no existe, que es lo que se quería) se borra el `PendingRemoteDeletion` |

Los `PendingRemoteDeletion` se crean aunque la cuenta esté desconectada, siempre que `layer3EverConnected` sea `true`; el sync no los procesa hasta que haya `homeAccountId`.

**Trigger**: mismo patrón que la cola offline (sección 8) — al volver la app a primer plano. No hay timer de background. El ciclo no corre si no hay `homeAccountId` o si el flag de reconexión está activo, y nunca corren dos ciclos a la vez. Un error de red corta el ciclo y lo pendiente queda igual, como en la cola offline.

**Cambio de cuenta**: al completar un login, si el `homeAccountId` guardado (UserDefaults; es un identificador, no un secreto) es nil o distinto del nuevo, se guarda y los `Expense` en `.synced` o `.modifiedLocally` pasan a `.pending`. Los `PendingRemoteDeletion` no se tocan: con otra cuenta su `DELETE` responde 404 y se purgan. Si el `homeAccountId` es igual, no se toca ningún estado. Al desconectar manualmente se borra el `homeAccountId`. La reconexión por sesión expirada no lo borra.

**Sesión expirada**: si la renovación silenciosa falla pidiendo interacción, se marca un flag local y el sync se salta mientras esté activo. Ajustes muestra "Reconexión necesaria" con botón de login. Los registros siguen en `.pending`. Un 401 de Graph se reintenta una vez tras renovar el token; dos fallos seguidos cuentan como sesión expirada. La misma regla aplica si hay un `homeAccountId` guardado pero MSAL no encuentra esa cuenta en su caché (por ejemplo, tras restaurar un backup en otro dispositivo, porque el token es `ThisDeviceOnly`): se marca el flag y Ajustes muestra "Reconexión necesaria".

**Throttling**: los `PUT` y los `DELETE` van en secuencia, sin concurrencia. Ante un 429 el ciclo se detiene, lo pendiente queda en `.pending` y se reanuda en el siguiente primer plano. `Retry-After` no se usa como timer.

**Nota sobre Power Query**: si el usuario ya combinó estos archivos en una tabla de Excel, un `DELETE` remoto no desaparece de esa tabla hasta que el usuario haga un refresh manual en Excel — comportamiento normal de Power Query, no un bug de la app. Los archivos viven bajo `Apps/Cuentas Claras` en el OneDrive del usuario. Si el usuario renombra o mueve esa carpeta, la app sigue funcionando (usa `special/approot`), pero su consulta de Power Query apunta a la ruta vieja y se rompe.

### 13.4 Backup manual reusando la misma conexión

Botón "Respaldar ahora" en ajustes — **manual, disparado únicamente por el usuario, sin ningún trigger automático ni gate de tiempo** (decisión explícita: se descartó cualquier mecanismo de "cada cierto tiempo" porque iOS no ofrece un timer de background confiable, y no hace falta uno si la acción es manual). Reusa la misma función de regenerar CSV completo (sección 11.1) y lo sube a una carpeta separada:

```
PUT /me/drive/special/approot:/Backups/respaldo.csv:/content
```

La carpeta `Backups/` se crea sola con el primer `PUT` (ver la nota en 13.3).

Sobrescribe cada vez (no acumula versiones — OneDrive ya guarda historial de versiones de un archivo por su cuenta).

Errores en "Respaldar ahora": mismas reglas que 13.3. Un 401 se reintenta una vez tras renovar el token. Si la renovación pide interacción, se marca el flag de "Reconexión necesaria" y se muestra el error con opción de reconectar; como el usuario está presente, reconectar abre el login directamente. Un 429 muestra error sin reintento automático. Un login iniciado desde aquí pasa por la regla de `homeAccountId` de 13.3.

Esta función es exclusiva de quien ya activó la Capa 3 — no es universal, no aplica a quien no ha conectado OneDrive.

### 13.5 Sobre costos

Microsoft Graph API es gratis para cuenta personal; no hay Azure de pago ni para el desarrollador ni para el usuario. Rate limiting (429) irrelevante en uso normal; tras un reset de estados por cambio de cuenta puede ocurrir y se maneja con la regla de 13.3.

---

## 14. Seguridad

- **Keychain** para tokens OAuth vía la caché de MSAL (ver 13.2), no `UserDefaults`.
- **PKCE**, sin secretos embebidos en el binario.
- **Data Protection class** en el store de SwiftData — mínimo el default de iOS (`.completeUntilFirstUserAuthentication`), dado que son datos financieros.
- **Bloqueo de app opcional con Face ID/Touch ID** al abrir (`LocalAuthentication`) — proporcional al tipo de dato, sin requerir servidor.
- **ATS (App Transport Security)** de iOS ya bloquea por defecto cualquier conexión no-HTTPS — no agregar excepciones (`NSAllowsArbitraryLoads`) salvo que se confirme, probando en la práctica, que el dominio `dgi-fep.mef.gob.pa` las necesita (algunos `.gob.pa` corren TLS más viejo que sitios comerciales — verificar con datos, no asumir).
- **Certificate pinning: descartado para v1**, decisión consciente. El costo de mantenimiento (romper la app entera para todos si el certificado rota y no se actualiza el pin a tiempo) no se justifica frente al nivel de amenaza real de una app de gastos personales sin usuarios masivos. Revisitar si el perfil de riesgo cambia.
- Validación de CUFE (sección 5.2) siempre ocurre **antes** de cualquier request de red.

---

## 15. Diseño / UI

- **SwiftUI**, siguiendo Human Interface Guidelines de Apple — sin librerías de UI de terceros.
- **Paleta**: inspirada en la bandera de Panamá (`PanamaBlue`/`PanamaRed` en Assets.xcassets, con variante de modo oscuro), usada con moderación — fondo tenue + texto de color, no rellenos sólidos, para no sobrecargar. Uso confirmado: insignia "RUC" (azul) / "SIN RUC" (rojo) en la lista y el detalle de un gasto, según tenga o no `issuerRuc`.
- **Swift Charts** (nativo) para las gráficas de la Capa 1: quincenas (con selector de año/mes), gasto por categoría, por mes, por año, y por comercio (top 10 donde más gastas, top 10 donde menos gastas, y frecuencia de visitas).
- **VisionKit `DataScannerViewController`** para la UI de escaneo en vivo.
- Pantallas principales:
  1. Mis Facturas (lista raíz, mezcla facturas DGI y gastos manuales; con buscador por nombre nativo de iOS y un botón de filtro aparte, en la esquina opuesta de la barra de navegación — RUC/sin RUC, categoría, método de pago; los filtros activos aparecen como chips removibles debajo del título; agrupada por mes en secciones colapsables — sin esto, años de datos serían una lista inmanejable; swipe-to-delete sobre una fila, sin diálogo de confirmación porque el gesto de dos pasos del swipe ya protege contra un borrado accidental). Se ordena y agrupa por `Expense.paymentDate` (`authorizationDate` ?? `issueDate` ?? `scanDate`) — nunca por `scanDate` a solas, que es cuándo se guardó en la app y puede no coincidir con cuándo se hizo la compra real.
  2. Detalle de una factura/gasto — insignia "RUC" (azul) / "SIN RUC" (rojo) junto al encabezado de la sección Negocio. Campos editables (alias/categoría siempre; nombre, fecha de pago, monto y método de pago solo si `cufe == nil`, ver 4.3) se marcan con un ícono de lápiz y, al guardar, un banner de confirmación (o de error si la operación falla) — sin esto, cerrar el editor sin ningún otro rastro visible dejaba al usuario sin saber si el cambio se guardó. Botón "Eliminar factura" (si tiene CUFE) o "Eliminar gasto" (manual), con diálogo de confirmación, ya que un solo toque no tiene la protección de dos pasos del swipe. La fecha se muestra bajo una sola etiqueta, "Fecha de pago", sin distinguir en el texto si es `authorizationDate` (DGI) o `issueDate` (manual)
  3. Captura (selector entre: escanear QR / CUFE manual / gasto manual)
  4. Negocios sin categorizar
  5. Gráficas / análisis
  6. Pendientes (cola offline, sección 8)
  7. Ajustes (exportar Capa 2, conectar/desconectar Capa 3, estado "Reconexión necesaria" de Capa 3, respaldar ahora, bloqueo con Face ID)
- Fuera de alcance por ahora: Android/Material Design. Este documento es exclusivamente para la versión iOS.

---

## 16. Testing

Los tres HTML capturados durante el diseño de este spec (factura válida, CUFE malformado, CUFE inexistente) se guardan como **fixtures dentro del proyecto de Xcode**, con tests unitarios del parser contra ellos desde el arranque del desarrollo — no después. Es la única forma de detectar automáticamente si la DGI cambia el markup, en vez de descubrirlo en producción con campos vacíos.

Fixtures a incluir (adjuntas a este spec):
- `factura_valida.html` → debe parsear a un `Expense` completo y correcto (CUFE `FE01200002029164-1-744562-9400072026091900000746370010310000746379`, emisor "JV PANAMA S.A.", 2 ítems, total 12.10).
- `factura_inexistente.html` → CUFE de 66 caracteres válido en formato pero con un dígito alterado → debe resultar en `.notFound`.
- `factura_malformada.html` → CUFE `"123"` → debe resultar en `.notFound` (mismo comportamiento confirmado, servidor no distingue formato inválido de inexistente en este endpoint).
- `factura.html` (respuesta del endpoint `FacturasPorQR`, con jwt/digestValue) → usada para confirmar que el HTML del panel de factura es idéntico al de `factura_valida.html`, validando que esos parámetros son descartables (sección 4.1).
- (Pendiente conseguir) una nota de crédito real → debe resultar en `.unsupported`.

No se agregan tests más allá de estos — no hay valor en cobertura por cobertura. Ver `CLAUDE.md` sobre disciplina de alcance en testing.

---

## 17. Consideraciones legales — resumen (detalle completo discutido fuera de este doc)

- **Ley 81 de Panamá (Protección de Datos Personales)**: la arquitectura local-first mantiene al desarrollador fuera del rol de "responsable del tratamiento" de datos de otros usuarios, porque no hay backend centralizando nada. Esto se rompe si en el futuro se agrega cualquier cosa centralizada (analytics, crash reporting con datos de usuario, backend propio).
- **Condiciones de Uso de la DGI** (`https://dgi.mef.gob.pa/Condicion.php`): prohíben explícitamente "la venta o comercialización de los contenidos, documentos o cualquier parte de la información contenida en el Sitio". Uso personal y app gratuita no tienen problema; monetizar específicamente la función de consulta DGI es zona gris — consultar con un abogado antes de cobrar por eso, no antes de usarlo.
- **App Store**: Privacy Policy + Privacy Nutrition Label obligatorios. Privacy Manifest (`PrivacyInfo.xcprivacy`) requerido desde 2024. La exención de "Sign in with Apple" (guideline 4.8) aplica porque el login de Microsoft es solo para conectar con un servicio de terceros específico (OneDrive), no la cuenta principal de la app — la app funciona 100% sin login.
- **Google Play**: fuera de alcance en esta fase (solo iOS por ahora) — revisar Data Safety cuando se aborde Android.

---

## 18. Roadmap por fases

**Estado**: Fase 3 completa — tag `v0.3.0` (Fase 2: `v0.2.0`, Fase 1: `v0.1.0`). Detalle del pulido hecho sobre lo básico de la Fase 1 en el issue #31 (cerrado). Ideas anotadas para evaluar más adelante, sin diseñar todavía: pagos recurrentes (issue #32) e inversiones/ahorros (issue #42) — ninguna de las dos es parte de ninguna fase todavía. Siguiente: Fase 4.

### Fase 1 — Núcleo (Capa 1) ✅
- Modelos SwiftData (sección 3)
- Parseo DGI completo con tests contra fixtures (secciones 5, 16)
- Las tres vías de captura (sección 4)
- Deduplicación (sección 6)
- Cola offline (sección 8)
- Categorización manual (sección 9)
- Pantallas de lista, detalle, captura, categorización
- Gráficas con Swift Charts

### Fase 2 — Capa 0 + Capa 2 ✅
- Backup local automático silencioso (sección 10)
- Exportación manual a archivo elegido, con append y versionado de esquema (secciones 11, 12)
- Pantalla de ajustes básica

### Fase 3 — Capa 3 ✅
- Registro en Microsoft Entra (manual, por el desarrollador)
- Auth MSAL + Keychain (secciones 13.1, 13.2)
- Sync de facturas individuales con propagación de cambios (13.3)
- Backup manual a OneDrive (13.4)

### Fase 4 — Pulido y preparación para tienda
- Bloqueo con Face ID/Touch ID
- Privacy Manifest, Privacy Policy, Nutrition Label
- Verificación de ATS contra el dominio DGI real (sección 14)

### Fase 5 — Pendientes fuera del spec original
Alcance por definir; se arma a partir de los Issues abiertos que no corresponden a ninguna fase anterior. Incluye la revisión final de Privacy Policy y Nutrition Label antes del primer envío a App Review.
- Revisión de notas de crédito con un caso real (sección 7), cuando se consiga uno. Mientras tanto, caen en `.unsupported` (límite conocido de v1).

### Fuera de alcance (no en este spec)
- Android / Google Play / Material Design
- Certificate pinning
- Sync bidireccional completo más allá de lo descrito en 13.3
- Cualquier backend propio
- OCR / fotos de facturas
