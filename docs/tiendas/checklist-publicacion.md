# Checklist de publicación — Fase 6

Consolidado de "Bloqueante de publicación vs. deseable" del plan de Fase
6. `test/paridad/paridad_3_2_test.dart` en verde es la reformulación
ejecutable del criterio de aceptación de la fase — es el primer punto de
esta lista, no el último, porque todo lo demás se apoya en que las cifras
no se movieron.

## Bloqueante

- [x] `test/paridad/paridad_3_2_test.dart` en verde (~800 pruebas totales
      con `dart test`, más `flutter test test/ui` en verde aparte — ver
      `docs/paridad-3-2-procedimiento.md`).
- [x] **`file_picker` es superficie nativa nueva** (selector de archivos de
      "Importar gastos"): verificado a mano el 2026-08-24 en el emulador
      `finanzas_pixel7` (Android 16, API 36, arranque en frío) — el
      selector nativo de Android (SAF) abre, la selección de un CSV real
      se refleja en pantalla, `previsualizarImportacion` muestra el conteo
      de movimientos y las categorías nuevas detectadas, y el `PopScope`
      "¿Descartar lo capturado?" dispara correctamente al salir sin
      importar (capturas en `docs/tiendas/capturas/importar_vista_previa.png`).
      **Actualizado el 2026-08-31:** `file_picker` subió de `12.0.0-beta.7`
      a la serie estable `^12.1.2` — `flutter pub get` resolvió sin
      conflicto con `share_plus ^13.3.0` (el problema de rango de `win32`
      que fijaba la versión en beta ya no aplica), y tanto
      `flutter build apk --debug` como `--release` (con minify/R8)
      compilan bien. Pendiente repetir la prueba interactiva del selector
      en dispositivo/emulador (bloqueado hoy por el login, ver el punto de
      firma/Firebase más abajo) para confirmar que el comportamiento en
      pantalla no cambió con la versión estable.
      **Sigue pendiente:** repetir en un dispositivo físico real (no
      emulador) antes de publicar — el guion completo de
      `docs/paridad-3-2-procedimiento.md`, incluido el segundo dispositivo.
      Play Data Safety / App Privacy: ver auditoría en
      `docs/tiendas/seguridad-de-datos.md` (actualizada el 2026-08-31).
- [x] `INTERNET` en el manifest de release (antes solo estaba en
      `debug/`, fallo solo-en-release).
- [x] `android:allowBackup="false"` + reglas de extracción de datos.
- [x] `android:label` y `description` del `pubspec.yaml` reales, no los
      de plantilla.
- [x] Ajustes con eliminación de cuenta funcional
      (`ServicioAuth.eliminarCuenta`, incluido el caso
      `requires-recent-login`) y exportación CSV.
- [x] Aviso de no-asesoría financiera in-app (Ajustes) y en la ficha de
      Play (`ficha-play.md`).
- [x] Formulario de Seguridad de datos / App Privacy redactado y
      coherente entre ambas tiendas (`seguridad-de-datos.md`).
- [x] **Política de privacidad y términos publicados en una URL pública.**
      Dentro de la app ya funciona: Ajustes → "Política de privacidad" /
      "Términos y condiciones" abre `lib/ui/comun/documento_legal.dart`,
      que renderiza `docs/legal/privacidad.md`/`terminos.md` (empaquetados
      como asset) directamente en la app. Además, desde 2026-08-12 existe
      el repo remoto `https://github.com/elizaldemanuel1612/app-finanzas`
      con GitHub Pages activo en la rama huérfana `gh-pages` (aislada de
      `docs/` interno a propósito): `https://elizaldemanuel1612.github.io/app-finanzas/privacidad/`
      y `.../terminos/`, con el contenido transcrito a mano de
      `docs/legal/*.md`. Si esos `.md` cambian, hay que editar a mano los
      HTML de `gh-pages` y volver a hacer push — no hay sincronización
      automática.
      **Resuelto el 2026-09-06:** correo de contacto real
      (`elizaldemanuel1612@gmail.com`) publicado en los cuatro lugares —
      los dos `.md` en `master` y los dos HTML en `gh-pages` (como enlace
      `mailto:` en estos últimos).
- [x] **URL web pública de solicitud de eliminación de cuenta** (Play la
      exige aparte de la eliminación in-app):
      `https://elizaldemanuel1612.github.io/app-finanzas/eliminar-cuenta/`,
      publicada el 2026-08-24 en el mismo `gh-pages`, enlazada desde el
      índice. Explica qué se borra de inmediato desde la app (cuenta +
      todos los datos locales) y cómo solicitar la eliminación de la
      cuenta de Firebase Authentication cuando ya no se tiene la app
      instalada. **Resuelto el 2026-09-06:** mismo correo de contacto real
      que privacidad/términos (ver arriba), publicado también aquí.
- [~] **Bundle ID de Android unificado** a `com.manuelelizalde.appfinanzas`
      — hecho el 2026-08-31, ver detalle y verificación en el paso 4 de
      "Próxima visita a Firebase/Play Console" más abajo y en "Estado
      actual" de `CLAUDE.md`. **Sigue pendiente:** el lado iOS sigue con
      su propio identificador — unificarlo cuando exista Mac (Bloque 6).
- [~] **Firma con keystore propia.** Generada el 2026-08-26: upload key en
      `android/app/upload-keystore.jks` (RSA 2048, validez 27 años,
      alias `upload`), referenciada desde `android/key.properties` —
      **ninguno de los dos se versiona** (ya estaban en `.gitignore` desde
      antes). `build.gradle.kts` carga `key.properties` y firma
      `buildTypes.release` con esa key si el archivo existe, cayendo a la
      firma de debug si no (para que `flutter run --release` siga
      funcionando en otra máquina sin el keystore). De paso se activó
      `isMinifyEnabled`/`isShrinkResources` (R8) con
      `android/app/proguard-rules.pro`. Verificado con
      `flutter build apk --release --no-tree-shake-icons`: compila,
      queda firmado con la upload key (no la de debug — confirmado con
      `apksigner verify --print-certs`), y la app arranca sin crashes en
      el emulador con R8 activo. El login con Google falla ahí con
      `UNREGISTERED_ON_API_CONSOLE`.
      **Hallazgo (no causado por este cambio):** ese mismo error también
      ocurre en el emulador con el build de **debug**, con la firma que
      ya existía antes de esta sesión — confirmado por logcat
      (`bvip: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE]`) y
      por `android/app/google-services.json`, cuyo arreglo `oauth_client`
      está vacío **desde el commit inicial del proyecto**
      (`git log --follow` no muestra ningún cambio a ese archivo). Es
      decir: Firebase nunca ha tenido registrada ninguna huella SHA-1
      para este paquete Android, ni siquiera la de debug — el login
      nativo de Google en Android probablemente nunca ha funcionado de
      punta a punta en un dispositivo/emulador fresco en este proyecto.
      **Huellas para pegar en Firebase Console → Configuración del
      proyecto → tus apps → app Android → agregar huella** (de una sola
      vez, son dos pares):
      - Debug (para poder probar login en desarrollo):
        SHA-1 `59:82:96:B9:BF:B8:49:9B:9D:7E:B0:DB:B7:C2:5A:C4:E8:D3:FB:57`
        · SHA-256 `31:09:71:5F:78:A6:31:6E:00:92:FA:7D:06:C9:4E:8D:C1:68:E4:66:56:46:6F:76:AD:56:1C:A6:3D:F2:7F:92`
        (de `~/.android/debug.keystore`, alias `androiddebugkey` —
        estándar de Gradle, distinto por máquina; si se prueba en otra
        computadora hay que sacar y agregar también la huella de esa).
      - Upload key (para los builds de release firmados hoy):
        SHA-1 `88:A9:6D:D5:10:C1:06:50:8B:56:A8:6B:39:4E:7E:35:BE:86:AB:4A`
        · SHA-256 `2F:33:0E:A8:22:7E:94:40:37:93:33:F7:A8:78:3A:D2:BD:A3:60:38:8F:4E:ED:E5:6C:87:33:5C:76:61:9E:28`.
      Después de agregar ambas, descargar el `google-services.json`
      actualizado desde Firebase Console y reemplazar
      `android/app/google-services.json` (el de hoy tiene el arreglo
      `oauth_client` vacío).
      **Confirmado el 2026-08-31: resuelto.** El usuario agregó las 4
      huellas (2 SHA-1 + 2 SHA-256) en Firebase Console y descargó el
      `google-services.json` nuevo — confirmado que trae
      `android_info.certificate_hash` con ambas huellas de debug y de la
      upload key. Reemplazado en el repo. Login probado en el emulador
      (build debug): completa de punta a punta (`GetGoogleIdOperation`
      exitoso, ya no aparece `UNREGISTERED_ON_API_CONSOLE`), llega al
      onboarding de cuenta nueva. Nota aparte: en el primer intento salió
      `unknownError` por falta de red del emulador (no relacionado a
      Firebase) — se resolvió con un arranque en frío del emulador.
      **Sigue pendiente (requiere Firebase/Play Console, fuera de
      alcance sin esas cuentas):** subir un `.aab` a la pista de pruebas
      internas de Play para que Play genere la *App signing key* (huella
      distinta a las de arriba, agregar
      también); y verificar el login **desde esa instalación** — la App
      signing key re-firma el bundle. **Guardar `upload-keystore.jks` y
      las contraseñas de `key.properties` en un lugar seguro fuera de
      este repo (gestor de contraseñas): perder el archivo después de la
      primera subida a Play significa no poder actualizar la app nunca
      más bajo esa ficha.**
- [~] Ícono y splash — `flutter_launcher_icons` y `flutter_native_splash`
      ya están instalados, configurados en `pubspec.yaml` y corridos
      (Android e iOS regenerados, sin canal alpha en iOS). Las imágenes
      fuente (`assets/icono/icono_1024.png`,
      `assets/icono/icono_foreground_1024.png`) son un **marcador de
      posición** generado por programa (moneda "$" en violeta/verde de
      marca, `lib/ui/comun/paleta.dart`), no arte final. **Sigue
      pendiente:** reemplazar esas dos imágenes por el arte definitivo y
      volver a correr `dart run flutter_launcher_icons` +
      `dart run flutter_native_splash:create`.
- [ ] Sign in with Apple presente en el código — no hecho en esta sesión
      (Bloque 6, iOS); de cualquier forma no verificable sin Mac.
- [ ] Declaración de funciones financieras de Play: "Ninguna de estas"
      (documentado en `ficha-play.md`, pendiente de marcarla en Play
      Console al crear la ficha).
- [~] Capturas de pantalla — 5 en `docs/tiendas/capturas/`: inicio y
      gastos (actualizadas 2026-08-31, cuenta de prueba con 20
      movimientos importados vía CSV — ver `capturas/README.md`),
      ajustes, guía, vista previa de importación (2026-08-24).
      **Sigue pendiente:** `Ciclos anteriores` sigue vacío — correcto
      para una cuenta nueva con el primer ciclo todavía abierto, no
      poblable sin una cuenta con meses reales de uso o sin manipular el
      reloj (ninguna honesta para una captura de tienda). También falta
      recortarlas al formato de marketing que piden las tiendas (no son
      las capturas crudas del dispositivo) y el gráfico destacado
      (feature graphic) de Play. El ícono de tienda en alta resolución ya
      puede salir de `assets/icono/icono_1024.png` (ver arriba), aunque
      sigue siendo placeholder.

## Próxima visita a Firebase/Play Console (Bloque 5)

Varios puntos de arriba comparten el mismo viaje — hacerlos juntos, en
este orden, para no ir y venir:

1. ~~Firebase Console → Configuración del proyecto → tus apps → app
   Android → agregar huella: pegar las dos huellas SHA-1/SHA-256 (debug
   y upload key) del punto "Firma con keystore propia" de arriba.~~
   **Hecho el 2026-08-31.**
2. ~~Descargar el `google-services.json` actualizado y reemplazar
   `android/app/google-services.json`.~~ **Hecho el 2026-08-31.**
3. ~~Probar el login en el emulador/dispositivo para confirmar que ya no
   sale `UNREGISTERED_ON_API_CONSOLE`.~~ **Hecho el 2026-08-31: login
   completo, llega al onboarding.**
4. ~~Cambiar `applicationId` de Android a `com.manuelelizalde.appfinanzas`
   (unificando con iOS).~~ **Hecho el 2026-08-31.** Requirió un paso
   adicional no previsto en el plan original: Firebase no renombra una
   app Android existente, así que primero se registró una app Android
   **nueva** en el mismo proyecto con el paquete unificado, se le
   agregaron las mismas 4 huellas (debug + upload key), y se descargó un
   `google-services.json` con las dos apps Android. Con eso ya en el
   repo, se cambió `applicationId` en `android/app/build.gradle.kts`
   (el `namespace` se dejó igual a propósito). Verificado: build de
   debug y de release (firmado + minify/R8) compilan, y el login con
   Google completa de punta a punta en ambos.
5. `flutter build appbundle --release` y subir el `.aab` a la pista de
   pruebas internas de Play — esto genera la *App signing key* de Play
   (huella distinta a la upload key).
6. Volver a Firebase Console y agregar también la huella de la App
   signing key (paso 1, mismo lugar).
7. Verificar el login **desde la instalación de la pista de pruebas**,
   no desde el APK/`.aab` local — la App signing key re-firma el bundle
   y cambia la SHA-1 con la que corre en producción.

## Deseable, alto valor

- [x] Exportación CSV (`lib/domain/exportacion/exportar_csv.dart`, spec v2
      §7.4).
- [x] Fuentes empaquetadas — Outfit y Plus Jakarta Sans (SIL OFL,
      `assets/fuentes/`, licencias registradas en `LicenseRegistry`),
      `TextTheme` centralizado (`lib/ui/comun/tema.dart`) y guardia
      (`test/estilos_ui_test.dart`).
- [x] Contraste WCAG AA — `lib/ui/comun/paleta.dart` +
      `test/ui_contraste_test.dart`. Gap conocido y aceptado sin corregir:
      `verde` (#12B76A) usado como fondo con ícono blanco encima
      (Dismissible) da 2.62:1, por debajo incluso del umbral gráfico 3:1 —
      requeriría cambiar el color de marca, fuera de alcance de este
      bloque.
- [x] `PopScope` de "¿Descartar lo capturado?" en las pantallas de
      captura/formularios, incluidas Importar y Meta de apartado
      (`lib/ui/comun/popscope_descartar.dart`).
- [x] Selección de locale de dictado (`es_MX` sobre `es-ES`,
      `lib/domain/voz/seleccion_locale.dart`) y mensaje accionable cuando
      el micrófono está denegado.
- [x] `semanticsLabel` con monto en palabras
      (`lib/domain/voz/monto_hablado.dart`) en las cifras héroe de Inicio
      y el total de Gastos.
- [x] Accesibilidad — `Semantics` en `BarraRitmo` (requiere el nuevo
      parámetro `descripcion` en sus 3 call sites: `pantalla_inicio.dart`,
      `pantalla_detalle_categoria.dart`, `pantalla_cierre_ciclo.dart`) y en
      `GraficaEvolucion` (resumen de qué ciclo apartó más/menos y el
      promedio); `ExcludeSemantics` en los emojis sueltos de
      `pantalla_inicio.dart` (👋 y los emoji de categoría); escalado de
      texto verificado sin overflow a 1.0x/1.5x/2.0x en `PantallaInicio` y
      `PantallaGastos` (`test/ui/escalado_test.dart`); `clamp(maxScaleFactor:
      1.6)` en las 2 cifras héroe de 34px, sin fijar ningún `textScaler`
      global; labels verificados en `test/ui/semantica_test.dart`. La guía
      por temas (`lib/ui/ayuda/`) y el onboarding rediseñado de 7 pasos
      quedan cubiertos aparte, sin overflow a 1.0x/2.0x
      (`test/ui/guia_test.dart`, `test/ui/onboarding_test.dart`).
      **Gap corregido:** el emoji 🎁 ya no va concatenado dentro del mismo
      `Text` que la etiqueta en `pantalla_ciclos_anteriores.dart` ni en
      `_FilaIngreso` de `pantalla_ingresos_del_ciclo.dart` — ambos pasaron
      a un `Row` con el emoji en su propio `Text` (`ExcludeSemantics`), así
      que un lector de pantalla dice solo "Cerrado" o la etiqueta, sin el
      nombre del emoji por delante.
- [x] Minify/R8 — activado el 2026-08-26 junto con la firma propia (ver
      arriba), `android/app/proguard-rules.pro`, verificado con
      `flutter build apk --release`.

## Explícitamente fuera de esta fase

- Widgets de inicio y atajos de voz (diferidos por decisión).
- Firestore y el punto 4 del §3.2 (diferidos con justificación escrita en
  `docs/paridad-3-2-procedimiento.md`).
- Migración inicial desde Excel con reconciliación de totales declarados
  (`lib/domain/migracion/reconciliacion.dart` se conserva sin consumidor,
  documentado en `CLAUDE.md`) — distinta de la importación de CSV "siempre
  disponible" que sí se implementó (`lib/ui/importacion/`), que reusa
  `movimiento_migrado.dart` pero no exige totales declarados que cuadren.
- Todo el Bloque 6 (iOS): el árbol está preparado para recibir Firebase
  iOS y Apple Sign-In, pero nada de eso se implementó en esta sesión — no
  hay forma de verificarlo sin Mac de cualquier manera.

## Verificación end-to-end antes de publicar

1. `flutter build appbundle --release` produce un `.aab` firmado con la
   upload key.
2. Instalar el release en dispositivo y correr el guion de
   `docs/paridad-3-2-procedimiento.md`.
3. Repetir en un segundo dispositivo Android — la sustitución documentada
   del §3.2.
4. Subir a la pista de pruebas internas y verificar el login con Google
   **desde esa instalación**, no desde el APK local — la App signing key
   de Play re-firma el bundle y cambia la SHA-1.
5. Probar a mano en el release: dictado, foto de ticket, exportar CSV, y
   eliminar cuenta con una cuenta desechable — confirmando que los 6 JSON
   y el directorio de fotos desaparecen (`AlmacenLocal.borrarTodo`).
6. Recorrer la app con TalkBack activado y con el tamaño de fuente del
   sistema al máximo — las pruebas automáticas (`test/ui/semantica_test.dart`,
   `test/ui/escalado_test.dart`, `test/ui/guia_test.dart`,
   `test/ui/onboarding_test.dart`) cubren `BarraRitmo`, `GraficaEvolucion`,
   los 10 temas de la guía, la bienvenida del onboarding y overflow a
   2.0x, pero un recorrido real con TalkBack en dispositivo sigue siendo
   el único modo de confirmar que se escucha bien de punta a punta.
