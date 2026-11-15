# MAVfin

Tus finanzas, tu progreso. Sistema de diseño para la app de control de gastos por ciclo de pago, meta de ahorro y patrimonio, hecha en Flutter con Material 3 tematizado.

## Principios

1. **Una pantalla, una pregunta.** Inicio: ¿voy bien y cuánto puedo gastar hoy? Gastos: ¿en qué se me fue? Análisis: ¿por qué voy así y qué hago? Patrimonio: ¿cuánto tengo y cuánto debo? Si una pantalla responde dos preguntas, se parte.
2. **Tres niveles de profundidad.** *Vistazo* (la cifra héroe y su veredicto, en 2 segundos), *toque* (el detalle de una categoría, cuenta u objetivo) y *a fondo* (Análisis › Detalle e Historial). Lo que sabe de números baja; lo que no, se queda arriba y ya tiene su respuesta.
3. **Número + veredicto, no párrafos.** Toda cifra importante lleva un estado de una o dos palabras ("Vas bien") y, si hace falta, una frase corta que la interprete.
4. **Una sola verdad.** Un solo modelo de pronóstico (ritmo lineal del ciclo) y una sola recomendación por problema. La misma cifra se ve igual en todas las pantallas.
5. **Premium es calma.** Mucho aire, marfil y azul noche, cifras grandes en Outfit, el oro solo como joya. Nada compite con la cifra héroe.

## Contenido: menos texto, más señal

**La regla 1 · 6 · 12**
- **1** veredicto por pantalla, arriba.
- **6** palabras máximo por título, banner o botón.
- **12** palabras máximo por frase de apoyo. Si no cabe, va detrás de un toque.

**Cómo se reduce el texto**
- El estado lo dice un *chip* con ícono ("Vas bien", "Vas un poco rápido", "Te pasaste"), no una oración.
- Las explicaciones ("cómo se calcula") viven en una hoja que abre el ícono ⓘ, nunca fijas en la pantalla.
- Los subtítulos de lista dicen el dato, no la definición: "Salidas · Efectivo", no "Categoría: Salidas, pagado con efectivo".
- Montos: "$3,290 de $7,700" en vez de porcentajes. Sin signos (+/−) en la vista principal: "$620 más que en octubre".
- Centavos: en resúmenes se redondea a pesos; en movimientos y saldos se muestran, al 50 % y en `texto-2` dentro de la cifra héroe.

**Tono**: tuteo, español de México, nunca reprende y siempre ofrece salida.

| No | Sí |
|---|---|
| Excedido | Te pasaste por $620 |
| 132 % del presupuesto | Ya usaste todo lo de Salidas |
| Movimiento registrado con éxito | Listo, te quedan $1,880 |
| Rebalanceo sugerido | Cubre $620 con Auto |
| Para invertir | Sin gastar |
| Confianza baja | Estimado |
| 4 movimiento(s) | 4 gastos |

Formato: `$12,345.67`, "14 nov", "Ciclo Nov 2026", "Van 14 de 30 días".

## Fundamentos visuales

**Color.** Tokens semánticos en claro y oscuro (ver Colores). Reglas:
- `oro` solo en el botón ＋, el ícono de meta y el emblema. Nunca texto (para eso `oro-texto`), nunca gráficas.
- Los colores de estado (`exito`, `atencion`, `peligro`) solo significan estado. Los montos neutros (saldos, patrimonio, gastos) van en `texto`. Verde para dinero solo cuando es dinero que entra o crece.
- Cada estado tiene versión de gráfica (3:1) y de texto (4.5:1). `atencion` se ajustó a `#D18306` en claro para pasar 3:1 sobre blanco.
- `heroe-fondo` (azul noche) es la única superficie oscura en modo claro: una por pantalla.

**Tipografía.** Outfit para cifras y títulos (`cifra-heroe`, `titulo`, `seccion`); Plus Jakarta Sans para todo lo demás (`cuerpo-fuerte`, `cuerpo`, `etiqueta`). Cifras tabulares siempre. Nada menor a 13 px. Las cifras héroe escalan hasta 1.6× con el texto del sistema; el resto hasta 2×.

**Espacio.** Escala de 4 pt (`esp-4` a `esp-48`). Margen de pantalla 20 (16 en 360 pt). 24 entre tarjetas, 32 entre secciones.

**Forma.** Radios `radio-m` 14 (controles), `radio-l` 22 (tarjetas), `radio-xl` 28 (hojas), `radio-pill`. Bordes de 1 px en `borde`; en claro, `sombra-1` muy suave; en oscuro, solo borde.

**Movimiento.** 120 / 220 / 320 ms con `cubic-bezier(0.2, 0, 0, 1)`. Las barras crecen al entrar; las cifras héroe no cuentan hacia arriba. Con "reducir movimiento", fundidos de 100 ms y nada más.

## La marca de ritmo

El único elemento que el usuario aprende. Una barra con una línea vertical que marca dónde deberías ir hoy: antes de la marca, vas bien; después, vas rápido. Al rebasar el presupuesto, la barra se re-escala y el exceso sale en `peligro` después de un corte. Es idéntica en Inicio, Categoría, Análisis y Registrar (componente BarraRitmo).

## Navegación

Barra inferior: **Inicio · Gastos · ＋ · Análisis · Patrimonio**. Ajustes en el avatar (arriba a la derecha). Pantallas raíz sin flecha ←; segundo nivel con flecha y sin barra. El ＋ abre Registrar como hoja a pantalla completa desde cualquier raíz.

- Inicio → Detalle de categoría, Meta del ciclo, Fijos.
- Gastos → Detalle de gasto (editar, anular, duplicar).
- Análisis → Resumen · Detalle · Historial (ciclos anteriores y cierre).
- Patrimonio → Cuentas · Objetivos → Detalle de cuenta / objetivo.
- Ajustes → Tu plan (meta, categorías, día de corte), Suscripción, Apariencia, Seguridad, Tus datos, Ayuda, Legal.

## Iconografía

Íconos de trazo de 1.8 px, puntas redondas, en caja de 24 (clases `.ic .i-<nombre>` en `components/bundle.css`). Las categorías del usuario usan su emoji dentro de un círculo `superficie-hundida`. Íconos solos siempre con `aria-label`.

## Accesibilidad

- Texto 4.5:1 y gráficas o bordes de control 3:1 en ambos modos (verificado para todos los pares de este sistema).
- Áreas táctiles de 44 × 44 como mínimo.
- El color nunca va solo: chip con ícono y palabra, corte y segmento en la barra, rayado para "en curso".
- Lectores de pantalla: las cifras se leen con su contexto ("Hoy puedes gastar trescientos setenta y cinco pesos. Vas un poco rápido").

## Implementación (Flutter)

Cada token de color es un campo de una `ThemeExtension<MavColors>` con `lerp` para el cambio de tema; los estilos de texto van en `TextTheme` (`displayLarge` = `cifra-heroe`, `headlineSmall` = `titulo`, `titleMedium` = `seccion`, `bodyLarge` = `cuerpo`, `labelLarge` = `cuerpo-fuerte`, `labelMedium` = `etiqueta`). Componentes estándar tematizados: `FilledButton`, `OutlinedButton`, `TextButton`, `FilterChip`/`ChoiceChip`, `SegmentedButton`, `NavigationBar`, `ModalBottomSheet`, `SnackBar`, `MaterialBanner`. La barra de ritmo y las gráficas son `CustomPainter`.
