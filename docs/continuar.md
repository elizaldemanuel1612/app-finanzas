# Para continuar (estado al 2026-10-25)

Resumen de traspaso entre conversaciones. Las reglas del proyecto viven en
`CLAUDE.md`; aquí solo va lo que está **a medias** y el contexto práctico.

## Entorno

- Mac del usuario: proyecto en `~/Documents/app-finanzas`, rama `master`,
  remoto `github.com/elizaldemanuel1612/app-finanzas` (sesión `gh` iniciada).
- También trabaja en una PC con Windows (Android). Tras `git pull` allá:
  `flutter pub get` (se agregaron `cloud_firestore` y `shared_preferences`).
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

## Pendiente inmediato: nube y web (código listo, falta conectar)

Código ya hecho y en GitHub (commit "Respaldo en la nube opcional y versión
web (PWA), en curso"): spec §4.2.1–4.2.2, `lib/data/almacenamiento/`,
`lib/data/nube/servicio_nube.dart`, `lib/domain/sincronizacion/fusion.dart`,
`lib/ui/ajustes/pantalla_nube.dart`, `firestore.rules`, `firebase.json`,
`.firebaserc` (proyecto `app-finanzas-27e41`), `web/` con marca MAVfin.

Falta, en orden:
1. `firebase login --no-localhost` (lo hace el usuario; firebase-tools ya
   está instalado). Comprobar con `firebase projects:list`.
2. Crear la base de datos Firestore si no existe
   (`firebase firestore:databases:create "(default)" --location=nam5` o
   desde la consola) y desplegar reglas: `firebase deploy --only firestore:rules`.
3. Registrar la app web: `firebase apps:create web MAVfin` y
   `firebase apps:sdkconfig web <appId>`; completar el bloque `web` en
   `lib/firebase_options.dart` (hoy lanza `UnsupportedError` para web).
4. `flutter build web` y `firebase deploy --only hosting` → URL
   `https://app-finanzas-27e41.web.app`. El dominio queda autorizado para
   el login de Google automáticamente.
5. Probar de punta a punta: en el simulador, Ajustes → Respaldo en la nube
   → Activar; luego en la web entrar con la misma cuenta → debe aparecer
   "Encontramos tu respaldo" → Restaurar. Probar las tres opciones de
   combinar y que borrar en un lado no "reviva" en el otro.
6. Instalar la versión nueva en el iPhone físico y revisar ahí el widget
   (la galería de widgets del simulador falla), la cámara, el dictado y
   los emojis.
7. Actualizar `CLAUDE.md` (sección Estado actual) con nube y web.

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
- Nube = Firestore ligado a la cuenta de Google, **opcional**, el usuario
  decide; no Google Drive.
- Publicar en tiendas sigue en pausa; prioridad: uso personal en iPhone y web.
- Android: falta la contraparte del widget y del atajo de voz.

## Ideas anotadas para después

Modo oscuro, recordatorios (fijas por vencer, "no has registrado hoy"),
presupuesto compartido en pareja (el modelo `cuentas/{cuentaId}/miembros`
ya lo permite), subir fotos de tickets a la nube.
