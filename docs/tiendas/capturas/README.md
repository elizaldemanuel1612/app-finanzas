# Capturas de pantalla — estado

Capturas reales tomadas del emulador `finanzas_pixel7` (Android 16, API 36):

- `inicio.png` — Pantalla de inicio con el ciclo en curso (actualizada
  2026-08-31, con historial importado — ver abajo).
- `gastos.png` — Lista de gastos con movimientos reales (nueva, 2026-08-31).
- `ajustes.png` — Ajustes, incluida la entrada "Cómo funciona la app"
  (2026-08-24).
- `guia.png` — Guía por temas (lista de temas) (2026-08-24).
- `importar_vista_previa.png` — Vista previa de `previsualizarImportacion`
  tras elegir un CSV con el selector nativo (`file_picker`) (2026-08-24).

`inicio.png` y `gastos.png` se retomaron el 2026-08-31 en una cuenta nueva
de prueba (no la cuenta real del usuario), importando
`gastos_prueba_onboarding.csv` (20 movimientos de ejemplo, ya usado en
sesiones anteriores para pruebas) vía "Importar gastos" — así que la cifra
que se ve ahí es historial de prueba, no datos reales de nadie.

**Lo que falta para la ficha de tienda real:**
- `Ciclos anteriores` sigue en estado vacío ("Todavía no hay ciclos
  anteriores") — es correcto: es una cuenta recién creada, con el primer
  ciclo todavía en curso (`calcularEvolucionCiclos` solo agrega ciclos ya
  cerrados, por diseño — ver `CLAUDE.md`). No se puede poblar sin una
  cuenta que ya lleve meses de uso real o sin manipular el reloj del
  sistema — ninguna de las dos es un dato honesto para una captura de
  tienda, así que se deja pendiente hasta que exista una cuenta de prueba
  con historial de varios ciclos cerrados.
- Estas son capturas crudas del dispositivo (1080×2400), no los recortes
  con marco/texto de marketing que piden Play Console / App Store Connect.
- Falta el gráfico destacado (feature graphic) de Play y el ícono de
  tienda en alta resolución (esto último puede salir directo de
  `assets/icono/icono_1024.png` una vez que exista el arte final, ver
  `docs/tiendas/checklist-publicacion.md`).
