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
      **Sigue pendiente:** repetir en un dispositivo físico real (no
      emulador) antes de publicar — el guion completo de
      `docs/paridad-3-2-procedimiento.md`, incluido el segundo dispositivo
      — y revisar si Play Data Safety / App Privacy piden declarar acceso
      a archivos. Fijado en `12.0.0-beta.7` (prerelease, ver "Estado
      actual" en `CLAUDE.md`): confirmar que sigue siendo la versión
      correcta antes de publicar, por si ya salió una estable compatible
      con `share_plus`.
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
      **Sigue pendiente:** el correo de contacto real en la sección
      "Contacto" de ambos documentos (`_[correo de contacto pendiente de
      publicar]_`) — decisión del usuario aplazada a propósito. Al
      resolverlo hay que actualizar los cuatro lugares: los dos `.md` en
      `master` y los dos HTML en `gh-pages`.
- [x] **URL web pública de solicitud de eliminación de cuenta** (Play la
      exige aparte de la eliminación in-app):
      `https://elizaldemanuel1612.github.io/app-finanzas/eliminar-cuenta/`,
      publicada el 2026-08-24 en el mismo `gh-pages`, enlazada desde el
      índice. Explica qué se borra de inmediato desde la app (cuenta +
      todos los datos locales) y cómo solicitar la eliminación de la
      cuenta de Firebase Authentication cuando ya no se tiene la app
      instalada. **Sigue pendiente:** el mismo correo de contacto real que
      falta en privacidad/términos (ver arriba) — hoy usa el mismo
      marcador de posición.
- [ ] **Bundle IDs unificados** (Android `com.manuelelizalde.appfinanzas.app_finanzas`
      vs. el de iOS) — diferido a propósito hasta el mismo viaje a
      Firebase Console que registra la SHA-1 de firma (Bloque 5), porque
      cambiar `applicationId` invalida `google-services.json`. Ver
      "Estado actual" en `CLAUDE.md`.
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
      `UNREGISTERED_ON_API_CONSOLE` — **esperado**, porque esta huella
      todavía no está en Firebase, no es una regresión de R8.
      **Huellas para pegar en Firebase Console → Configuración del
      proyecto → tus apps → agregar huella:**
      SHA-1 `88:A9:6D:D5:10:C1:06:50:8B:56:A8:6B:39:4E:7E:35:BE:86:AB:4A`
      · SHA-256 `2F:33:0E:A8:22:7E:94:40:37:93:33:F7:A8:78:3A:D2:BD:A3:60:38:8F:4E:ED:E5:6C:87:33:5C:76:61:9E:28`.
      **Sigue pendiente (requiere Firebase/Play Console, fuera de
      alcance sin esas cuentas):** pegar esas huellas en Firebase, subir
      un `.aab` a la pista de pruebas internas de Play para que Play
      genere la *App signing key* (huellas distintas a las de arriba,
      hay que agregar esas también), y verificar el login **desde esa
      instalación** — la App signing key re-firma el bundle. **Guardar
      `upload-keystore.jks` y las contraseñas de `key.properties` en un
      lugar seguro fuera de este repo (gestor de contraseñas): perder el
      archivo después de la primera subida a Play significa no poder
      actualizar la app nunca más bajo esa ficha.**
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
- [~] Capturas de pantalla — 4 tomadas el 2026-08-24 en el emulador
      (`docs/tiendas/capturas/`: inicio, ajustes, guía, vista previa de
      importación). **Sigue pendiente:** `Gastos` y `Ciclos anteriores`
      salieron vacíos (la cuenta usada no tenía movimientos capturados;
      no se sembraron datos falsos a propósito); repetir esas dos con una
      cuenta de prueba con historial. También falta recortarlas al
      formato de marketing que piden las tiendas (no son las capturas
      crudas del dispositivo) y el gráfico destacado (feature graphic) de
      Play. El ícono de tienda en alta resolución ya puede salir de
      `assets/icono/icono_1024.png` (ver arriba), aunque sigue siendo
      placeholder.

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
