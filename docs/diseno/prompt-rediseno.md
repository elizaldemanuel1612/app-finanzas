# Prompt para el diseñador de Claude — rediseño de MAVfin (2026-11-14)

> Copia todo lo que está debajo de la línea y pégalo tal cual. Si el diseñador te deja adjuntar imágenes, agrega capturas de la app actual y de las apps que te gustan: ayudan más que cualquier descripción.

---

Eres un diseñador de producto senior especializado en apps móviles de finanzas personales. Rediseña la experiencia (UX) y la interfaz (UI) de **MAVfin**, una app de finanzas personales para México. El objetivo es que sea **más simple, más clara y más consistente** sin perder lo que ya hace. Quiero un **sistema de diseño estandarizado** (tokens, componentes y estados) y las **pantallas principales rediseñadas con ese sistema**.

## 1. Contexto del producto

- **Qué es:** una app para controlar gastos por ciclo de pago, cumplir una meta de ahorro mensual y ver tus cuentas, ahorros y patrimonio. Lema: "Tus finanzas, tu progreso".
- **Para quién:** personas en México que cobran una vez al mes (o por quincena) y quieren saber, sin hacer cuentas, si van bien y cuánto pueden gastar. No son expertos en finanzas.
- **Cómo funciona:** el usuario registra cada gasto a mano: con teclado, voz o foto del ticket. La app **no se conecta a bancos**, a propósito, por privacidad. Por eso registrar un gasto tiene que ser rapidísimo: monto → categoría → listo.
- **Plataformas:** iPhone y Android, hechas con Flutter (Material 3 personalizado); también como web app en el iPhone. Diseña **mobile-first a 390 × 844 pt**, solo en vertical. Revisa que funcione desde 360 pt de ancho.
- **Idioma:** todo en **español de México**, tuteando. Montos como `$12,345.67`; fechas como "14 nov".

## 2. Qué responde cada pantalla (no negociable)

Cada pantalla responde **una sola pregunta**. Si responde dos, se parte en dos.

| Pantalla | La pregunta que responde |
|---|---|
| Inicio | ¿Voy bien o no, y cuánto puedo gastar hoy? |
| Registrar gasto | ¿Cuánto y de qué? |
| Gastos | ¿En qué se me fue? (lista y búsqueda) |
| Análisis | ¿Por qué voy así y qué hago? |
| Cuentas | ¿Cuánto tengo y cuánto debo? |
| Objetivos | ¿Para qué ahorro y cuánto me falta? |
| Ciclos anteriores | ¿Estoy mejorando? |

## 3. Reglas de contenido y tono

- **Cada texto dice qué significa para el usuario, no qué hizo el sistema.** Ejemplos:
  - "Te pasaste por $1,931", no "variación negativa".
  - "Ya usaste todo lo de Salidas", no "132 % del presupuesto".
  - "Van 17 de 31 días", no "avance efectivo del ciclo".
  - "Listo, te quedan $2,546", no "Movimiento registrado con éxito".
- **Nunca reprender.** La app es una herramienta, no un juez. Ejemplo: "Vas un poco arriba. Con un ajuste chico cierras bien."
- **Toda alerta ofrece una salida concreta**, con un botón o enlace para resolverla.
- **Todo número importante va con una frase que lo interprete.** Ejemplo: "Si sigues así, apartas $11,550 de $11,550".
- **Pocos porcentajes y sin signos que interpretar** en la vista principal; el detalle queda para quien lo busque.

## 4. Lo que hoy existe (inventario a rediseñar)

Navegación actual: barra inferior con **Inicio · Gastos · [＋ dorado al centro] · Análisis · Ajustes**.

**Inicio.** Es la pantalla más cargada; hoy tiene, en este orden:
1. Tarjeta del ciclo: fechas y días que faltan, lo que entró este ciclo, lo gastado y lo que queda para invertir.
2. "Hoy puedes gastar $522.94".
3. Meta de este ciclo, con un chip de porcentaje.
4. Renglón "Ciclos anteriores".
5. Renglón "Objetivos de ahorro".
6. Tarjeta "Tus cuentas" con saldos y patrimonio.
7. Selector de orden (% usado / $ gastado).
8. Lista de categorías variables, con barra de ritmo.
9. Lista de gastos fijos, pagados y pendientes.

**Registrar gasto.** Monto con teclado numérico, categoría con chips, cuenta con la que pagó, fecha (Hoy / Ayer / calendario) y descripción. También tiene dictado por voz y foto del ticket.

**Gastos.**
- Selector de ciclo arriba ("‹ Ciclo Nov 2026 ▾ ›"); los ciclos cerrados llevan candado y solo se consultan.
- Búsqueda, y filtros por categoría y por medio de pago.
- Lista agrupada por día. Deslizar a la izquierda elimina; a la derecha, duplica.

**Análisis.**
- El mismo selector de ciclo, y tres vistas: Básico / Avanzado / Cuentas.
- Básico: veredicto en una frase, 2 recomendaciones y las 3 categorías donde más se gasta.
- Avanzado: resumen, recomendaciones, "¿Cuánto pesa cada parte?" (barras de plan contra real, con una línea del 80/20), dona por categoría, ritmo del ciclo (línea acumulada contra la línea pareja, con pronóstico punteado), comparación contra el ciclo pasado, últimos 6 ciclos, día de la semana con más gasto, dónde más gastas y tarjeta contra efectivo.

**Cuentas.**
- Patrimonio total: lo que tienes para gastar + ahorro e inversiones − lo que debes en tarjetas.
- Una gráfica del patrimonio por ciclo.
- La lista de cuentas: efectivo, débito, crédito (cuánto debes y cuánto crédito te queda) y ahorro.
- Cada cuenta tiene su detalle: abonar, ajustar o actualizar el valor, transferir o pagar la tarjeta, y su historial.

**Objetivos de ahorro.**
- Cada objetivo tiene nombre, monto, una cuenta de ahorro y una fecha opcional.
- Su avance es el saldo de esa cuenta, con una frase como "Aparta $5,888 por ciclo para llegar en julio 2027".

**Categoría (detalle).** Presupuesto, lo gastado, el pronóstico al cierre, el plan de ajuste y "mover presupuesto desde otra categoría".

**Ciclos anteriores y cierre de ciclo.**
- Gráfica de cuánto apartaste en cada ciclo, en una escala de color por alcance de la meta.
- Lista filtrable por periodo.
- Cierre del ciclo: meta contra lo apartado, presupuesto contra lo real, y la oferta de pasar lo apartado a tu ahorro.

**Ajustes.**
- Cuenta, apariencia (claro / oscuro / automático) y seguridad (PIN y Face ID).
- Ayuda: guía por temas y guías rápidas.
- Tu plan: meta, categorías, cuentas, objetivos y día de corte.
- Tus datos: respaldo en el Google Drive del propio usuario, exportar e importar CSV.
- Legal y cerrar sesión.

**Otros flujos:**
- Onboarding de 7 pasos: bienvenida, ciclo, ingreso, meta, categorías sugeridas, la marca de ritmo y la guía.
- Bloqueo con PIN y biometría.
- Login con Google.
- Guías rápidas de primera vez: hojas de 3 a 5 pasos.

## 5. Elementos de marca que se conservan

- **Paleta**, que puedes refinar pero no reemplazar:
  - Azul noche `#0B1F3B` para texto principal, botón primario y selección.
  - Oro `#D4AF37` **solo como acento**: el botón ＋ de registrar, el ícono de la meta y el emblema. No se usa para texto; el texto dorado es `#7A5C0A`.
  - Fondo marfil `#FCFAF7`, tarjetas blancas y bordes gris niebla `#E6E8EE`.
- **Colores de estado:** cada uno tiene una versión brillante para gráficas y otra oscura para texto, que debe pasar contraste AA.
  - Verde: `#16A34A` en gráficas, `#15803D` en texto.
  - Ámbar: `#F59E0B` en gráficas, `#92400E` en texto.
  - Coral: `#EF4444` en gráficas, `#B91C1C` en texto.
- **Modo oscuro** obligatorio: fondo `#0A1424`, tarjetas `#13213A`, texto `#EEF1F7` y azul de selección `#8DB4F2`. El oro se mantiene.
- **Tipografía:** Outfit para cifras grandes y títulos, y Plus Jakarta Sans para todo lo demás. No propongas Inter.
- **Logo:** aro dorado con montaña, bandera, flecha y barras.
- **La "marca de ritmo":** una barra de presupuesto con una línea vertical que indica dónde deberías ir hoy. Si la barra pasa la marca, vas rápido; si se queda antes, vas bien. Es **el único elemento que el usuario tiene que aprender**, y debe verse idéntico en toda la app.

## 6. Lo que te pido

### 6.1 Diagnóstico breve
Antes de diseñar, dime en una lista corta qué problemas de UX ves en el inventario de arriba: jerarquía, saturación, duplicados, navegación, consistencia. Ordénalos por impacto. Considera al menos estos:
- Inicio responde demasiadas preguntas a la vez.
- Algunas funciones viven en dos lugares; por ejemplo, Cuentas aparece en Inicio, en Ajustes y en Análisis.
- Hay cuatro tipos de "tarjeta" con estilos distintos.
- Ajustes mezcla configuración con funciones de uso diario: categorías, cuentas y objetivos.

### 6.2 Arquitectura de información
- Propón la navegación principal: qué va en la barra inferior, qué en un segundo nivel y qué se va a Ajustes.
- Justifica cada decisión. Mantén el botón ＋ siempre a un toque.
- Entrega un mapa de pantallas.

### 6.3 Sistema de diseño estandarizado

**Tokens:**
- Color: semánticos, no por tono. Por ejemplo `fondo`, `superficie`, `texto-principal`, `texto-secundario`, `borde`, `accion`, `exito`, `atencion`, `peligro`, cada uno en claro y oscuro.
- Tipografía: escala de 5 o 6 estilos máximo, con tamaño, peso e interlineado.
- Espaciado: escala de 4 pt.
- Radios, elevación o sombras, y duración y curva de las animaciones.

**Componentes, cada uno con anatomía, variantes, tamaños y TODOS sus estados** (reposo, presionado, enfocado, deshabilitado, cargando, error, seleccionado), en claro y oscuro:
- Botones: primario, secundario, de texto e ícono, y el FAB ＋.
- Campos: texto, monto (con "$" fijo y comas de miles automáticas) y búsqueda.
- Chips de selección y filtros, y control segmentado.
- Tarjetas. **Define un solo componente con pocas variantes**: héroe, informativa y de lista.
- Renglón de lista: con ícono o emoji, título, subtítulo, monto a la derecha y chevron; también deslizable.
- Barra de ritmo con la marca, barra de progreso (objetivo) y barra de proporción.
- Selector de ciclo y selector de fecha.
- Hojas inferiores (bottom sheets), diálogos de confirmación, snackbar y aviso o banner en tres tonos: info, atención y peligro.
- Encabezado de sección.
- Gráficas: barras, dona y línea con pronóstico punteado. Incluye estilo de ejes, etiquetas, leyenda y el tono atenuado para "en curso".
- Estado vacío, estado de carga (skeleton) y estado de error con reintento.

**Reglas de uso:** cuándo usar cada variante y qué **no** hacer. Por ejemplo: el oro nunca en texto; nunca más de un botón primario por pantalla.

### 6.4 Pantallas rediseñadas
Con el sistema anterior, diseña en claro y en oscuro:
1. **Inicio:** prioriza "¿voy bien?" y "hoy puedes gastar"; lo demás, a un toque.
2. **Registrar gasto**, en su versión más rápida posible: dos toques para lo normal.
3. **Gastos**, con el selector de ciclo, y un ciclo cerrado en modo de solo consulta.
4. **Análisis**, vista básica y avanzada.
5. **Cuentas y patrimonio.**
6. **Objetivos de ahorro.**
7. **Detalle de categoría.**
8. **Ajustes.**

Para cada pantalla muestra también su **estado vacío** (usuario nuevo, sin datos), su **estado de carga** y, donde aplique, el **estado de alerta**: te pasaste, ciclo cerrado o fecha vencida.

### 6.5 Accesibilidad (obligatoria)
- Contraste WCAG 2.2 AA: 4.5:1 para texto y 3:1 para gráficas y bordes de controles, en ambos modos.
- Áreas táctiles de 44 × 44 pt como mínimo.
- El color nunca es la única señal: acompáñalo con ícono, texto o forma.
- Debe funcionar con texto del sistema a 200 % sin cortes. Las cifras héroe pueden limitarse a 1.6×.
- Etiquetas para lectores de pantalla en gráficas y cifras: por ejemplo, "Gastaste mil novecientos pesos de dos mil".
- Respeta "reducir movimiento".

### 6.6 Entregables
1. Diagnóstico (6.1).
2. Mapa de navegación (6.2).
3. Sistema de diseño con tokens en una tabla que pueda pasar a código (nombre, valor en claro, valor en oscuro, uso).
4. Componentes con sus estados.
5. Pantallas en claro y oscuro.
6. Una lista de los cambios respecto a hoy, ordenados por impacto y esfuerzo, para implementarlos por etapas. **Empieza por Inicio**, que es la pantalla que más se ve.

## 7. Restricciones técnicas

- Se implementará en **Flutter con Material 3**, tematizando componentes estándar (`ThemeData`). Evita interacciones que no existan en Material o Cupertino sin justificarlas.
- Las gráficas se dibujan a mano, sin librerías: mantenlas simples.
- **Los ciclos no son meses de calendario:** van de un día de corte al siguiente (ej. "12 nov – 11 dic"). Cada ciclo se nombra por el mes en que empieza: "Ciclo Nov 2026".
- **Nada se borra, se anula.** Un ciclo cerrado solo se consulta; para editarlo hay que reabrirlo. El diseño debe dejar clara esa diferencia.
- **La app no da asesoría financiera** ni recomienda inversiones; solo muestra lo que el usuario registra.
