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
- [ ] **`file_picker` es superficie nativa nueva** (selector de archivos de
      "Importar gastos", Fase 6 posterior a este bloque): hay que volver a
      correr el guion manual de `docs/paridad-3-2-procedimiento.md` en
      dispositivo — el selector de archivos no está cubierto por
      `test/paridad/` ni por `test/ui/` — y revisar si Play Data Safety /
      App Privacy piden declarar acceso a archivos. Fijado en
      `12.0.0-beta.7` (prerelease, ver "Estado actual" en `CLAUDE.md`):
      confirmar que sigue siendo la versión correcta antes de publicar, por
      si ya salió una estable compatible con `share_plus`.
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
- [ ] **Política de privacidad y términos publicados en una URL pública.**
      Dentro de la app ya funciona: Ajustes → "Política de privacidad" /
      "Términos y condiciones" abre `lib/ui/comun/documento_legal.dart`,
      que renderiza `docs/legal/privacidad.md`/`terminos.md` (empaquetados
      como asset) directamente en la app — ya no depende de una URL
      externa para eso. Lo que **sigue pendiente** es la URL pública que
      las tiendas piden aparte, en la ficha de la app (Play Console /
      App Store Connect piden un link, no aceptan "está dentro de la
      app"): este repo no tiene remoto de GitHub configurado todavía, así
      que no hay GitHub Pages posible. Pendiente: crear el repo remoto,
      habilitar Pages, y publicar ahí el mismo contenido de
      `docs/legal/`.
      También pendiente: el correo de contacto real en la sección
      "Contacto" de ambos documentos (`_[correo de contacto pendiente de
      publicar]_`) — decisión del usuario aplazada a propósito.
- [ ] **URL web pública de solicitud de eliminación de cuenta** (Play la
      exige aparte de la eliminación in-app) — depende del mismo
      GitHub Pages de arriba.
- [ ] **Bundle IDs unificados** (Android `com.manuelelizalde.appfinanzas.app_finanzas`
      vs. el de iOS) — diferido a propósito hasta el mismo viaje a
      Firebase Console que registra la SHA-1 de firma (Bloque 5), porque
      cambiar `applicationId` invalida `google-services.json`. Ver
      "Estado actual" en `CLAUDE.md`.
- [ ] Firma con keystore propia + **ambas** huellas SHA-1/SHA-256 en
      Firebase (upload key y App signing key de Play), verificado desde
      la pista de pruebas internas — no hecho en esta sesión (requiere
      generar y resguardar un keystore, y acceso a Firebase/Play
      Console).
- [ ] Ícono y splash propios (`flutter_launcher_icons`,
      `flutter_native_splash`) — no hecho en esta sesión (requiere el
      arte, `assets/icono/icono_1024.png`, que no existe todavía).
- [ ] Sign in with Apple presente en el código — no hecho en esta sesión
      (Bloque 6, iOS); de cualquier forma no verificable sin Mac.
- [ ] Declaración de funciones financieras de Play: "Ninguna de estas"
      (documentado en `ficha-play.md`, pendiente de marcarla en Play
      Console al crear la ficha).
- [ ] Capturas de pantalla, gráfico destacado e ícono de tienda — no
      tomadas en esta sesión (requiere un dispositivo o emulador real).
      Las fuentes ya están empaquetadas, así que ya no hay que esperar a
      un pase de tipografía para tomarlas.

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
      global; labels verificados en `test/ui/semantica_test.dart`.
      **Gap conocido, no corregido:** el emoji 🎁 va concatenado dentro del
      mismo `Text` que la etiqueta en `pantalla_ciclos_anteriores.dart` y
      `pantalla_ingresos_del_ciclo.dart` — un lector de pantalla dice
      "gift emoji Cerrado" en vez de solo "Cerrado". Restructurar esos dos
      `Text` en un `Row` con el emoji excluido aparte queda pendiente.
- [ ] Minify/R8 — no hecho en esta sesión (depende de que exista firma
      propia primero, Bloque 5).

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
   `test/ui/escalado_test.dart`) cubren `BarraRitmo`, `GraficaEvolucion` y
   overflow a 2.0x, pero un recorrido real con TalkBack en dispositivo
   sigue siendo el único modo de confirmar que se escucha bien de punta a
   punta.
