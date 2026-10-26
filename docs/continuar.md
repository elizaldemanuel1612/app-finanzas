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

## Pendiente inmediato: probar el respaldo en Google Drive

2026-10-26: por privacidad, el respaldo dejó de ser Firestore y ahora vive
en el **Google Drive del propio usuario** (`appDataFolder`, permiso
`drive.appdata`; spec §4.2.1). Firestore quedó cerrado (reglas que niegan
todo). Política de privacidad y términos actualizados. Web publicada en
`https://app-finanzas-27e41.web.app`.

Falta, en orden:
1. **Habilitar la API de Google Drive** en el proyecto (lo hace el usuario):
   https://console.cloud.google.com/apis/library/drive.googleapis.com?project=app-finanzas-27e41
   Sin eso, Drive responde 403 y la app dice "No se pudo conectar con tu
   Google Drive".
2. Probar en la web (Safari del iPhone y la app agregada a inicio, que
   guardan aparte): entrar → aceptar permiso de Drive → Ajustes → Respaldo
   en tu Google Drive → Activar → registrar gastos → en el otro lado entrar
   → "Encontramos tu respaldo" → Restaurar. Probar anular/borrar en un lado.
3. Instalar la versión nueva en el iPhone físico (cable): probar el permiso
   de Drive desde la app nativa, el widget, la cámara, el dictado y los
   emojis.
4. Decidir si se borra la base Firestore `(default)` (ya no se usa; puede
   tener datos de prueba del 2026-10-26).

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
  (2026-10-26, reemplaza la decisión anterior de Firestore).
- Publicar en tiendas sigue en pausa; prioridad: uso personal en iPhone y web.
- Android: falta la contraparte del widget y del atajo de voz.

## Ideas anotadas para después

Modo oscuro, recordatorios (fijas por vencer, "no has registrado hoy"),
presupuesto compartido en pareja (el modelo `cuentas/{cuentaId}/miembros`
ya lo permite), subir fotos de tickets a la nube.
