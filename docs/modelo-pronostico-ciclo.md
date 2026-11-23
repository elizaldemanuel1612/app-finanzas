# Motor de Pronóstico por Ciclo (MPC) — v1

Modelo de pronóstico de cierre de ciclo basado en el historial del usuario. **No usa extrapolación lineal.**

---

## 0. El problema con la extrapolación lineal

`(gastado ÷ días transcurridos) × días totales` falla por tres razones estructurales:

1. **Multiplica los eventos únicos.** Una reparación de auto de $4,000 el día 3 se convierte en $41,000 proyectados. El evento ya ocurrió y no se va a repetir, pero la fórmula lo repite 10 veces.
2. **Trata todos los días como iguales.** Si haces súper los sábados, tu ritmo el miércoles subestima y el domingo sobreestima. El error cambia según el día en que consultes.
3. **Ignora todo tu historial.** Usa solo el ciclo actual, cuando ya tienes ciclos cerrados que dicen mucho más sobre tu comportamiento real.

El MPC ataca cada uno por separado.

---

## 1. Principio central: separar lo que se repite de lo que no

Antes de proyectar nada, el gasto observado de cada categoría se parte en tres:

```
Observado_c = Base_c + Atípico_c + Comprometido_c
```

| Componente | Qué es | Cómo se trata |
|---|---|---|
| **Base** | Gasto recurrente, dentro de tu patrón normal | **Se proyecta** al resto del ciclo |
| **Atípico** | Eventos únicos muy lejanos a tu media | **Se suma una sola vez, no se proyecta** |
| **Comprometido** | Recurrentes conocidos que aún no caen (Vivienda, Spotify) | **Se suma en su fecha, sin estimar** |

Este solo cambio elimina el error más grande del método anterior. La reparación de $4,000 suma $4,000 al cierre — no $41,000.

---

## 2. Detección de atípicos (robusta, no por promedio)

Usar media y desviación estándar para detectar outliers es circular: el outlier contamina las mismas estadísticas que deberían detectarlo. Se usa **mediana y MAD** (Desviación Absoluta Mediana), que son resistentes a valores extremos.

**Para cada categoría, sobre el historial de montos individuales:**

```
mediana     = mediana(montos_históricos_c)
MAD         = mediana(|monto_i − mediana|)
z_modificado = 0.6745 × (monto − mediana) ÷ MAD
```

**Regla de decisión:**

| z modificado | Clasificación | Tratamiento |
|---|---|---|
| ≤ 3.5 | Normal | Entra a Base |
| 3.5 – 6.0 | Pico | **Winsorización**: se recorta al valor del percentil 95 de la categoría. El exceso pasa a Atípico. |
| > 6.0 | Atípico franco | Sale completo de Base, se suma como evento único |

**Salvaguarda contra MAD = 0:** si una categoría tiene montos casi idénticos (ej. Spotify), MAD tiende a cero y todo se ve atípico. Regla: si `MAD < 0.05 × mediana`, se usa `MAD = 0.05 × mediana`.

**Nunca se descarta silenciosamente.** Todo monto reclasificado queda visible en la app: *"Auto operación incluye $4,000 tratado como evento único (reparación, 14 jul). Sin él, proyectaría $6,180."*

---

## 3. Estacionalidad: peso de calendario en vez de días

En lugar de contar días restantes, se cuenta **cuánto peso de gasto** queda por delante.

**3.1 Perfil por día de semana (por categoría)**

Sobre el historial, para cada categoría `c` y cada día de semana `d`:

```
w_c(d) = gasto promedio en día d ÷ gasto promedio diario de la categoría
```

Ejemplo real esperado en Súper/Comida: sábado ≈ 2.4, domingo ≈ 1.3, martes ≈ 0.4. Los pesos se normalizan para que el promedio sea 1.

**3.2 Perfil de posición dentro del ciclo**

Algunas categorías se concentran al inicio del ciclo (justo después del corte) o cerca de quincena: la colegiatura que se paga el primer día, la despensa grande del mes. Con avance de calendario, el día 10 de 30 el modelo creía que faltaban dos tercios del gasto y proyectaba casi el triple.

**Implementado el 2026-11-21 como curva acumulada**, no como multiplicador por decil (la simulación de §9.1 midió que la curva directa acierta más con pocos ciclos):

```
F_c(d) = promedio, entre los ciclos cerrados con gasto, de
         (lo gastado hasta el día d del ciclo ÷ total de ese ciclo)

p_c = λ × F_c(día de hoy) + (1 − λ) × p_calendario        λ = n ÷ (n + 0.5)
```

`p_calendario` es el avance por día de semana de §3.3 y `n` los ciclos cerrados con gasto. Con un ciclo, λ = 0.67; con cuatro, 0.89. Si la categoría ya había gastado 95 % a esta altura en los ciclos pasados, `p_c` ≈ 0.95 y casi no se proyecta nada más; si este ciclo ya no se gasta, el estimado se queda en lo observado y `p_c` sigue subiendo con los días.

El día de cada gasto pasado se cuenta desde el inicio de su ciclo, que se toma del `cicloId` (`AAAA-MM`) con el mismo día de inicio del ciclo en curso: tras un cambio de día de corte, los ciclos anteriores quedan desfasados unos días, y eso se acepta.

**3.3 Peso combinado y avance real**

```
peso_día(t) = w_c(dow(t)) × v_c(t)

p_c = Σ peso_día(días transcurridos) ÷ Σ peso_día(todos los días del ciclo)
```

`p_c` es el **avance efectivo** de la categoría, no el avance del calendario. Si van 9 de 31 días (29% calendario) pero los dos fines de semana fuertes de Súper ya pasaron, `p_c` puede ser 42% — y la proyección lo refleja.

**Suavizado del perfil:** los pesos se suavizan contra el valor neutro (1.0) según cuántos datos los respalden:

```
w_final = λ × w_observado + (1 − λ) × 1.0        donde  λ = n ÷ (n + 8)
```

Con 4 sábados de historia, λ = 0.33 → el perfil se aplica con prudencia. Con 30 sábados, λ = 0.79 → se aplica casi completo. El modelo no se cree un patrón que vio tres veces.

---

## 4. Tres modelos según el tipo de categoría

La tipificación es automática, según frecuencia y variabilidad histórica.

### Tipo A — Fija / recurrente
*Vivienda, Spotify, Plan celular, Gimnasio*

Criterio: **lo declara el usuario al crear la categoría** (§1.5 de la spec técnica), no se infiere de estadísticas. La detección automática por coeficiente de variación se usa solo como sugerencia al momento de crearla, y como aviso si una categoría marcada variable resulta idéntica tres ciclos seguidos.

**No se pronostica.** Se suma el monto conocido en su fecha programada. Incertidumbre = 0.

Estas categorías quedan también fuera del plan de ajuste y del rebalanceo: no tiene sentido pedirle a alguien que gaste menos renta, ni quitarle presupuesto a un cargo que va a llegar igual.

### Tipo B — Variable frecuente
*Súper/Comida, Salidas, Auto operación (operación normal)*

Criterio: ≥8 movimientos por ciclo.

```
Proyección_B = Base_observada + (Base_esperada_restante) + Atípicos_observados
```

donde la base esperada del resto del ciclo combina tu historial con lo que llevas en este ciclo:

```
Base_esperada_restante = [ Z × (Base_obs ÷ p_c) + (1 − Z) × Histórico_c ] × (1 − p_c)

Z = p_c ÷ (p_c + 0.35)
```

**Qué hace `Z` (factor de credibilidad):** al inicio del ciclo (`p_c` = 0.1), Z = 0.22 → el pronóstico se apoya 78% en tu historial, porque tres días no dicen nada. A media ciclo (`p_c` = 0.5), Z = 0.59 → ya pesa más lo que está pasando ahora. Cerca del cierre (`p_c` = 0.9), Z = 0.72 → domina el ciclo actual. La transición es continua, sin saltos bruscos entre un día y otro.

### Tipo C — Esporádica / a golpes
*Salud, Pediatra, Corte cabello, Imprevistos*

Criterio: < 8 movimientos por ciclo. Aquí "pesos por día" no significa nada — o pasa o no pasa.

Se modela **frecuencia × severidad**:

```
λ_c = movimientos promedio por ciclo (histórico)
m_c = mediana del monto por movimiento

Proyección_C = Observado + [ λ_c × (1 − p_c) × m_c ]
```

Se usa **mediana**, no promedio, para que una consulta médica cara de una vez no infle todas las proyecciones futuras.

**Con posición dentro del ciclo (2026-11-21).** La fórmula de arriba reparte parejo lo que falta, y eso falla justo en lo que se paga una vez: el día 10, con la colegiatura ya pagada, seguía esperando 0.67 pagos más. Cuando se conoce en qué día del ciclo cayó cada gasto pasado, lo que falta sale de la historia a esta misma altura:

```
Falta_j(d)  = lo gastado después del día d en el ciclo cerrado j
Falta_c     = [ promedio(Falta_j) + mediana(Falta_j) ] ÷ 2

Proyección_C = Observado + Falta_c
```

El promedio solo se dejaría inflar por un ciclo con un gasto enorme; la mediana sola diría cero demasiado seguido en categorías de pocos gastos. Mitad y mitad fue lo que mejor midió.

**Tope por conteo (con 3 ciclos cerrados o más, y solo en categorías que nunca han pasado de 2 gastos en un ciclo):** nunca se esperan más gastos que los más que ha habido en un ciclo, menos los ya hechos:

```
Falta_c ≤ max(0, máximo de movimientos en un ciclo − movimientos de este ciclo) × m_c
```

Así, si el corte de cabello ya se pagó y nunca ha habido dos en un ciclo, no se espera otro. Con menos de 3 ciclos el máximo todavía no dice nada y el tope no se aplica. Tampoco en categorías de 3 gastos o más por ciclo: ahí, llegar pronto al máximo dice que este ciclo viene distinto, no que ya se acabó.

---

## 5. Suavizado entre ciclos

El `Histórico_c` de la sección 4 no es un promedio simple. Se construye así:

**Con 2–4 ciclos cerrados:** mediana de los totales winsorizados por categoría. La mediana resiste que un ciclo haya sido raro.

**Con 5+ ciclos:** promedio móvil exponencial (EWMA) con α = 0.4 sobre los totales winsorizados.

```
Histórico_c = α × Ciclo_{t−1} + α(1−α) × Ciclo_{t−2} + α(1−α)² × Ciclo_{t−3} + …
```

α = 0.4 significa que el ciclo pasado pesa 40%, el anterior 24%, el anterior 14%. Responde a cambios reales de estilo de vida sin que un solo mes malo domine.

**Detección de cambio de nivel:** si los últimos 2 ciclos difieren de la base histórica en más de 2 MAD *en la misma dirección*, se asume cambio estructural (aumento de renta, nuevo gasto fijo) y el histórico se reinicia a esos 2 ciclos. Evita que el modelo tarde medio año en aceptar una nueva realidad.

---

## 6. Rango, no número único

Un pronóstico puntual da falsa precisión. La app muestra un rango.

Sobre los errores históricos del propio modelo (ver §8), se calculan los cuantiles del error relativo por categoría:

```
P10 = Proyección × (1 + q₁₀)     escenario contenido
P50 = Proyección                  escenario central
P90 = Proyección × (1 + q₉₀)     escenario alto
```

**Cota inferior dura:** el pronóstico nunca puede ser menor a lo ya gastado más lo comprometido. Es imposible cerrar por debajo de lo que ya saliste.

**Presentación en la app:**
> Súper/Comida — cierre estimado **$9,200** (rango $7,800 – $11,400)

---

## 7. Escalera de arranque en frío

El modelo no puede fingir tener datos que no tiene. Degrada de forma explícita:

| Ciclos cerrados | Modelo activo | Qué se le dice al usuario |
|---|---|---|
| 0 | Presupuesto como pronóstico | "Sin historial. Mostrando tu presupuesto." |
| 1 | Histórico simple, sin estacionalidad | "Pronóstico preliminar, 1 ciclo de historial." |
| 2–3 | + detección de atípicos + credibilidad | "Precisión limitada, mejora cada ciclo." |
| 4–6 | + perfil de día de semana (suavizado) | "Pronóstico con estacionalidad." |
| 7+ | Modelo completo + intervalos calibrados | Sin advertencia. |

---

## 8. Control de subcaptura

Un pronóstico bajo puede significar que gastaste poco... o que dejaste de capturar. Son cosas opuestas y el modelo debe distinguirlas.

**Señal:** se compara el número de movimientos registrados a la fecha contra lo esperado por historial (ajustado por `p_c`).

```
densidad = movimientos_observados ÷ movimientos_esperados
```

| densidad | Acción |
|---|---|
| ≥ 0.75 | Normal |
| 0.40 – 0.74 | Bandera: *"Llevas menos movimientos de lo habitual. ¿Falta capturar algo?"* |
| < 0.40 | El pronóstico se marca como **no confiable** y se apoya en histórico, no en lo observado |

Sin esto, el modelo premia con un pronóstico optimista justo cuando dejaste de registrar — el peor incentivo posible.

---

## 9. Mejora continua (backtesting)

Al cerrar cada ciclo, automáticamente:

1. **Se mide el error** por categoría: `WAPE = Σ|real − pronosticado| ÷ Σ real`, evaluado en 4 momentos del ciclo (25%, 50%, 75%, 90% de avance) para saber no solo si acierta, sino desde cuándo.
2. **Se recalibran los intervalos** P10/P90 con los errores reales acumulados. Meta: que el rango contenga el valor real ~80% de las veces.
3. **Se reajustan parámetros** (α del EWMA, el 0.35 del factor Z, umbral de atípicos) contra todo el historial disponible.
4. **Campeón vs. retador:** los parámetros nuevos solo reemplazan a los vigentes si reducen el WAPE en el histórico completo. Nunca se adopta un cambio porque "se ve mejor" en el último ciclo.
5. **Bitácora de versiones:** cada ciclo queda archivado con la versión del modelo que lo pronosticó. Siempre se puede auditar por qué el modelo dijo lo que dijo.

### 9.1 Simulación del 2026-11-21

`tool/simular_pronostico/simular.dart` (`dart run tool/simular_pronostico/simular.dart`) genera 40 historiales de 9 ciclos con once tipos de categoría (pago al inicio, una vez al ciclo, quincenal, súper, salidas, gasolina, salud, gasto hormiga…) y, para cada ciclo y cada día, compara lo que cada variante habría estimado ese día contra el cierre real. Son datos generados, no de un usuario.

| Error promedio del total, días 6–10 | 1 ciclo | 2–3 ciclos | 4–8 ciclos |
|---|---|---|---|
| Modelo anterior (avance de calendario) | 13.9 % (sesgo +10.1 %) | 13.7 % (+11.6 %) | 14.4 % (+13.0 %) |
| Con posición dentro del ciclo (§3.2 y Tipo C) | 12.4 % (+0.2 %) | 9.9 % (−0.5 %) | 8.5 % (−1.1 %) |
| Regla de tres | 41.1 % (+40.7 %) | 42.6 % (+42.6 %) | 41.3 % (+41.2 %) |

Por categoría, días 6 a 20: un pago al inicio del ciclo pasó de 66 % de error (siempre de más) a 1.4 %; muchas compras concentradas en la primera semana, de 73 % a 15 %; un gasto quincenal, de 23 % a 4 %. Las categorías de gasto repartido (súper, gasto hormiga) quedan prácticamente igual (23 % → 25 %, 11 % → 11 %). Lo que no mejora es lo impredecible por naturaleza (salud, imprevistos: ~50–60 % con cualquier variante).

También se probaron y se descartaron: el multiplicador por decil suavizado con λ = n ÷ (n + 8) (se queda corto con pocos ciclos), escalar lo que falta por cómo va el ciclo en categorías esporádicas (más ruido), y el tope por conteo desde el primer ciclo o en cualquier categoría esporádica (se queda corto: sesgo de −2 a −5 %).

---

## 10. Salida del modelo

Por categoría y por ciclo:

```
{
  categoria, tipo: "A"|"B"|"C",
  observadoCentavos, baseCentavos, atipicoCentavos, comprometidoCentavos,
  avanceEfectivo,            // p_c
  pronosticoP50Centavos,
  pronosticoP10Centavos, pronosticoP90Centavos,
  confianza: "alta"|"media"|"baja",
  densidadCaptura,
  explicacion: [ "texto legible de qué movió el número" ],
  versionModelo, cicloId
}
```

El campo `explicacion` es obligatorio. Un pronóstico que no puede explicarse en una frase no se muestra.

---

## 11. Implementación

- Corre como **Cloud Function programada**, una vez al día (madrugada) y ante cada confirmación de movimiento.
- El mismo código, escrito en Dart puro y sin dependencias de plataforma, se ejecuta también en el dispositivo para dar respuesta inmediata al capturar. Si servidor y dispositivo difieren, **gana el servidor**. Esto garantiza que el pronóstico sea idéntico en iOS y en Android.
- Escribe en la colección `pronosticos/{cuentaId}_{cicloId}_{categoriaId}` — la app solo lee, nunca calcula. Consistencia garantizada entre pantallas.
- Aritmética en **centavos enteros** (§1.1 de la spec técnica).
- Los perfiles de estacionalidad se recalculan semanalmente, no en cada corrida.

---

## 12. Limitaciones honestas con tus datos de hoy

Vale la pena que esto quede escrito antes de construirlo:

1. **Tienes 3 ciclos** (may, jun, jul). Según §7, eso ubica al modelo en el nivel "2–3": detección de atípicos y credibilidad sí; perfil de día de semana todavía no confiable.
2. **May y jun se importaron como totales diarios por categoría**, sin detalle por compra. Eso significa:
   - El perfil por día de semana **sí** es recuperable (los totales tienen fecha).
   - El modelo de frecuencia × severidad (Tipo C) **no** — no hay conteo de movimientos individuales. Solo se puede entrenar de julio en adelante.
3. **La detección de subcaptura (§8) necesita ~4 ciclos** capturados con la app para tener una línea base creíble.

**Actualización importante:** al separar categorías fijas de variables, **$11,126 mensuales dejaron de depender del modelo** — el 21% del gasto del ciclo pasó de ser estimación a ser dato. Eso reduce el error esperado del pronóstico total sin necesitar más historial.

Consecuencia sobre los ciclos históricos: mayo y junio estaban subestimados en $11,126 cada uno porque los fijos se pagaban sin capturarse. Los totales reales son **$68,911** (may) y **$42,674** (jun), no $57,785 y $31,548.

**Conclusión práctica:** el modelo entra en operación desde el primer día con lo que hay, marcando su propia confianza como "media", y alcanza precisión plena alrededor del ciclo 7 (≈ marzo 2027 si empiezas ahora). Eso es honesto y es lo normal — cualquiera que prometa buen pronóstico con 3 ciclos de datos está adivinando.
