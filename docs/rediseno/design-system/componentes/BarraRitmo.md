# BarraRitmo

Una barra con una línea vertical que marca dónde deberías ir hoy. Se ve idéntica en Inicio, Categoría, Análisis y Gastos.

- Pista `graf-pista`, alto 8 (10 en héroe), marca de 2 px en `marca-ritmo` que sobresale 5 px arriba y abajo.
- Relleno: `exito` antes de la marca, `atencion` si la pasaste, y al rebasar el presupuesto la barra se re-escala: el presupuesto queda como un corte y el exceso en `peligro`. Nunca se llena entera de rojo.
- Siempre va con una frase debajo ("$3,290 de $7,700" o "Te pasaste por $620"): el color nunca es la única señal.
- Lector de pantalla: "Súper: gastaste tres mil doscientos noventa de siete mil setecientos. Vas bien."
- No: usar esta barra sin marca; dorado como relleno.
