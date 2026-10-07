# Privacy drafts

Drafts of the Privacy Policy and the App Store Connect Nutrition Label (App Privacy). Not final: the final review happens in Phase 5, before the first App Review submission (spec section 18). The policy text itself is in Spanish because that is the app's language; headings and notes are in English.

## Nutrition Label (App Store Connect > App Privacy)

"Do you or your third-party partners collect data from this app?": **Yes**.

Conservative option: declare the data types listed in MSAL's own `PrivacyInfo.xcprivacy` (MSAL 2.16.0), following MSAL's linked/not linked value per type, plus Purchase History. All with tracking off and purpose **App Functionality**.

| Category | Data type | Linked to user | Tracking | Source |
|---|---|---|---|---|
| Contact Info | Name | Yes | No | MSAL manifest: Name |
| Contact Info | Email Address | Yes | No | MSAL manifest: EmailAddress |
| Contact Info | Other User Contact Info | Yes | No | MSAL manifest: OtherUserContactInfo |
| Contact Info | Phone Number | **No** | No | MSAL manifest: PhoneNumber |
| User Content | Customer Support | Yes | No | MSAL manifest: CustomerSupport |
| Identifiers | User ID | Yes | No | MSAL manifest: UserID |
| Identifiers | Device ID | Yes | No | MSAL manifest: DeviceID |
| Diagnostics | Other Diagnostic Data | Yes | No | MSAL manifest: OtherDiagnosticData |
| Purchases | Purchase History | Yes | No | App: invoice CSV files uploaded to the user's own OneDrive |

The "Privacy Policy URL" field (App Information) takes the URL where the policy below ends up published.

## Not verifiable against the code

- **Exact data MSAL sends.** Defined by Microsoft. The table follows MSAL's own manifest, but what it actually transmits, and how long Microsoft retains it, cannot be confirmed from this repo.
- **Whether App Review accepts "the data goes to Microsoft, not to the developer" as not collected.** That is why the conservative option declares it.
- **Purchase History.** The CSV content (issuer, RUC, items, amounts, payment method) goes to the user's own Microsoft account, not to the developer. It is declared under the same conservative logic as the MSAL types; Apple's classification is App Review's call.
- **The DGI lookup.** A CUFE is sent to a public government endpoint, not to the developer or a partner. It is not declared in the label, which is a judgment call and not a verifiable fact.
- **Date and contact email** in the policy are placeholders.

## Privacy Policy (draft, Spanish)

> **Política de privacidad de Cuentas Claras**
>
> Última actualización: [fecha]
>
> **Resumen.** Cuentas Claras guarda tus datos en tu dispositivo. No tiene servidores propios, no usa analytics, no muestra publicidad y no hace tracking. La app solo se conecta a internet para consultar a la DGI de Panamá el CUFE de una factura y, si tú lo activas, para conectar tu cuenta de OneDrive. Sin conexión a OneDrive, la app no recolecta datos.
>
> **Datos que se guardan en tu dispositivo.** Las facturas que escaneas o registras (emisor, RUC, ítems, montos, fecha, método de pago), tus categorías y alias de negocios, y archivos CSV de respaldo en la carpeta de Documentos de la app.
>
> **Copias de seguridad de iOS.** Los archivos CSV de respaldo de la carpeta de Documentos pueden incluirse en las copias de seguridad de iOS o iCloud que tengas activas en tu dispositivo, según tu configuración de Apple. Esas copias las gestiona Apple, no el desarrollador.
>
> **Exportación manual.** Si exportas un CSV desde Ajustes, el archivo se guarda en la ubicación que elijas, y desde ese momento queda fuera del control de la app.
>
> **Consulta a la DGI.** Al escanear o ingresar un CUFE, la app consulta el servicio público de la DGI de Panamá enviándole ese CUFE para obtener los datos de la factura. No se envía ningún otro dato tuyo.
>
> **OneDrive (opcional).** Si conectas tu cuenta de Microsoft, la app inicia sesión con la biblioteca MSAL de Microsoft y sube copias de tus facturas en CSV a la carpeta de la app en tu OneDrive. Solo en ese caso se recolectan datos como los de tu cuenta de Microsoft, y esos datos van a Microsoft, no a un servidor del desarrollador. El desarrollador no tiene acceso a ellos. Su tratamiento lo rige la política de privacidad de Microsoft. Puedes desconectar OneDrive cuando quieras desde Ajustes.
>
> **Cámara.** Se usa solo para leer el código QR de la factura. No se guardan ni se envían imágenes.
>
> **Contacto.** [correo de contacto]
