# Rediseño UX/UI de MAVfin (nov 2026)

Fuente de verdad del rediseño. Va junto a `design-system/` (tokens, guía de contenido y componentes) y `pantallas/` (maquetas de referencia).

## Cómo leer las maquetas

`pantallas/*.dc.html` son maquetas, no código para copiar:
- Las clases (`.hero`, `.bar`, `.mark`, `.pill`…) están en `pantallas/estilos-pantallas.css`.
- Los colores son las variables `--<token>` de `design-system/tokens.json`.
- El `<script>` de abajo de cada archivo trae los datos de ejemplo y los estados: `estado` = normal / alerta / vacio / carga…, y `tema` = claro / oscuro.

Lo que cuenta es la estructura, la jerarquía, los textos exactos y los estados. Se implementa con los widgets y el tema de la app (`lib/ui/comun/tema.dart`, `paleta.dart`), respetando `CLAUDE.md`.

## Principios (resumen; detalle en design-system/README.md)

1. Una pantalla, una pregunta.
2. Regla 1 · 6 · 12: 1 veredicto por pantalla, títulos y botones de máximo 6 palabras, frases de apoyo de máximo 12. Las explicaciones van detrás de ⓘ.
3. Una sola verdad: un solo pronóstico (MPC) y una sola recomendación por problema, iguales en todas las pantallas.
4. La marca de ritmo es idéntica en toda la app. Cuando el gasto rebasa el presupuesto, la barra se re-escala: el presupuesto queda como un corte y el exceso va en `peligro`.
5. El oro solo en el ＋, el ícono de la meta y el emblema. Los montos neutros van en `texto`. El verde solo para estados.
6. Una sola tarjeta héroe (azul noche) por pantalla, como máximo.

## Navegación nueva

- Barra inferior: **Inicio · Gastos · ＋ · Análisis · Patrimonio**. Siempre visible en las raíces, sin flecha ←.
- Ajustes se abre desde el avatar (arriba a la derecha) y conserva Tu plan: meta, categorías y día de corte.
- **Patrimonio**: control segmentado Cuentas | Objetivos.
- **Análisis**: Resumen | Detalle | Historial. Historial reemplaza a "Ciclos anteriores" en Inicio.
- Segundo nivel (Categoría, Ajustes, detalle de cuenta): flecha ←, sin barra.
- Quitar de Inicio: tarjeta de cuentas, renglones de Ciclos anteriores y Objetivos, y el selector "Ordenar por". Las categorías que necesitan atención van primero.
- Quitar la vista "Cuentas" de Análisis (vive en Patrimonio).

## Etapas (cada una con `dart test`, `flutter analyze` y `flutter test test/ui` en verde)

**Etapa 0, lógica (antes que lo visual)**
- Un solo pronóstico por categoría y total (el MPC de `docs/modelo-pronostico-ciclo.md`) para Inicio, Análisis y Categoría. Hoy Análisis dice "cerraría $5,728.57 arriba" y el detalle de Salidas "cierre estimado $4,950".
- Un solo motor de recomendación de rebalanceo. Hoy Análisis sugiere "$620 desde Auto" y el detalle sugiere mover $3,290 desde Súper (todo lo gastado en Súper: bug).
- La recomendación sale de la categoría con más sobrante proyectado y se muestra igual en Inicio (banner), Análisis (Qué hacer) y Categoría.
- Las comparaciones "contra el ciclo pasado" solo aparecen con al menos un ciclo cerrado completo.

**Etapa 1, base visual**
- Pasar los tokens de `tokens.json` a `paleta.dart`/`tema.dart` (claro y oscuro), conservando los nombres existentes donde ya existan y el contraste vigilado por `ui_contraste_test.dart`. `atencion` de gráficas queda en `#D18306` en claro (3:1 sobre blanco).
- Tipografía en 6 ranuras: `cifra-heroe` 44/48 600, `titulo` 24/30, `seccion` 17/24 (Outfit); `cuerpo-fuerte` 15/22 600, `cuerpo` 15/22, `etiqueta` 13/18 500 (Plus Jakarta Sans). Cifras tabulares.
- Un solo componente de tarjeta (héroe / informativa / de lista) y el renglón de lista estándar.
- `BarraRitmo` única según `componentes/BarraRitmo.md`, con su corte y el segmento de exceso.
- Chip de estado (`Vas bien` / `Vas un poco rápido` / `Te pasaste`) con ícono.

**Etapa 2, Inicio + navegación** (`pantallas/Inicio.dc.html`)
- Encabezado: "Ciclo Nov 2026" y "1 – 30 nov · faltan 16 días", avatar a la derecha.
- Héroe: chip de estado, "Hoy puedes gastar" como cifra héroe, ritmo de variables, renglón de la meta del ciclo.
- Banner de alerta solo si hay uno (el más urgente), con su salida.
- Presupuesto: renglones con barra de ritmo, "Quedan $X" o "Te pasaste $X". Renglón Fijos con "Al día" o "Por pagar".
- Snackbar al guardar: "Listo, te quedan $1,880 en Salidas · Deshacer".
- Estados: vacío (día 1 con el plan cargado), carga (skeleton) y alerta.

**Etapa 3, Registrar en dos toques** (`pantallas/Registrar.dc.html`)
- Teclado numérico propio. Chips compactos de fecha (Hoy), cuenta (la última usada) y nota.
- Rejilla de categorías: tocar una guarda y cierra. Se resalta la sugerida.
- Sin monto, las categorías van deshabilitadas.
- Quitar los medios genéricos "Tarjeta" y "Efectivo": solo cuentas reales (`cuentaDe`). **Corrección 2026-11-22:** se ofrecen todas las cuentas activas (sin ahorro), incluidas las base; esconder "Efectivo" al haber otra de efectivo dejaba fuera la cartera del usuario. La que no se use se archiva en Tus cuentas.
- Voz y foto en el encabezado.

**Etapa 4, Gastos** (`pantallas/Gastos.dc.html`): selector de ciclo, búsqueda con filtros, renglones agrupados por día en un grupo (no tarjetas sueltas), ciclo cerrado con aviso info y "Reabrir", estado vacío y de carga.

**Etapa 5, Análisis** (`Analisis.dc.html`, `AnalisisDetalle.dc.html`): en Resumen, veredicto, "Qué hacer" (máximo 2) y "En qué se fue". En Detalle, cada gráfica lleva una frase-conclusión como título. En Historial, la gráfica de apartado por ciclo y la lista de ciclos cerrados.

**Etapa 6, Patrimonio, Objetivos, Categoría y Ajustes** (sus maquetas): héroe de patrimonio con su tendencia; cuentas agrupadas en Para gastar / Ahorro / Tarjetas; objetivos con barra de progreso y estado de fecha vencida; categoría con una sola acción primaria; Ajustes agrupado.

## Copy que cambia

| Antes | Ahora |
|---|---|
| Excedido | Te pasaste por $620 |
| Para invertir | Sin gastar |
| Rebalanceo sugerido | Cúbrelo con Auto |
| Confianza baja / rango | Estimado (~$9,580) |
| 4 movimiento(s) | 4 gastos |
| Chip 100 % / 66 % en la meta | "Apartas $11,550 de $11,550" |
| +$11,550 en rojo (contra el ciclo pasado) | "$1,800 → $4,470", con la frase arriba |
| Párrafos de ayuda en Cuentas | ⓘ con hoja |
