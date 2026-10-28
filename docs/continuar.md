# Para continuar (estado al 2026-10-25)

Resumen de traspaso entre conversaciones. Las reglas del proyecto viven en
`CLAUDE.md`; aquí solo va lo que está **a medias** y el contexto práctico.

## Entorno

- Mac del usuario: proyecto en `~/Documents/app-finanzas`, rama `master`,
  remoto `github.com/elizaldemanuel1612/app-finanzas` (sesión `gh` iniciada).
- También trabaja en una PC con Windows (Android). Tras `git pull` allá:
  `flutter pub get` (se agregaron `http` y `shared_preferences`; salió `cloud_firestore`).
- Flutter 3.47.7 en el Mac; Xcode 27; simulador `iPhone 17`
  (`FE974627-DC6D-40B4-9A0E-B7642FE5C326`) con 98 gastos de ejemplo y la
  sesión cerrada.
- iPhone físico: "iPhone de Daniel (3)", iPhone 17 Pro Max, iOS 26.6.2,
  UDID `00008150-000E4C562244401C`, Modo desarrollador activo, Apple ID
  gratuito (equipo `C9ZH8PG83T`, firma de 7 días). App Group ya fue
  aceptado por Apple con la cuenta gratuita.
- Instalar en el iPhone conectado:
  `cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner
  -configuration Release -destination "id=00008150-000E4C562244401C"
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`
  y luego `xcrun devicectl device install app --device <UDID> <ruta Runner.app>`.
  Si dice "profile has not been explicitly trusted": Ajustes → General →
  VPN y gestión de dispositivos → confiar.
- El usuario a veces trabaja en remoto (TeamViewer / Remote Control): los
  pasos que requieren sus credenciales (Google, Apple, Firebase) los hace él.
- `pubspec.lock` y `analysis_options.yaml` pueden aparecer modificados por
  la versión de Flutter del Mac: no es un problema.

## Pendiente inmediato: instalar la app nativa en el iPhone (en pausa)

El usuario decidió (2026-10-28) **esperar a instalar la app nativa** antes
de seguir puliendo: la web en iPhone es más lenta y no tiene cámara. Todo
lo hecho desde el 2026-10-26 vive en el código compartido de Flutter, así
que **ya va incluido** en la nativa al instalarla; no hay que replicar nada,
solo probarlo ahí.

Hecho y probado en la web (2026-10-26 a 10-28): respaldo en el Google Drive
del usuario (activado y funcionando con su cuenta), Firestore cerrado,
modo oscuro, fuentes Plus Jakarta Sans en botones/chips/listas, sugerencias
del onboarding independientes ("lo que sobre" sí sobra), chips legibles,
gesto de regresar sin choque con Safari, importar CSV (selector propio en
web) y dictado web con el micrófono del teclado.

Al instalar la nativa (cable; comandos en "Entorno"), probar en este orden:
1. Login con Google y **permiso de Drive desde la app nativa** (hoja de
   Google al tocar Activar respaldo); que restaure lo que ya está en Drive
   desde la web ("Encontramos tu respaldo" o Combinar).
2. **Dictado nativo** (`speech_to_text`, no el de la web): permiso de
   micrófono la primera vez, que no se trabe, que entienda es-MX.
3. **Foto de ticket** (cámara y galería) y "Dividir ticket". Hoy es solo
   adjunto: **no lee** total ni productos. Si el usuario lo pide, la lectura
   automática es una función nueva (ML Kit en el dispositivo o IA nivel 3).
4. **Importar CSV** con `file_picker` nativo desde Archivos/iCloud.
5. Modo oscuro (Ajustes → Apariencia y "Automático" con el del iPhone),
   gesto de regresar, velocidad general, widget de inicio y atajo de Siri,
   emojis.
6. Revisar que la pantalla de consentimiento OAuth esté "En producción"
   antes de que otra persona use el respaldo (en "Prueba" solo entran
   usuarios de prueba y el permiso caduca a los 7 días).

## Decisiones tomadas (no reabrir sin preguntar)

- Nombre visible **MAVfin**, lema "Tus finanzas, tu progreso"
  (`lib/ui/comun/marca.dart`). Identificadores internos
  (`com.manuelelizalde.appfinanzas`, `app_finanzas`, App Group) **no** se
  cambian.
- Logo del usuario (aro dorado, montaña con bandera, flecha, barras)
  redibujado en `assets/icono/` y `assets/marca/logo.png`. Script en
  `/private/tmp/.../scratchpad/logo.swift` (temporal; el PNG es la fuente).
- Diseño premium: azul noche #0B1F3B, oro #D4AF37 solo como acento, marfil.
  Tipografía Outfit/Plus Jakarta Sans (el usuario no quiere Inter por ahora).
- Respaldo = **Google Drive del propio usuario** (`appDataFolder`),
  **opcional**; la app no guarda datos financieros en servidores propios
  (2026-10-26, reemplaza la decisión anterior de Firestore). La base
  Firestore `(default)` se **conserva cerrada** (reglas que niegan todo) por
  si se ocupa después; no borrarla sin preguntar.
- Publicar en tiendas sigue en pausa; prioridad: uso personal en iPhone y web.
- Android: falta la contraparte del widget y del atajo de voz.

## Ideas anotadas para después

Recordatorios (fijas por vencer, "no has registrado hoy"),
presupuesto compartido en pareja (el modelo `cuentas/{cuentaId}/miembros`
ya lo permite), subir fotos de tickets a la nube.
