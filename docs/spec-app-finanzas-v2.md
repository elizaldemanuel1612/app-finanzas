# Especificación técnica v2 — App de Finanzas Personales (iOS + Android)

> Revisión crítica de la v1. Los cambios están marcados con **[NUEVO]** o **[CAMBIO]** y cada uno responde a un error real y frecuente en apps financieras.

---

## 0. Principios de diseño (no negociables)

1. **El dinero nunca se pierde ni se duplica.** Toda escritura es idempotente y auditable.
2. **La app funciona sin señal.** La captura de un gasto jamás depende de la red.
3. **El dashboard nunca escanea todo el histórico.** Los agregados se precalculan.
4. **La IA sugiere, el usuario decide.** Ninguna categoría se aplica a ciegas cuando la confianza es baja.
5. **Nada se borra de golpe.** Al eliminar, el gasto desaparece de todas las listas y cifras al instante; internamente queda anulado 30 días para permitir deshacer y auditar.
6. **Las cifras son idénticas en iOS y Android.** Toda la lógica vive en una sola base de código compartida.

---

## 1. Integridad financiera

### 1.1 [CAMBIO] Los montos se guardan como enteros, no decimales
Guardar `$1,019.84` como número decimal (`Double`/`Float`) produce errores de redondeo que se acumulan: sumas de cientos de movimientos terminan desfasadas por centavos, y tu dashboard deja de cuadrar contra tu estado de cuenta.

**Regla:** todo monto se almacena en **centavos como entero** (`montoCentavos: Int` → `101984`) y solo se formatea a `$1,019.84` en la capa de presentación. Es el estándar de la industria financiera.

### 1.2 [NUEVO] Idempotencia en cada captura
El error #1 en apps de gastos: el usuario pica "Guardar", la red tarda, pica otra vez → gasto duplicado. O el dictado por voz se procesa dos veces.

**Regla:** cada movimiento se crea con un `clientId` (UUID generado en el dispositivo *antes* de enviar). Si el mismo `clientId` llega dos veces, el backend lo ignora. Cero duplicados, aunque falle la red a media escritura.

### 1.3 [NUEVO] Soft delete + bitácora de auditoría
Un registro financiero borrado hace que el histórico deje de cuadrar y no hay forma de saber por qué.

**Regla:** los movimientos nunca se eliminan. Se marcan `anulado: true` con `anuladoPor`, `anuladoEn`, `motivo`. Toda edición de monto o categoría se registra en una subcolección `auditoria` (valor anterior → valor nuevo → cuándo). Así siempre puedes reconstruir por qué cambió una cifra.

### 1.4 [CAMBIO] Estados del movimiento — sin bandeja de pendientes
```
activo → (anulado)
```
**Todo lo que el usuario registra entra de inmediato y cuenta.** La confirmación de un ticket o de un dictado ocurre en el momento de la captura, no después en una lista que hay que limpiar.

**Única excepción:** los movimientos que el sistema genera solo (recurrencias de gastos fijos y, a futuro, importación bancaria) nacen como `propuesto` y requieren un tap de confirmación — porque no los escribió el usuario. Un `propuesto` no cuenta en el dashboard hasta confirmarse.

**Anulación:** al eliminar un gasto, desaparece de todas las listas y de todas las cifras al instante. Internamente queda `anulado` 30 días, lo que permite deshacer y auditar; pasado ese plazo se purga.

---

## 1.5 [NUEVO] Tipo de categoría: fija o variable

Se define **al crear cada categoría**, con una sola pregunta: *¿el monto es siempre el mismo?* No se infiere del nombre — lo que es fijo para una persona (plan de celular) es variable para otra.

| | Fija | Variable |
|---|---|---|
| Pronóstico | **No se pronostica.** Es un dato. | Modelo MPC completo |
| Barra de ritmo | No aplica | Sí |
| Plan de ajuste | Excluida — no se puede recortar la renta | Incluida |
| Rebalanceo | No se le puede quitar presupuesto | Sí |
| Estado | Pagado / pendiente | % usado y proyección |
| Campos extra | `montoFijo`, `diaDelCiclo` | `presupuestoMensual` |

**Efecto en el pronóstico del ciclo:**
```
Cierre estimado = Σ fijas (determinista) + Σ variables (MPC)
```

**Si el monto real difiere del declarado**, la app pregunta si fue excepción de un mes o si actualiza el monto para los siguientes ciclos. Nunca lo cambia sola.

**Reparto del presupuesto:** las fijas se respetan tal cual y solo el sobrante se distribuye entre las variables. Si las fijas exceden lo disponible, se bloquea y se informa cuánto falta — nunca se generan montos negativos.

## 2. Ciclo de tarjeta como concepto de primera clase

### 2.1 [CAMBIO] El ciclo 12–11 se calcula en el servidor, no en la app
Tu Excel ya opera sobre ciclo de tarjeta (del 12 al 11). Si cada pantalla calcula ese ciclo por su cuenta, tarde o temprano dos vistas muestran cifras distintas para el mismo periodo — y pierdes confianza en la herramienta.

**Regla:** existe una colección `ciclos` con registros explícitos:
```
{ id: "2026-07", fechaInicio: 2026-07-12, fechaFin: 2026-08-11,
  etiqueta: "Jul", estado: "abierto" | "cerrado" }
```
Cada movimiento guarda su `cicloId` **al momento de crearse**. Nunca se recalcula sobre la marcha. Un solo lugar define la verdad.

### 2.2 [NUEVO] Cierre de ciclo
Al terminar un ciclo se congela un snapshot inmutable (presupuesto vs. real por categoría). Los ciclos cerrados ya no se recalculan → los históricos nunca cambian retroactivamente, y las tendencias mensuales son estables.

### 2.3 [NUEVO] Soporte para mes natural Y ciclo de tarjeta
Tu Excel ya alterna entre ambas bases. La app mantiene ambos ejes: `periodoNatural` (AAAA-MM) y `cicloId`, precalculados en cada movimiento. Cambiar de vista es instantáneo, sin recalcular nada.

---

## 3. Rendimiento: agregados precalculados

### 3.1 [NUEVO] El dashboard no lee movimientos
Si el dashboard suma miles de movimientos cada vez que lo abres, en 2 años tarda segundos en cargar y te cuesta dinero en lecturas de Firestore.

**Regla:** una Cloud Function mantiene una colección `rollups` que se actualiza en cada escritura:
```
rollups/{cuentaId}_{cicloId}_{categoriaId}
{ totalCentavos, conteoMovimientos, presupuestoCentavos,
  porcentajeUsado, ultimaActualizacion }
```
El dashboard hace **~20 lecturas** (una por categoría) en vez de miles. Carga en menos de 300 ms sin importar cuánto histórico tengas.

### 3.2 [NUEVO] Rollups también por mes y por tendencia
`rollups_tendencia/{cuentaId}_{periodo}` guarda el total del periodo listo para graficar. Tu gráfica de tendencia mensual (que hoy en Excel abarca hasta 2027) se dibuja con una sola lectura.

### 3.3 [NUEVO] Reconciliación nocturna
Los rollups pueden desincronizarse si falla una función. Una Cloud Function programada recalcula cada noche los rollups del ciclo abierto desde los movimientos crudos y corrige diferencias. Si detecta un desfase, te notifica. Esto es lo que te da **certeza** de que las cifras del dashboard son las reales.

### 3.4 [NUEVO] Índices compuestos definidos desde el inicio
Firestore falla en tiempo de ejecución si falta un índice. Se declaran por adelantado:
`(cuentaId, cicloId, anulado)` · `(cuentaId, categoriaId, fecha)` · `(cuentaId, estado)` · `(cuentaId, fecha desc)`

---

## 4. Offline-first

### 4.1 [NUEVO] La captura nunca depende de la red
Estás en el súper, en un estacionamiento, sin señal. Si la app no guarda, no la vas a usar — y una app de gastos que se usa a medias no sirve de nada.

**Regla:** persistencia local de Firestore activada + escritura optimista. El gasto se guarda local al instante, se muestra en la UI, y se sincroniza sola cuando vuelve la señal. Un indicador discreto muestra "pendiente de sincronizar".

### 4.2 [NUEVO] Resolución de conflictos
Si editas el mismo gasto desde dos dispositivos: gana la escritura más reciente por campo (no por documento completo), y el conflicto queda en la bitácora de auditoría. Nunca se pierde silenciosamente una edición.

### 4.3 [NUEVO] Cola de trabajos pesados
Fotos de tickets y notas de voz se encolan localmente y se procesan cuando hay conexión (y de preferencia con WiFi). No bloquean la captura.

---

## 5. Captura: mejoras significativas

### 5.1 [CAMBIO] OCR en dos niveles — primero en el dispositivo
La v1 mandaba toda foto a la nube. Eso es lento, cuesta por llamada y no funciona sin señal.

**Regla:** primero corre **ML Kit Text Recognition en el dispositivo** (gratis, instantáneo, offline, disponible en iOS y Android por igual). Solo si la confianza es baja se escala a la nube. Resultado: la mayoría de los tickets se leen en menos de 1 segundo sin costo y sin internet.

En iOS se puede usar además el Vision framework de Apple como segundo motor local cuando ML Kit devuelve baja confianza, antes de recurrir a la nube.

### 5.2 [NUEVO] Extracción estructurada del ticket
No solo el total: `comercio`, `fecha`, `total`, `subtotal`, `impuestos`, `últimos 4 dígitos de tarjeta`. El comercio detectado alimenta el motor de categorización (ver 6.2).

### 5.3 [CAMBIO] Voz: transcripción en el dispositivo, parsing después
La transcripción corre **en el dispositivo** usando el reconocedor nativo de cada sistema (`SFSpeechRecognizer` en iOS, `SpeechRecognizer` en Android), a través de una sola interfaz compartida. Solo el texto resultante se manda a parsear; el audio nunca sale del teléfono.

**Diferencia a atender:** en Android el modelo de idioma puede requerir descarga la primera vez. Si falta, la app ofrece descargarlo y explica por qué, en vez de fallar.

### 5.4 [NUEVO] Gastos recurrentes automáticos
Spotify ($239), gimnasio ($658.33), plan celular ($319), vivienda ($9,910)... registrarlos a mano cada mes es fricción innecesaria y la fuente #1 de "se me olvidó capturar".

**Regla:** motor de recurrencias que genera estos movimientos automáticamente al inicio del ciclo, en estado `propuesto` (§1.4). Te llega una notificación: "¿Confirmas tus 4 gastos fijos de este ciclo?" → un tap y listo.

### 5.5 [NUEVO] Captura por lote / múltiples renglones
Un ticket de súper puede tener partidas de categorías distintas (despensa + salud + limpieza). La app permite dividir un mismo ticket en varios movimientos que comparten `ticketId`.

### 5.6 [NUEVO] Widget y atajo de voz del sistema
Widget en pantalla de inicio para capturar en 1 tap, y atajo por voz del asistente ("Oye Siri" en iOS, "Ok Google" en Android). La fricción de captura es lo que decide si una app de gastos sobrevive al mes 3.

Es el **único código que se escribe dos veces** (WidgetKit + App Intents en iOS, Glance + App Actions en Android). Por eso se mantienen deliberadamente simples: muestran un solo dato y abren un solo flujo.

**El dato: cuánto queda hoy.** Lo que queda del presupuesto de las categorías **variables** del ciclo, repartido parejo entre los días que faltan contando hoy:

`quedaHoy = max(0, presupuestoVariables − gastadoVariables) ÷ (díasParaTerminar + 1)`

redondeado hacia abajo al centavo, para no prometer más de lo que hay. Las fijas no entran: ya tienen su monto apartado y no se "gastan por día". `presupuestoVariables` es el mismo que muestra Inicio en "Gastos Variables" (con los ajustes del ciclo aplicados). Lo calcula `domain/presupuesto/disponible_por_dia.dart`; la app lo publica al widget cada vez que Inicio se recalcula, y el widget nunca calcula nada por su cuenta.

**Los flujos.** El widget abre la captura (botón "Gasto") o la captura con el dictado ya escuchando (botón "Dictar"). El atajo de voz abre siempre el dictado. Siri no permite montos ni texto libre dentro de la frase que lo activa, así que es en dos pasos: "Oye Siri, registra un gasto en App Finanzas" → la app abre escuchando → "40 de cine en salidas con tarjeta" → el mismo `parsearDictado` de siempre llena la captura y el usuario confirma con "Listo".

**iOS.** El widget lee el dato de un App Group (`group.com.manuelelizalde.appfinanzas`). Si el App Group no está disponible (por ejemplo, con firma de Apple ID gratuito), el widget muestra solo los botones y la app no falla.

---

## 6. Categorización con IA: controlada y con costo acotado

### 6.1 [CAMBIO] Cascada de 3 niveles antes de llamar a la IA
Llamar a un modelo por cada gasto es lento y caro, y para el 90% de los casos es innecesario.

```
Nivel 1 — Reglas del usuario (instantáneo, gratis, offline)
          "Oxxo" → Super/Comida · "carnicería" → Super/Comida
Nivel 2 — Historial: ¿ya clasificaste este comercio antes?
          Si sí, se aplica la misma categoría automáticamente
Nivel 3 — IA (solo si los anteriores no resuelven)
```

### 6.2 [NUEVO] Tabla de aprendizaje de correcciones
Cada vez que corriges una sugerencia, se guarda en `reglas_aprendidas` (`patrón → categoría`, con contador de confirmaciones). El sistema mejora con el uso y las llamadas a la IA disminuyen mes con mes.

### 6.3 [NUEVO] Umbrales de confianza explícitos
- `≥ 0.90` → se aplica la categoría, con marca visual de "sugerida"
- `0.60 – 0.89` → se pide confirmación
- `< 0.60` → va a "Otros" y se marca para revisión

### 6.4 [NUEVO] Tope de costo mensual
Límite configurable de llamadas a la IA por mes. Si se alcanza, la app sigue funcionando perfectamente con reglas e historial (niveles 1 y 2). Nunca hay una sorpresa en la factura.

---

## 7. Seguridad y multiusuario

### 7.1 [CAMBIO] El modelo se ancla en `cuentaId`, no en `uid`
Este es el cambio arquitectónico más importante para tu requisito de "listo para más usuarios". Si los datos cuelgan del usuario, migrar a cuentas compartidas después implica rehacer el modelo completo.

**Regla:** desde el día uno, todo cuelga de `cuentas/{cuentaId}`. Hoy tú eres el único miembro; mañana agregar a alguien es insertar un registro en `miembros`, sin tocar el modelo de datos.

```
cuentas/{cuentaId}
  ├── miembros/{uid}  → { rol: "propietario" | "editor" | "lector" }
  ├── movimientos/
  ├── categorias/
  ├── ciclos/
  └── rollups/
```

### 7.2 [NUEVO] Reglas de seguridad de Firestore desde el inicio
No se deja para el final (error clásico que expone datos). Las reglas validan: pertenencia a la cuenta, rol suficiente, y que los montos sean enteros positivos. La validación vive en el servidor, no solo en la app.

### 7.3 [NUEVO] Bloqueo biométrico de la app
Face ID / Touch ID al abrir, configurable. Tu información financiera completa no debería quedar expuesta si alguien toma tu teléfono desbloqueado.

### 7.4 [NUEVO] Exportación y portabilidad
Exportar todo a Excel/CSV cuando quieras. No quedas atrapado en la app — y te da una red de seguridad psicológica al abandonar el Excel.

---

## 8. Migración desde el Excel: con verificación

### 8.1 [NUEVO] Migración con reconciliación obligatoria
Migrar sin verificar es cómo se pierden años de histórico en silencio.

**Proceso:**
1. Importar movimientos (los `HIST-####` conservan su ID original como `idOrigen`)
2. Calcular totales por categoría y por ciclo **en la app**
3. Comparar contra los totales del Excel
4. **Si no cuadra al centavo, la migración se detiene** y muestra exactamente qué renglones difieren

### 8.2 [NUEVO] Marca de origen del dato
Los registros históricos vienen como totales diarios agregados, no con detalle por compra. Se marcan `granularidad: "agregado_diario"` para que sepas que ese periodo no tiene el mismo nivel de detalle que lo capturado desde la app. Sin esto, en 6 meses no vas a recordar por qué mayo no tiene desglose.

### 8.3 [NUEVO] Periodo de operación en paralelo
Un ciclo completo usando app y Excel simultáneamente antes de apagar el Excel. Si al cierre ambos cuadran, migras con certeza total.

---

## 9. Alertas inteligentes

### 9.1 [CAMBIO] Alertas por ritmo de gasto, no solo por umbral
Avisarte al 100% del presupuesto llega tarde: ya te pasaste. Lo útil es avisar cuando la *proyección* dice que te vas a pasar.

**Regla:** la alerta compara tu ritmo de gasto contra los días transcurridos del ciclo:
> *"Salidas/Diversión: llevas 62% del presupuesto y solo van 9 días del ciclo. A este ritmo cerrarías en 165%."*

Esto es lo que convierte la app en herramienta de decisión, no solo de registro.

### 9.2 [NUEVO] Control anti-spam de notificaciones
Máximo una alerta por categoría por ciclo, y silenciables individualmente. Las apps que notifican de más terminan con las notificaciones apagadas — y entonces no sirven para nada.

### 9.3 [NUEVO] Resumen ejecutivo al cierre de ciclo
El día 11, notificación con el resumen del ciclo: variación por categoría, margen del periodo, y comparativo contra los 3 ciclos anteriores.

---

## 10. Calidad y confiabilidad

### 10.1 [NUEVO] Pruebas obligatorias antes de cada fase
- **Unitarias:** aritmética de dinero, cálculo de ciclos, generación de recurrencias
- **De integración:** sincronización offline → online, resolución de conflictos
- **De reconciliación:** que los rollups siempre cuadren con la suma de movimientos crudos

### 10.2 [NUEVO] Observabilidad
Crashlytics + logs estructurados. **Ningún monto ni descripción de gasto se escribe en logs** — solo IDs. Privacidad por diseño.

### 10.3 [NUEVO] Modo de datos de prueba
Un ambiente separado para probar sin contaminar tus datos reales. Fundamental durante las fases 1–3.

---

## 11. Roadmap revisado

**Fase 0 — Cimientos** *(nueva, y es la que más ahorra dolor después)*
Modelo `cuentaId` · aritmética en centavos · idempotencia · ciclos explícitos · reglas de seguridad · ambiente de pruebas

**Fase 1 — Núcleo funcional**
Auth (Apple/Google) · categorías y presupuestos editables · captura manual · offline-first · migración del Excel con reconciliación

**Fase 2 — Rendimiento y dashboards**
Rollups · reconciliación nocturna · dashboard ejecutivo · tendencia mensual · cierre de ciclo

**Fase 3 — Captura avanzada**
OCR en dispositivo + respaldo en nube · voz · recurrentes automáticos · widget y atajo de voz del sistema · captura por lote

**Fase 4 — Inteligencia**
Cascada de categorización · reglas aprendidas · alertas por ritmo de gasto · resumen ejecutivo de cierre

**Fase 5 — Multiusuario y pulido**
Invitaciones y roles · diseño visual final · exportación · accesibilidad

---

## 12. Los 3 cambios que más impacto tienen

Si algo de este documento hay que priorizar, es esto:

1. **`cuentaId` desde el día uno** (7.1) — sin esto, el multiusuario implica rehacer todo.
2. **Montos en centavos + idempotencia** (1.1, 1.2) — sin esto, la app pierde credibilidad la primera vez que no cuadra contra tu estado de cuenta, y ya no la vuelves a usar.
3. **Rollups precalculados** (3.1) — sin esto, la app funciona muy bien el primer año y se vuelve lenta y cara justo cuando ya tienes histórico valioso.
