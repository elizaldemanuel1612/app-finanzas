# Capturas de pantalla — estado

Capturas reales tomadas del emulador `finanzas_pixel7` (Android 16, API 36)
el 2026-08-24, con la cuenta real de la sesión (sin datos de prueba
inventados a propósito, para no ensuciar el historial real):

- `inicio.png` — Pantalla de inicio con el ciclo en curso.
- `ajustes.png` — Ajustes, incluida la entrada "Cómo funciona la app".
- `guia.png` — Guía por temas (lista de temas).
- `importar_vista_previa.png` — Vista previa de `previsualizarImportacion`
  tras elegir un CSV con el selector nativo (`file_picker`).

**Lo que falta para la ficha de tienda real:**
- `Gastos` y `Ciclos anteriores` salieron en estado vacío ("Nada por aquí" /
  "Todavía no hay ciclos anteriores") porque esta cuenta no tenía gastos
  capturados — no se sembraron datos falsos para no alterar el historial
  real. Repetir con una cuenta de prueba que sí tenga movimientos para esas
  dos pantallas.
- Estas son capturas crudas del dispositivo (1080×2400), no los recortes
  con marco/texto de marketing que piden Play Console / App Store Connect.
- Falta el gráfico destacado (feature graphic) de Play y el ícono de
  tienda en alta resolución (esto último puede salir directo de
  `assets/icono/icono_1024.png` una vez que exista el arte final, ver
  `docs/tiendas/checklist-publicacion.md`).
