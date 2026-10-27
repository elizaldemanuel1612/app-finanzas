# Addendum v3 — Plan de ajuste, simplicidad y motivación

Revisión de las specs v1 y v2 contra un criterio que faltaba: **que cualquiera pueda usarla, quiera abrirla, y mejore mes a mes.**

---

## 1. Qué le faltaba a las specs anteriores

Las specs v1 y v2 resolvían bien la parte de ingeniería (integridad, rendimiento, pronóstico) pero fallaban en tres cosas:

| Hueco | Consecuencia |
|---|---|
| **Diagnostican, no proponen** | La app decía "vas al 132%" y ahí te dejaba. Saber que vas mal sin saber qué hacer genera culpa, y la culpa hace que dejes de abrir la app. |
| **Sin conexión con el objetivo** | Nada ligaba el gasto contenido con tu meta real (invertir). Ahorrar sin ver para qué se siente a castigo. |
| **Lenguaje de analista** | "Variación", "% usado", "avance efectivo". Correcto y frío. Nadie que no lleve un Excel lo entiende de un vistazo. |

Las tres se atacan abajo.

---

## 2. Motor de Plan de Ajuste (nuevo)

### 2.1 Cuándo se dispara
Cuando el pronóstico (MPC) proyecta cierre por encima del presupuesto de una categoría, **y todavía queda ciclo para corregir** (≥ 3 días). Si no queda margen de acción, no se muestra: un consejo que ya no se puede seguir solo genera frustración.

### 2.2 Cálculo del ritmo objetivo

```
Disponible = Presupuesto − Gastado − Comprometido_restante

Sugerido_día(t) = Disponible × w_c(dow(t)) ÷ Σ w_c(dow) de días restantes
```

El reparto **no es plano**. Usa el mismo perfil de día de semana del MPC, así que respeta tus días fuertes en vez de pedirte una disciplina uniforme que nadie sostiene.

### 2.3 El mensaje
Tres piezas, en este orden, sin excepción:

1. **Cuánto queda** — "Te quedan $3,026 para 14 días"
2. **Contra tu costumbre** — "Normalmente gastas $1,758 por semana"
3. **El número a seguir** — "Apunta a $1,513" · "$216 al día"

Nunca se muestra el porcentaje de recorte solo. "Recorta 14%" no es accionable; "$216 al día" sí.

### 2.4 Comparación honesta de periodos
**Error detectado en pruebas:** al comparar "semana habitual" contra "semana sugerida", los tramos restantes del ciclo casi nunca son semanas completas. Dividir el disponible entre el número de tramos y compararlo contra una semana de 7 días produjo un recorte reportado de 43% cuando el real era 14% — un error que habría hecho ver el plan como imposible y lo habría vuelto ignorable.

**Regla:** toda comparación se normaliza a **gasto por día** internamente, y solo se presenta en semanas cuando ambos lados son de 7 días. Los tramos parciales se etiquetan con su duración ("4 días", "cierre de ciclo").

### 2.5 Rebalanceo entre categorías
Cuando una categoría ya se pasó y no hay forma de recuperar dentro de ella, la app ofrece mover presupuesto desde categorías con holgura proyectada.

```
Holgura_c = Presupuesto_c − Pronóstico_c    (solo si > 0)
```

Se ofrecen las 3 mayores. El usuario decide, candidata por candidata, cuánto mover de cada una; nunca se rebalancea solo ni con un reparto automático. El movimiento es **temporal**: es un ajuste vigente solo para el ciclo en curso, nunca cambia el presupuesto base de ninguna categoría (`CategoriaVariable.presupuestoMensualCentavos` permanece intacto para todos los ciclos futuros). Se guarda como un delta acumulable — un mismo ciclo puede tener varios rebalanceos, y cada uno se suma a los anteriores en vez de reemplazarlos.

### 2.5.1 Reajuste al cambiar el ingreso base
Los presupuestos de las categorías se guardan como montos, no como porcentajes. Si el usuario cambia su ingreso base (porque se equivocó al capturarlo o porque de verdad cambió), los montos no se mueven solos y pueden quedar muy por encima o muy por debajo del ingreso nuevo — p. ej. ingreso $350,000 corregido a $35,000 con categorías que suman $315,000.

Por eso, al guardar un ingreso base distinto, la app **pregunta** si reajusta las categorías activas en la misma proporción:

```
Nuevo_c = Presupuesto_c × IngresoNuevo ÷ IngresoAnterior
```

redondeado hacia abajo al peso entero, con mínimo de $1 (ningún presupuesto queda en cero). Aplica igual a fijas (monto fijo) y variables (presupuesto mensual), y a la meta de apartado solo si es por monto — la meta por porcentaje ya se ajusta sola. Las categorías archivadas no se tocan. El usuario puede contestar "Dejar como están": nunca se reajusta sin preguntar.

En el onboarding, la sugerencia de cada categoría (fija o variable) es un **porcentaje fijo del ingreso** capturado (Vivienda 30 %, Súper 20 %, Salidas 10 %, Auto 10 %, Salud 5 %, Hijos 10 %, Gimnasio 3 %, Suscripciones 2 %), redondeado hacia abajo al peso; ninguna trae un monto absoluto de fábrica. Cada sugerencia es **independiente**: editar una nunca mueve las demás, y lo que no se asigna queda sin asignar (es "lo que sobre" para apartar). Antes (hasta 2026-10-26) se repartía por peso todo lo disponible entre las no editadas, lo que obligaba a asignar el 100 % y anulaba la meta "Lo que sobre". Si la suma más la meta rebasa el ingreso, se avisa y se ofrece "Usar la sugerencia"; nunca se recorta nada solo.

### 2.6 Guardarraíles
- **Nunca sugerir por debajo de un mínimo digno.** Categorías marcadas como necesarias (Súper, Salud, Vivienda) tienen piso configurable. La app no propone dejar de comer.
- **Un plan por categoría por ciclo.** Recalcular el plan cada día lo vuelve ruido.
- **Si el disponible es negativo**, no se inventa un ritmo: se pasa directo a rebalanceo o a aceptar el sobrecosto y proteger el resto del ciclo.

---

## 3. Principios de simplicidad

### 3.1 Una pregunta por pantalla
| Pantalla | La única pregunta que responde |
|---|---|
| Inicio | ¿Voy bien o no? |
| Plan | ¿Cuánto puedo gastar? |
| Captura | ¿Cuánto y de qué? |
| Progreso | ¿Estoy mejorando? |

Si una pantalla responde dos preguntas, se parte en dos.

### 3.2 Un solo elemento que hay que aprender
**La marca vertical** = dónde deberías ir hoy. Barra pasada de la marca: vas rápido. Barra corta: vas bien. Se explica una vez en el onboarding y se usa en toda la app, idéntica — y queda consultable en la guía (Ajustes → "Cómo funciona la app") para quien quiera repasarla.

No hay porcentajes que interpretar, ni variaciones con signo, ni ciclos que entender. Esos datos siguen existiendo, pero en la vista de detalle, para quien los busque.

### 3.3 Vocabulario
| No decir | Decir |
|---|---|
| Variación negativa | Te pasaste por $1,931 |
| 132% del presupuesto | Ya usaste todo lo de salidas |
| Avance efectivo del ciclo | Van 17 de 31 días |
| Movimiento registrado con éxito | Listo — te quedan $2,546 |

Cada texto de la app dice **qué significa para el usuario**, no qué hizo el sistema.

### 3.4 Regla de los dos taps
Registrar un gasto: monto → categoría → hecho. Foto y voz viven dentro del mismo teclado, no en menús aparte. Si capturar cuesta trabajo, no hay datos; sin datos, nada de lo demás sirve.

---

## 4. Motivación (sin volverla un juego tonto)

### 4.1 Cada peso conectado al objetivo
El objetivo declarado es maximizar lo invertible. Por eso el Inicio cierra con:

> **$34,897** es lo que vas a poder invertir este ciclo.
> Si cierras Salidas en presupuesto, suben a **$42,454**.

Convierte "no gastes" en "esto ganas". Es la diferencia entre restricción y decisión.

### 4.2 Logros que premian conductas correctas
Solo se premia lo que mejora tus finanzas:

| Logro | Conducta que refuerza |
|---|---|
| Racha de días registrando | Captura constante (sin datos no hay sistema) |
| Ciclo cerrado en verde | Cumplir presupuesto |
| Categoría sostenida 3 ciclos | Cambio de hábito, no esfuerzo puntual |
| Mejora vs ciclo anterior | Progreso propio, no comparación con otros |

**Ninguna mecánica premia gastar, ni compara contra otras personas.**

### 4.3 Progreso visible, no solo estado
La gráfica por ciclo con la proyección punteada al lado es la pantalla que sostiene el hábito: ver que bajaste de $57,785 a $31,548 y que este ciclo va arriba mueve más que cualquier alerta.

### 4.4 Tono ante el error
Nunca reprender. "Vas un poco arriba. Nada grave, con un ajuste chico cierras bien." La app es una herramienta, no un juez. Una app que hace sentir mal se desinstala.

---

## 5. Pruebas ejecutadas sobre el mockup

Antes de entregarlo se corrieron validaciones automáticas:

| Prueba | Resultado |
|---|---|
| Balance de etiquetas HTML | ✅ |
| Variables CSS usadas sin definir | ✅ ninguna |
| Clases en HTML sin regla CSS | ✅ ninguna |
| Anchos de barra > 100% | ✅ ninguno |
| Suma del plan semanal = disponible | ❌ → **corregido** (faltaba el tramo de cierre; sumaba $2,348 de $3,026) |
| Coherencia del % de recorte | ❌ → **corregido** (decía 43%, el real es 14%) |
| Meses restantes del fondo | ❌ → **corregido** (decía 8, son 9) |
| Proporción del sparkline vs cifras reales | ✅ |
| Disponible diario, margen y potencial | ✅ |

Las tres fallas eran de coherencia aritmética entre el texto y los datos — exactamente el tipo de error que en una app financiera destruye la confianza del usuario, porque son invisibles hasta que alguien saca la calculadora.

---

## 6. Hallazgo del historial que cambió el diseño

El ejemplo original asumía compras de súper en fin de semana. **Los datos dicen otra cosa:** los días fuertes son martes, miércoles y domingo; viernes a domingo concentra 46% del gasto, casi idéntico a su proporción natural de días (43%).

Por eso el plan de ajuste no reparte por "fin de semana": reparte por el perfil real de cada categoría. Un consejo construido sobre un supuesto equivocado se siente ajeno y se ignora — y ese es el modo de falla más común de las apps de finanzas personales.

**Advertencia de confianza:** este perfil sale de 8 semanas de datos. El propio modelo lo suavizará contra el valor neutro hasta tener más historial (§3.3 del MPC), y la app debe marcarlo como "patrón preliminar" mientras tanto.
