# Privacy policy draft

Draft of the app's privacy policy. The app is a personal and portfolio project and is not distributed on the App Store, so this is not submitted anywhere; it documents what the app does with data. Not final. The policy text itself is in Spanish because that is the app's language; headings and notes are in English.

## Not verifiable against the code

- **Exact data MSAL sends.** Defined by Microsoft; what it actually transmits, and how long Microsoft retains it, cannot be confirmed from this repo. The data types MSAL declares are in its own `PrivacyInfo.xcprivacy`.
- **Invoice CSV content.** The content (issuer, RUC, items, amounts, payment method) goes to the user's own Microsoft account, not to the developer.
- **The DGI lookup.** A CUFE is sent to a public government endpoint, not to the developer or a partner.
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
