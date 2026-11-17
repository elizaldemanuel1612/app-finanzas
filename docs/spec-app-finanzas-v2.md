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

### 2.4 [NUEVO] Cambiar el día de corte

> **Al elegirlo en el onboarding (2026-11-04):** quien acaba de descargar la app no sabe qué es un ciclo. El paso "¿Cuándo empieza tu mes?" explica para qué sirve (el periodo en que se renueva el presupuesto), qué significa cada opción (corte de tarjeta, mes natural, otro día) y muestra con fechas cómo quedaría el ciclo de hoy.
El usuario puede cambiar su día de corte después del onboarding (cambió de tarjeta, o prefiere otro día). El cambio **nunca reescribe el historial**: los ciclos cerrados no cambian (regla #6) y cada movimiento conserva el `cicloId` con que se creó (regla #5).

**Historial de cortes.** El perfil guarda cada cambio (`cambiosDeCorte`: día anterior, día nuevo, inicio de la transición y fecha desde la que rige el nuevo). La calculadora de ciclos usa ese historial, así que un gasto con fecha pasada —capturado tarde o importado— cae en el ciclo que le tocaba con el corte vigente en esa fecha.

**Ciclo de transición.** El ciclo en curso se convierte en el ciclo de transición: empieza donde ya empezaba (mismo `id`, así que todo lo ya registrado sigue ahí) y termina el día anterior al primer corte con el día nuevo. La app propone dos fechas y **el usuario elige**:
- el primer corte nuevo posible → la transición queda más corta, o
- el corte del mes siguiente → la transición queda más larga.

Se recomienda la duración más cercana a 30 días. Las dos opciones cumplen: el primer ciclo nuevo empieza después de hoy (la transición siempre incluye hoy) y en un mes posterior al inicio de la transición (los `id` AAAA-MM nunca se repiten).

**Presupuestos e ingreso.** No se prorratean: la pantalla dice cuántos días dura la transición y que los presupuestos son por ciclo, para que el usuario lo tome en cuenta. La marca de ritmo usa las fechas reales del ciclo, así que el ritmo esperado sigue siendo correcto aunque el ciclo sea más corto o más largo.

**Cambio pendiente.** Mientras el nuevo corte no entra en vigor, un segundo cambio reemplaza al primero; si el usuario regresa a su día original, el cambio se cancela y el ciclo en curso recupera sus fechas normales.

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

### 4.2.1 [NUEVO] Respaldo y sincronización en el Google Drive del usuario (opcional)
Los datos viven en el dispositivo (la captura nunca depende de la red, §4.1). El usuario **decide** si además guarda una copia **en su propio Google Drive**, en la carpeta privada de la app (`appDataFolder`, permiso `drive.appdata`): ocupa su espacio, no aparece entre sus archivos, solo esta app puede leerla y **quien desarrolla la app no tiene acceso** — los datos financieros nunca pasan por un servidor propio (2026-10-26; antes era Firestore en `cuentas/{uid}`, descartado por privacidad). La copia es un solo archivo, `respaldo.json`, con las colecciones del §4.1. Se activa en Ajustes → Tus datos → "Respaldo en tu Google Drive"; la primera vez Google pide el permiso.

**Al activar**, si la nube y el dispositivo tienen datos, el usuario elige:
- **Combinar** (recomendado): junta ambos; donde el mismo registro difiere, gana el del dispositivo.
- **Usar lo de la nube**: el dispositivo queda igual que la nube.
- **Usar lo de este dispositivo**: la nube queda igual que el dispositivo. Los movimientos que sobran en la nube se **anulan**, no se borran (regla #3).

**En un dispositivo nuevo** (sin perfil local) con respaldo en su Drive, la app ofrece restaurarlo antes del registro inicial, si el permiso ya está concedido (en la web se pide junto con el inicio de sesión). Si no, el usuario lo activa en Ajustes y elige cómo combinar.

**Después**, con el respaldo activo, se sincroniza solo al abrir la app, al volver a ella, al salir de ella y con "Sincronizar ahora". La fusión es de tres vías contra la última sincronización (las claves que ambos lados tenían): lo que se borró en un lado se borra en el otro en vez de "revivir". Reglas al fusionar un mismo registro:
- `estado: anulado` gana siempre (movimientos, ingresos extra): una anulación nunca se pierde.
- Un ciclo `cerrado` gana sobre uno abierto (regla #6).
- Fuera de eso, gana el dispositivo que sincroniza (la escritura más reciente que llega).

Claves: categorías, ciclos e ingresos por `id`; movimientos por `clientId` (regla #2); reglas aprendidas por `patron`; ajustes de presupuesto por `cicloId|categoriaId|cuando`; perfil es un solo documento.

Dos dispositivos que sincronizan en el mismo instante pueden pisarse (gana el último en subir); la siguiente sincronización de tres vías lo reconcilia sin perder anulaciones.

**Privacidad.** La copia vive en el Drive del usuario; la app no guarda datos financieros en servidores propios (Firebase solo identifica la cuenta). "Eliminar cuenta" borra también la copia de su Drive; desactivar el respaldo la conserva, y se puede borrar desde la misma pantalla (o desde Google Drive → Configuración → Administrar apps). Las fotos de tickets no se suben.

### 4.2.2 [NUEVO] Versión web (PWA)
El mismo código corre en el navegador y se instala como app ("Agregar a inicio" en iPhone, "Instalar" en Chrome/Android). Diferencias:
- Los datos del dispositivo se guardan en el almacenamiento del navegador (no en archivos). Como el navegador puede borrarlos si no se usa el sitio, la web **recomienda activar el respaldo en Drive** desde el inicio.
- El permiso de Drive se pide en la misma ventana de inicio de sesión; el acceso dura una hora. Después, la web sincroniza con "Sincronizar ahora" (que vuelve a pedir el acceso con una ventana) en vez de hacerlo sola al abrir.
- Sesión con Google por ventana emergente.
- Sin widget, Siri ni fotos de tickets (no hay sistema de archivos); exportar descarga el CSV.

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

**Avisos de gestos (2026-10-31).** La primera vez que se usa un gesto que no se ve a simple vista (deslizar para duplicar o eliminar, deslizar hacia abajo para actualizar), un aviso pequeño explica qué hace. Una sola vez por gesto y por dispositivo (`lib/ui/comun/aviso_gesto.dart`).

### 5.5 [NUEVO] Captura por lote / múltiples renglones
Un ticket de súper puede tener partidas de categorías distintas (despensa + salud + limpieza). La app permite dividir un mismo ticket en varios movimientos que comparten `ticketId`.

### 5.6 [NUEVO] Widget y atajo de voz del sistema
Widget en pantalla de inicio para capturar en 1 tap, y atajo por voz del asistente ("Oye Siri" en iOS, "Ok Google" en Android). La fricción de captura es lo que decide si una app de gastos sobrevive al mes 3.

Es el **único código que se escribe dos veces** (WidgetKit + App Intents en iOS, Glance + App Actions en Android). Por eso se mantienen deliberadamente simples: muestran un solo dato y abren un solo flujo.

**El dato: cuánto queda hoy.** Lo que queda del presupuesto de las categorías **variables** del ciclo, repartido parejo entre los días que faltan contando hoy:

`quedaHoy = max(0, presupuestoVariables − gastadoVariables) ÷ (díasParaTerminar + 1)`

redondeado hacia abajo al centavo, para no prometer más de lo que hay. Las fijas no entran: ya tienen su monto apartado y no se "gastan por día". `presupuestoVariables` es el mismo que muestra Inicio en "Gastos Variables" (con los ajustes del ciclo aplicados). Las listas de variables y fijas de Inicio se ordenan de mayor a menor, a elección del usuario, por presupuesto consumido (por omisión) o por dinero gastado; la elección es del dispositivo y aplica a las dos listas (2026-10-31, `domain/rollups/orden_categorias.dart`). Al registrar un gasto, las categorías van de la más usada a la menos usada (gastos activos de todo el historial); sin historial o en empate, de mayor a menor presupuesto. Lo calcula `domain/presupuesto/disponible_por_dia.dart`; la app lo publica al widget cada vez que Inicio se recalcula, y el widget nunca calcula nada por su cuenta.

**Los flujos.** El widget abre la captura (botón "Gasto") o la captura con el dictado ya escuchando (botón "Dictar"). El atajo de voz registra el gasto sin abrir la app (§5.6.3); "Abre el dictado en MAVfin" y el control del Centro de Control abren el dictado. Antes, Siri no permitía montos ni texto libre dentro de la frase que lo activa, así que es en dos pasos: "Oye Siri, registra un gasto en App Finanzas" → la app abre escuchando → "40 de cine en salidas con tarjeta" → el mismo `parsearDictado` de siempre llena la captura y el usuario confirma con "Listo".

**iOS.** El widget lee el dato de un App Group (`group.com.manuelelizalde.appfinanzas`). Si el App Group no está disponible (por ejemplo, con firma de Apple ID gratuito), el widget muestra solo los botones y la app no falla.

### 5.6.3 [NUEVO] Siri registra el gasto sin abrir la app, con Apple Intelligence (2026-11-15)
Lo que más se repite al día es registrar un gasto, así que con Siri ya no hace falta abrir la app:

1. "Oye Siri, **registra un gasto en MAVfin**" (o "anota un gasto…") → Siri pregunta "¿Qué gastaste?".
2. "230 en el súper con la BBVA ayer" → la app, **en segundo plano**, entiende monto, categoría, cuenta y fecha.
3. Si falta algo, Siri lo pregunta: sin monto, "¿Cuánto fue?"; sin categoría, "¿En qué categoría?" (contesta con su nombre).
4. Siri confirma: "¿Registro $230 en Súper con BBVA, ayer?" → "Sí" → "Listo. Te quedan $1,170 en Súper." (o "llevas $X" si no tiene presupuesto, §7.3.6, o "te pasaste por $X").

También: "Oye Siri, **¿cuánto llevo gastado en MAVfin?**" → "Llevas $X de $Y este ciclo; te quedan $Z y faltan N días" (el mismo dato de Inicio y del widget).

- **Una sola lógica.** Siri arranca la parte Dart de la app sin pantalla (`lib/siri.dart`, punto de entrada `siriMain`) y usa exactamente lo mismo que la captura: `crearMovimiento` (el ciclo se asigna al crear, regla #5), `clientId` nuevo (regla #2), la cuenta y lo aprendido de la cascada (§6.2). El lado nativo (`ios/Runner/AtajosSiri.swift`) solo hace la conversación; nunca calcula ni escribe datos.
- **Pide el iPhone desbloqueado** (`authenticationPolicy = .requiresAuthentication`): con la pantalla bloqueada Siri pide desbloquearlo. El candado de la app (§7.3) protege lo que se ve en ella; registrar con Siri no muestra nada más que lo que se acaba de decir.
- **Sesión:** la app guarda en el dispositivo qué cuenta tiene la sesión abierta; sin sesión, Siri dice "Abre MAVfin e inicia sesión primero". Un ciclo cerrado (regla #6) no se reabre desde Siri: lo dice y no guarda.
- **El intérprete** (`domain/voz/interpretar_gasto.dart`, `interpretarFraseGasto`) es el mismo para Siri y para el dictado dentro de la app (§5.3): extiende `parsearDictado` con **fecha** ("hoy", "ayer", "antier", "el lunes", "el 12", "el 12 de noviembre"; nunca a futuro ni más de 62 días atrás), **cuenta** (su nombre, "en efectivo", "con tarjeta") y montos escritos con cifras ("$1,250.50"). La categoría sale de su nombre en la frase y, si no, de la cascada (reglas e historial de comercios, §6.1).
- **Apple Intelligence** (y cualquier complemento de §6.5) **solo propone la categoría**, y solo cuando las reglas no la resolvieron; la app la acepta si es una categoría activa (`completarConIA`). Monto, fecha, cuenta y descripción son siempre de las reglas: medido con Apple Intelligence real (`tool/ia_gasto/`, 2026-11-15), el modelo inventaba cuenta y fecha cuando no se dijeron, elegía mal entre dos montos ("doce tacos de treinta" → $30) y adornaba la descripción; para la categoría acertó 21 de 24 en ≈0.4 s. Con Apple se usa **generación guiada** con las categorías como única opción (más "Ninguna"), así que no puede responder un nombre que no exista. Se usa el complemento activo; si no hay ninguno y el iPhone tiene Apple Intelligence, se usa ese, porque corre dentro del teléfono: la frase no sale de él. Sin IA, o si falla, Siri pregunta la categoría. Dos números sin saber cuál es el total ("doce tacos de treinta") se preguntan: "Dímelo otra vez con el total".
- Lo dicho se registra con `origenCaptura: voz`.

### 5.6.1 [NUEVO] Meta del ciclo en curso: estimado, no lo que aún no se gasta
La tarjeta "Meta de este ciclo" de Inicio y la recomendación de la meta en Análisis miden el ciclo **en curso** con un estimado, no con `ingreso − gastado` (que el día 1 marcaba 1000 % porque todo lo no gastado aún contaba como apartado):

`apartadoEstimado = ingreso − fijas − variablesEstimadas`

- `fijas` = lo mayor entre su presupuesto y lo ya pagado (las fijas no se pronostican, regla #9: se asumen completas).
- `variablesEstimadas` = lo mayor entre el presupuesto de variables y la proyección lineal de lo gastado (`gastado + gastado × díasRestantes ÷ díasTranscurridos`). Así no se promete lo que todavía no pasa: gastar menos que lo planeado se ve al cierre (y en "Te está sobrando" de Análisis), gastar más se ve de inmediato.

Siempre con su frase (regla #23): "Si sigues así, apartas $X de $Y". El cierre del ciclo sigue usando lo real (`calcularMetricasApartado`).

### 5.6.2 [NUEVO] Gastos de ciclos anteriores (2026-11-14)

La pestaña Gastos abre en el ciclo en curso y, arriba, deja cambiar de ciclo: flechas ‹ › al anterior y al siguiente, y tocar el nombre abre la lista de todos ("¿Qué ciclo quieres ver?") con fechas, estado (En curso / Cerrado / Sin cerrar) y total. Aparecen el ciclo en curso y todos los que tienen al menos un gasto (`domain/ciclo_de_vida/ciclos_para_consultar.dart`). Búsqueda y filtros aplican al ciclo elegido. Un ciclo **cerrado** se consulta pero no se cambia (regla #6): lleva un candado y el aviso "Ciclo cerrado: solo para consultar"; al tocar o deslizar un gasto sale el mismo diálogo de siempre que ofrece reabrir el ciclo (`asegurarCicloAbierto`). Duplicar un gasto viejo sigue permitido: la copia cae hoy, en el ciclo en curso.

### 5.7 [NUEVO] Pestaña Análisis
Una pestaña propia (barra inferior: Inicio · Gastos · ＋ · Análisis · Ajustes) que convierte lo registrado en respuestas: ¿en qué se va?, ¿voy bien?, ¿qué cambió?, ¿qué hago? Por qué: en las apps mejor calificadas (Copilot, Monarch, YNAB, Spendee) lo que más elogian los usuarios, después de la captura rápida, son los reportes claros, la comparación contra el mes anterior y los avisos accionables (ver `docs/investigacion-apps-finanzas.md`).

Todo se calcula en `domain/analisis/` (Dart puro, sin red) sobre los movimientos activos; la UI solo dibuja.

**Básico y avanzado (2026-10-31).** Hasta arriba se elige la vista; se recuerda en el dispositivo y arranca en básico. La **básica** es para echar un vistazo: un veredicto en palabras (vas bien / vas un poco rápido / te pasaste, `domain/analisis/veredicto_ciclo.dart`), cuánto puede gastar hoy, las 2 recomendaciones más urgentes, las 3 categorías variables con más gasto y un botón al análisis completo. La **avanzada** muestra todos los bloques siguientes.

**Ciclos pasados (2026-11-14).** Arriba de las vistas va el mismo selector de ciclo que en Gastos (§5.6.2; `lib/ui/comun/selector_ciclo.dart`): abre en el ciclo en curso y deja ver cualquier ciclo con gastos tal como quedó. Un ciclo que ya terminó (`ReporteAnalisis.terminado`: hoy es después de su último día) se cuenta en pasado —"Cerraste dentro de lo planeado", "Gastaste", "Al cierre", "Ciclo de N días"—, sin "hoy puedes gastar" ni pronóstico, no se marca "en curso" en Últimos ciclos y se compara completo contra el anterior completo. Si está **cerrado**, usa su fotografía del cierre (§2.2): el presupuesto que cada variable tenía ese día (`domain/analisis/presupuestos_del_cierre.dart`), el ingreso y la meta congelados; así cambiar o archivar una categoría después no reescribe cómo le fue. Solo se consulta: nada en Análisis modifica el ciclo.

**Una sola verdad (2026-11-15, rediseño Etapa 0, `docs/rediseno/plan-rediseno.md`).** El cierre estimado de cada variable y el total salen del MPC (`estadosDeVariables`, `ReporteAnalisis.variables`), no del ritmo lineal; la salida de "te pasaste" es `calcularCoberturas` (addendum-v3 §2.5), igual que en Inicio y el detalle de categoría. "Contra el ciclo pasado" y sus recomendaciones solo aparecen si el ciclo anterior está cerrado y completo (`cicloComparable`: se registraba desde su primera semana).

**Periodo: resumen del año y rango de fechas (2026-11-15).** Cuarta vista de Análisis (Resumen · Detalle · Historial · **Periodo**) para ver más allá de un ciclo. Se elige **Este año** (1 de enero a hoy, por omisión), **Últimos 12 meses**, **Año pasado** o **Elegir fechas** (cualquier rango de días). Sobre los gastos activos con fecha en el rango (`domain/analisis/resumen_periodo.dart`, `calcularResumenPeriodo`): total, cuántos gastos, fijas y variables, **promedio por mes** (total ÷ días del rango × 30.44, redondeado al centavo), **gasto por mes calendario** (barras, solo si el rango abarca 13 meses o menos), **por categoría** (monto y % del total, de mayor a menor), el **mes de más gasto** y el **gasto más grande**. **Contra el mismo periodo del año anterior** solo si hay con qué compararlo honestamente: había gastos registrados desde la primera semana de ese periodo (misma idea que `cicloComparable`); si no, no se muestra. Solo consulta: no cambia nada.

**Lo que se repite (2026-11-15).** En Detalle, después de "Dónde más gastas": gastos que se repiten solos —suscripciones, colegiaturas, el gimnasio— detectados en todo el historial por **descripción y monto** (`domain/analisis/gastos_recurrentes.dart`, `detectarRecurrentes`). Se agrupan por la descripción normalizada (sin acentos, mayúsculas ni signos; sin descripción no entra). Un grupo es recurrente si la mediana de días entre un pago y el siguiente cae en una frecuencia —**semanal** (6–8 días), **quincenal** (13–17), **mensual** (26–35) o **anual** (350–380)—, todos los intervalos quedan a ±30 % de esa mediana, aparece al menos 3 veces (2 si es anual) y al menos 3 de cada 4 montos están a ±25 % de la mediana de montos (así un aumento de precio no lo rompe). Solo se muestran los **vigentes**: el último pago no tiene más de 1.5 intervalos. De cada uno: nombre (la descripción más reciente), categoría, frecuencia, monto (el último pagado), cuándo toca el próximo (último + mediana) y **cuánto suma al año** (monto × 52, 26, 12 o 1). Arriba, la frase "Lo que se repite suma $X al año". Solo informa: no crea gastos ni cambia presupuestos.

**Bloques de la vista avanzada, en este orden:**
1. **Resumen del ciclo:** gastado, "van N de M días", promedio por día de las variables y "si sigues a este ritmo, tus variables cierran en $X" (proyección lineal **solo de variables**, regla #9; siempre con su frase, regla #23).
2. **Recomendaciones** (máximo 5, las más importantes primero), cada una con una salida concreta (regla #22) y en el tono de addendum-v3 §4.4: nunca reprender. **Excesos (2026-11-08):** sin "Nada grave" cuando de verdad se pasó: las dos categorías con más exceso van con su propia tarjeta —el ritmo al cierre si aún faltan días ("A este ritmo cerraría $X arriba") y de dónde sale: "Muévele $X desde Súper (se estima que le sobren $Y)", "Desde Súper puedes cubrir $X; los otros $Y saldrían de lo que apartas" o, sin holgura en ninguna, que sale de lo que apartas—; lo que le sobrará a cada categoría se reparte entre los excesos sin ofrecerlo dos veces. Las demás excedidas se juntan en una tarjeta ("También te pasaste en N categorías más", con montos y una sugerencia de ajustar su presupuesto) para dejar lugar a las otras recomendaciones.
   - *Te pasaste* — variable con gasto > presupuesto. Si otra variable va holgada, se sugiere moverle presupuesto (el rebalanceo de siempre, desde el detalle).
   - *Ya usaste todo* — variable que llegó justo a su presupuesto (o le quedan centavos) con días por delante.
   - *Va rápido* — variable que a su ritmo cerraría arriba de su presupuesto (desde el día 3). Dice cuánto arriba y el máximo por día para llegar justo.
   - *Más que el ciclo pasado* — variable que, a los mismos días transcurridos, lleva ≥ 25 % más que el ciclo anterior (y ≥ $300 de diferencia, con ≥ $200 de base).
   - *Gastos pequeños* — 6 o más gastos de $150 o menos que suman ≥ 10 % de las variables del ciclo.
   - *Tu día de más gasto* — un día de la semana con promedio ≥ 1.8 veces el de los demás, con al menos 14 días de datos.
   - *Te está sobrando* — variable de ≥ $500 que, pasada la mitad del ciclo, lleva menos de la mitad de lo que tocaría a su ritmo.
   - *Tu meta* — apartado estimado (§5.6.1) contra la meta del ciclo: a favor, en juego (con cuánto menos al día llega) o, si los gastos pasarían lo que entra, cuánto faltaría.
   - *Vas abajo del ciclo pasado* — variables totales ≤ 85 % de lo que llevabas el ciclo anterior a los mismos días.
3. **¿En qué se va?** — dona por categoría (fijas y variables) con lista: monto y % del gasto.
   - **Orden y selector compartido (2026-11-03):** "¿Cuánto pesa cada parte?" va antes que "¿En qué se va?", y su selector *Variables / Fijos / Total* también filtra la dona: con Variables o Fijos muestra solo esas categorías, con el total y los porcentajes sobre lo que se ve.
   - **¿Cuánto pesa cada parte?** (2026-11-02) — selector *Variables / Fijos / Total*. Variables y Fijos (2026-11-03): cómo está dividido el presupuesto —cada categoría activa con su monto asignado y su % del total asignado a variables o a fijos, de mayor a menor—; lo gastado ya se ve en "¿En qué se va?" y en Inicio, así que aquí no se repite. **Línea del 80/20 (2026-11-14):** una divisoria discreta va justo debajo de las primeras categorías que juntas llegan al 80 % de lo asignado, con "↑ Estas N suman el X%" (`domain/analisis/corte_pareto.dart`); no aparece si hacen falta todas para llegar. Total (por omisión): una barra sobre lo que entra en el ciclo (ingreso base + extras) con fijos rayados, variables y lo que sobra —o la marca de cuánto falta—, hasta hoy y al cierre si sigue así (fijas completas, variables a su proyección; `domain/analisis/reparto_ingreso.dart`). Antes de esas dos, **"Tu plan"** (2026-11-03): la misma barra con lo asignado hoy —presupuesto de fijas y de variables del ciclo— más el **apartado ideal** (la meta del ciclo, `calcularMetaDelCiclo`) en verde sólido, y lo que queda **sin asignar** en gris; si el plan pasa lo que entra, "Tu plan se pasa por" en coral. Así se compara lo planeado contra lo real con la misma escala. **Colores (2026-11-03):** las tres barras usan los mismos tonos —fijos azul, variables oro, lo libre (apartado o lo que sobra) verde— y cambia solo el trazo, con una etiqueta junto al título: *Ideal* (plan) con contorno y relleno tenue, *Real* (hasta hoy) sólido, *Estimado* (al cierre) con rayas de pronóstico, como la línea punteada del ritmo. Las fijas ya no van rayadas.
4. **Ritmo del ciclo** — gasto acumulado de variables por día contra la línea pareja de su presupuesto. En los días restantes, una línea punteada llega a la misma proyección lineal del resumen (punto 1): verde si cierra dentro del presupuesto, coral si lo rebasa.
5. **Contra el ciclo pasado** — por categoría, lo de este ciclo contra lo del anterior **a los mismos días transcurridos** (addendum-v3 §2.4: comparación honesta, nunca contra el ciclo anterior completo). Al ver un ciclo ya terminado, los dos van completos.
6. **Últimos ciclos** — total gastado de hasta 6 ciclos, el actual marcado como "en curso".
7. **¿Qué día gastas más?** — promedio por día de la semana de las variables (últimos 90 días).
8. **Dónde más gastas** — las 5 descripciones con más gasto (al tocar el bloque, la lista completa, 2026-11-03) en **variables** del ciclo (sin descripción no entra; las fijas ya se conocen). Lo parecido se junta (2026-11-02, `agrupar_descripciones.dart`): sin acentos, signos, plurales ni palabras vacías, "café", "Cafés" y "un café" son el concepto *Café*, y una descripción más larga ("pan y café") va al concepto más frecuente que contenga; si no contiene ninguno escrito solo alguna vez, se queda como está.
9. **Tarjeta y efectivo** — reparto del gasto del ciclo por medio de pago.

Montos siempre en `Dinero`; los porcentajes y promedios se redondean en la frontera, como el MPC.


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

### 6.5 [NUEVO] Complementos de IA: cada quien conecta la suya (2026-11-15)
Reemplaza la idea de una Cloud Function con la llave de la app: **la app no paga ni guarda ninguna IA**. Cada usuario conecta la suya en **Ajustes → Complementos de IA**, como los complementos de una suite de oficina:

| Complemento | Cómo se conecta | Dónde funciona |
|---|---|---|
| **Apple Intelligence** | Sin cuenta ni clave: el modelo de Apple corre en el iPhone (Foundation Models, iOS 26+, con Apple Intelligence activo). Gratis y privado. | Solo app de iPhone |
| **Gemini** | Clave de API de Google AI Studio, en su nivel gratuito (sin tarjeta). En ese nivel Google puede usar lo que se le manda para mejorar sus productos: la app solo le manda la frase o nota del gasto y los nombres de las categorías, nunca saldos ni movimientos. | iPhone, Android y web |
| **Gemini Nano** *(pendiente, solo Android)* | Sin cuenta ni clave: el modelo de Google corre dentro del teléfono con ML Kit (Prompt API, sobre AICore). Gratis, sin internet y privado, como Apple Intelligence. Solo en teléfonos compatibles (Pixel 9 y 10, Galaxy S25 y S26, varios Xiaomi, OnePlus, Honor y vivo) y solo con la app en pantalla. Se agrega cuando se haga la parte de Android (widget, App Actions). | Solo app de Android |

**Sin complementos que cobren aparte (2026-11-15).** ChatGPT y Claude se quitaron: su API se cobra en una cuenta aparte de la suscripción (OpenAI y Anthropic), y la app no debe costarle extra a nadie. Anthropic no permite usar la suscripción de Claude en otras apps (desde 2026-02). "Iniciar sesión con ChatGPT" (programa de OpenAI de 2026-09, que sí usa el plan del usuario sin cobro extra) se puede reconsiderar si OpenAI aprueba la app. Un `ia.json` que todavía los nombre se lee sin ellos.

- **La clave vive solo en el dispositivo** (`ia.json` junto al candado, §7.3): no se respalda en Drive ni sale a ningún servidor de la app. La app llama directo a la IA del usuario. "Eliminar cuenta" la borra.
- **Conectar = probar.** Al pegar la clave, la app pide la lista de modelos del proveedor y elige uno rápido y barato (`domain/ia/proveedor_ia.dart`, `elegirModelo`); si la clave no sirve, lo dice en palabras y no se guarda.
- **Un complemento activo a la vez.** Se puede tener varios conectados y elegir cuál usa la app.
- **Usos:**
  1. **Asistente "Pregúntale a tu IA"** (Ajustes → Ayuda y la guía por temas): conversación que contesta **solo con base en la guía por temas** (`lib/ui/ayuda/instructivo_ia.dart` arma el instructivo con todo `contenido_guia.dart`): dónde está cada botón y cómo se hace cada cosa. No ve los datos del usuario, no da asesoría financiera ni de inversión y, si algo no está en la guía, lo dice.
  2. **Nivel 3 de la cascada** (§6.1, interruptor "Sugerir categorías con IA", apagado por omisión): al escribir la nota de un gasto que reglas e historial no resolvieron, la IA sugiere la categoría con su confianza; se aplican los umbrales de §6.3 y solo **resalta** la categoría ("Sugerida por tu IA"): nunca guarda sola. Se manda solo la nota y los nombres de las categorías.
  3. **Entender lo que se dicta** (§5.6.3): con Siri o con el dictado de la captura, propone la categoría cuando las reglas no la resolvieron (en la captura solo la resalta). Se manda la frase dicha y los nombres de las categorías.
  4. **Preguntar sobre tus números (2026-11-15, opcional y apagado por omisión).** Con el interruptor "Dejar que tu IA vea tus números" (Complementos de IA), el asistente también recibe un **resumen que calcula la app** (`domain/ia/datos_para_ia.dart`, `textoParaIA`): el ciclo y sus días, ingreso, lo gastado en variables contra su presupuesto, cada categoría con lo que le queda, fijos, el ciclo pasado, saldos de cuentas, lo que se debe en tarjetas, patrimonio y objetivos. Así contesta "¿cuánto me queda en súper?" o "¿en qué se me ha ido más?". La IA **no calcula**: lee las cifras que la app ya calculó con `Dinero`; no ve cada gasto ni sus descripciones. Sigue sin dar asesoría financiera ni de inversión. Con Apple Intelligence el resumen no sale del iPhone; con Gemini se manda a Google, y el interruptor lo dice antes de encenderlo (en el nivel gratuito Google puede usarlo para mejorar sus productos). Apagado, el asistente sigue sin ver nada del usuario.
- **Gemini sin sorpresas (2026-11-15).** Lo que el modelo "piensa" cuenta contra el tamaño de la respuesta y dejaba vacías las cortas (la categoría de un gasto): el cliente pide no pensar según el modelo (`ClienteGemini.configuracionDePensar`), y si el modelo lo rechaza o la respuesta sale vacía, reintenta una vez con holgura.
- **Sin IA o sin red, nada cambia** (regla #17): la captura nunca espera a la IA.

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

**Cómo quedó (2026-11-02):**
- **PIN de 6 números obligatorio**, como en el iPhone: se crea al entrar (también cuentas que ya existían) y es el respaldo de todo lo demás. No se aceptan los fáciles de adivinar (111111, 123456, 654321).
- **Método elegible** en Ajustes → Seguridad: Face ID / huella (solo en la app del teléfono, `local_auth`; en la web no hay), PIN o contraseña (6+ caracteres con letras y números).
- **El PIN se pide al menos una vez por semana** aunque el método sea otro, para no olvidarlo.
- Se pide al abrir y al volver a la app tras **2 minutos de inactividad** (2026-11-03), contados desde el último toque, no desde que salió: así una salida breve —o un aviso del sistema que el navegador reporta como "oculta" al registrar un gasto— no lo vuelve a pedir. El último toque se guarda en el dispositivo (cada 15 s y al salir), así que si el sistema cierra o recarga la app —Safari en el iPhone lo hace al quedarse sin memoria— y se abre dentro de esos 2 minutos, tampoco se pide. El desbloqueo se pone encima de lo que estaba abierto, sin perderlo. Se pide **una sola vez** por apertura: redibujar la app (cambio de tema, claro/oscuro del sistema) nunca la vuelve a montar bloqueada (2026-11-06).
- **Intentos:** del 5.º fallo en adelante, esperas de 30 s, 1, 5, 15 y 60 min; al 10.º solo se entra recuperando.
- **Recuperación:** "¿Olvidaste tu PIN?" vuelve a confirmar la **misma cuenta de Google** con la que se entró (Firebase rechaza otra, `user-mismatch`) y deja crear un PIN nuevo; los datos no se tocan. **Exige escribir la contraseña de Google en ese momento** (2026-11-02): se le pide a Google volver a autenticar (`max_age=0`) y se comprueba el claim `auth_time` del ID token (requiere "Session age claims" activado en Google Auth Platform → Configuración avanzada); si la contraseña no se escribió en los últimos 5 minutos —Google reusó la sesión abierta del teléfono—, se rechaza y se le explica que cierre sesión de Google en ese dispositivo y lo intente de nuevo. Sin esto, quien tomara el teléfono desbloqueado podía cambiar el PIN con un toque. (`data/seguridad/autenticacion_reciente.dart`, `ServicioAuth.reautenticarConContrasena`.) **Temporal:** Google solo manda `auth_time` a apps con la marca verificada (en trámite desde el 2026-11-02); mientras no llegue, la recuperación acepta con solo confirmar la cuenta, como antes. Al verificarse, activar la casilla en Google Auth Platform → Configuración y quitar la excepción.
- **Privacidad:** PIN y contraseña nunca se guardan: solo su huella PBKDF2-SHA256 con sal aleatoria, en la carpeta de la cuenta en el dispositivo (`candado.json`, `lib/data/seguridad/candado.dart`). No viaja en el respaldo; "Eliminar cuenta" la borra. Las reglas viven en `domain/seguridad/politica_bloqueo.dart`.

### 7.3.1 [NUEVO] Cuentas y tarjetas (2026-11-02)
Aprobado de `docs/propuesta-cuentas.md` (fase A). Cada gasto dice de qué **cuenta** salió: efectivo, débito o crédito. Varias tarjetas de cada tipo.

- **Modelo.** `Cuenta { id, nombre, emoji, tipo: efectivo|debito|credito, llevaSaldo, saldoInicial, fechaSaldoInicial, activa, limite?, diaCorte?, diaPago? }` en `cuentas.json`, respaldada en Drive. Las cuentas con historial se archivan, no se borran (ver "Eliminar una cuenta"). `Movimiento.cuentaId` (opcional); `medio` sigue existiendo y se deriva del tipo (débito/crédito = tarjeta). Los gastos de antes, sin `cuentaId`, caen en las cuentas base **Tarjeta** (crédito) y **Efectivo**, que se crean solas: no se reescribe ningún dato.
- **Eliminar una cuenta (2026-11-15).** Desde su detalle, "Eliminar cuenta", con confirmación (`domain/cuentas/eliminar_cuenta.dart`, `comoQuitarCuenta`). Si **nunca se usó** (ningún gasto ni abono, ajuste o transferencia, ni anulado), se borra por completo y la fusión con Drive no la revive. Si **tiene movimientos**, no se borra (regla #3): se archiva —deja de verse y de contar en el patrimonio, su historial se conserva y se puede reactivar desde "Ver archivadas"—. Una cuenta con **apartados activos** pide eliminarlos primero (su dinero regresa a ella, §7.3.5). Efectivo no se elimina; Tarjeta, como cuenta base que se vuelve a crear sola, solo se archiva. Un objetivo que se juntaba ahí se queda en $0 hasta que se le elija otra cuenta.
- **Saldo: se calcula, nunca se guarda.** `saldoInicial + abonos ± ajustes − gastos activos` desde `fechaSaldoInicial`. Débito siempre lleva saldo; el efectivo y el crédito, solo si el usuario lo activa ("traigo $800", "debo $3,000"). Saldo negativo se permite y se avisa en coral; nunca bloquea la captura (regla #17).
- **Abonos y ajustes.** `MovimientoCuenta { clientId, cuentaId, fecha, monto > 0, tipo: abono|ajuste, sentido (ajuste: + o −), nota, estado, ingresoExtraId }` en `movimientos_cuenta.json`. No son gastos: no tocan categorías ni presupuesto. Se anulan, no se borran (regla #3). "Ajustar saldo" registra la diferencia como ajuste, no reescribe el saldo inicial. Un abono puede marcar **"También es ingreso de este ciclo"** (apagado por omisión): crea el `IngresoExtra` ligado y anular el abono lo anula también.
- **Captura.** Fila de cuentas, la más usada primero; por omisión, la última usada.
- **Dónde se ve.** Ajustes → Tus cuentas (alta, edición, saldo, abonos, ajuste). Inicio: tarjeta "Tus cuentas" con los saldos. Análisis: tercera vista **Cuentas** (aparte de Básico y Avanzado): por cuenta, gastado en el ciclo, % del total, número de gastos, sus categorías principales y el saldo.
- **CSV.** Columna **Cuenta** (nombre). Si no existe al importar, se crea (débito si el medio dice débito, efectivo si dice efectivo, si no crédito) con aviso. Importar no elimina cuentas.
- **Transferencias (2026-11-03).** Mover dinero entre cuentas: retirar efectivo del débito, pasar entre débitos o **pagar la tarjeta de crédito** desde el débito. Es un `MovimientoCuenta` de tipo `transferencia` con `cuentaDestinoId`: resta en el origen y suma en el destino; **no es gasto** (contarlo como gasto duplicaría lo que ya se registró con la tarjeta de crédito). Se anula como los abonos. Se hace desde Tus cuentas ("Transferir") o desde el detalle de una cuenta (en una de crédito, "Pagar esta tarjeta").
- **Suma de tus cuentas.** Tus cuentas muestra arriba el total de las que llevan saldo (débito y efectivo con saldo); las de crédito no entran y lo que se debe en ellas se muestra debajo.
- **Deuda de la tarjeta de crédito (2026-11-06).** Opcional, como el saldo del efectivo: al activarlo se pide cuánto se debe hoy y, si se quiere, el límite. Es el mismo saldo calculado con el signo al revés (`saldoInicial` = −lo que se debía): cada gasto con la tarjeta sube lo que se debe; los pagos (transferencias desde otra cuenta), los abonos (un pago desde fuera o una devolución) y los ajustes lo corrigen. Con límite, el ajuste se puede hacer escribiendo **lo que se debe o el crédito disponible** —el que muestre el banco—; lo que se debe sale de límite − disponible (`deudaDesdeDisponible`, 2026-11-07). Se lee como **Debes $X** —o **A tu favor**, si se pagó de más— y, con límite, **Disponible**; pasado del límite va en coral (`deudaDe`, `lecturaDeSaldo`). Lo que se debe no entra al total de tus cuentas: va aparte, "Debes en tarjetas" (`sumaDeDeudas`). Lo que tienes va en verde salvia y lo que debes en rojo ladrillo (`aFavor`/`enContra` de la paleta, más apagados que `verdeTexto`/`coralTexto` porque se ven todo el tiempo; AA en los dos modos).
- **Corte y fecha de pago (2026-11-15).** Opcionales en las de crédito: **día de corte** y **día límite de pago** (1–31; en meses más cortos, el último día). Con los dos, la app calcula el **último corte** (el día de corte más reciente, hoy incluido), la **fecha de pago** que le toca (la primera con el día de pago después de ese corte) y el **próximo corte** (`domain/cuentas/fechas_tarjeta.dart`, `pagoDeTarjeta`). **Cuánto pagar para no generar intereses:** si la tarjeta lleva lo que se debe, es lo que se debe hoy menos lo gastado con ella después del corte (nunca menos de cero): los pagos posteriores al corte ya lo bajaron. Si no lleva saldo, la app no sabe de pagos: muestra lo gastado en el periodo (del corte anterior al último) como referencia y, pasada la fecha de pago, deja de avisar. **Estados:** sin pendiente (no hay nada que pagar), por pagar (con días que faltan) y vencido (solo con saldo: pasó la fecha y aún se debe algo del corte). **Aviso en Inicio:** el pago más próximo que esté por pagar en los siguientes 7 días o vencido ("Paga $X de {tarjeta} antes del {fecha}", "Hoy vence…", "Se pasó la fecha…"), con salida a la tarjeta, donde está "Pagar esta tarjeta". Tiene prioridad sobre el banner de cobertura (sigue siendo uno solo). En Tus cuentas y en el detalle de la tarjeta se lee la fecha de pago.
- **Compras a meses sin intereses (2026-11-16).** Al registrar un gasto con una tarjeta de crédito aparece el chip **Meses**: sin meses (por omisión), 3, 6, 9, 12, 18 o 24. Una compra a N meses se guarda como **N gastos, uno por mensualidad** (`domain/cuentas/compra_a_meses.dart`, `crearCompraAMeses`), ligados por `compraId` y con `mensualidad` (1…N) y `meses` (N):
  - **Montos:** el total entre N, al centavo hacia abajo; los centavos que sobran van en la primera. La suma siempre es el total exacto.
  - **Fechas:** la primera, el día de la compra; cada una de las siguientes, un mes después (mismo día y hora; en meses más cortos, el último día). Cada mensualidad toma el ciclo de su propia fecha (regla #5), así **el presupuesto de cada ciclo carga solo su mensualidad**, no el total de jalón.
  - **Tarjeta:** lo que se debe sube por el total desde el día de la compra (así lo aparta el banco del límite), pero **el pago para no generar intereses** de cada corte incluye solo la mensualidad que cae en ese periodo, porque lo gastado después del corte —las mensualidades futuras incluidas— no entra (`pagoDeTarjeta`). El detalle de la tarjeta dice cuánto de la deuda es "a meses, por venir" (`porPagarAMeses`) y lista las compras a meses con cuántas mensualidades faltan.
  - **Mensualidades futuras** no son un ciclo anterior ni se eligen en Gastos: el historial y el selector de ciclos ignoran los ciclos posteriores al de hoy; aparecen solas cuando llega su ciclo. Lo que se repite (§5.7) no las cuenta como gasto recurrente.
  - **Editar:** en una mensualidad se cambian la categoría y la nota, y se aplica a toda la compra; monto, fecha, cuenta y meses no se editan (se elimina y se registra de nuevo). **Eliminar** (deslizar o Deshacer) anula todas las mensualidades de la compra, y Deshacer las regresa. No se duplica.
  - **CSV (§7.4):** la columna opcional **Meses** ("2 de 12") va al final; con ella y el ID (`{compraId}-m{n}`) la importación reconstruye la compra.
- **Segunda etapa:** cuenta por voz, notificaciones del recordatorio de pago (requieren app nativa). El aviso de saldo bajo se descartó (2026-11-15).

### 7.3.2 [NUEVO] Ahorro, inversiones y patrimonio (2026-11-14)

Por qué: la app ya decía cuánto se aparta cada ciclo, pero ese dinero no vivía en ningún lado; el patrimonio en un solo número es de lo más elogiado en las apps mejor valoradas (`docs/investigacion-apps-finanzas.md`).

- **Cuarto tipo de cuenta: `ahorro`** (ahorro o inversión: fondo, CETES, afore…). Siempre lleva saldo (`TipoCuenta.siempreLlevaSaldo`). **No se paga con ella:** no aparece al registrar un gasto ni en el análisis por cuenta. Se le **transfiere** desde otra cuenta ("Aportar a tu ahorro"; no cuenta como gasto) y su valor se corrige con **"Actualizar valor"**, que es el ajuste de siempre: en su historial se lee "Rendimiento" o "Baja de valor".
- **Patrimonio** (`calcularPatrimonio`, `domain/cuentas/saldos.dart`) = para gastar (efectivo y débito, `sumaDeSaldos`) + ahorro e inversiones (`sumaDeAhorros`) − lo que se debe en tarjetas (`sumaDeDeudas`). Solo cuentas activas que llevan saldo. Encabeza "Tus cuentas" con su desglose y cierra la tarjeta de cuentas de Inicio (si hay más de una con saldo).
- **Conexión con el cierre del ciclo:** un ciclo cerrado con apartado positivo pregunta "¿Ya está en tu ahorro?" y ofrece "Pasarlo a mi ahorro": abre la transferencia hacia la cuenta de ahorro con el monto ya escrito; si aún no hay ninguna, primero la crea. Es una oferta, nunca automático.
- No es asesoría: la app no recomienda instrumentos ni estima rendimientos; solo lleva lo que el usuario le dice que tiene.

### 7.3.3 [NUEVO] Objetivos de ahorro y patrimonio por ciclo (2026-11-14)

Por qué: las metas con nombre son de lo más elogiado y pedido en las apps de finanzas (`docs/investigacion-apps-finanzas.md`); la "meta de apartado" (§5.6) dice cuánto apartar cada ciclo, pero no para qué ni cuánto falta.

- **Objetivo** (`domain/modelos/objetivo.dart`, en `objetivos.json`, se respalda en Drive por `id`): nombre, emoji, monto, fecha límite opcional y la **cuenta de ahorro** donde se junta. Se archiva o, si el usuario lo pide y confirma, se elimina (2026-11-15): un objetivo no tiene historial propio —su avance es el saldo de la cuenta—, así que eliminarlo no toca dinero ni movimientos, y la fusión de tres vías contra Drive (§4.2.1) no lo revive.
- **El avance no se guarda: es el saldo de su cuenta de ahorro** (`calcularProgresoObjetivos`, `domain/objetivos/progreso_objetivos.dart`). Si varios objetivos comparten cuenta, el saldo los llena en orden de creación: el primero se completa antes de que el segundo reciba algo. Para sumarle se aporta a la cuenta (§7.3.2); no hay "abonos al objetivo" aparte que puedan descuadrarse.
- **Con fecha (reparto por días, 2026-11-15):** lo que falta se reparte entre los ciclos que tocan la fecha (con `perfil.calculadoraCiclo`) **en proporción a los días** de cada uno que caen entre hoy y la fecha, los dos incluidos — un ciclo del que solo quedan 4 días antes de la fecha pide poco, no lo mismo que uno completo. Cada parte va a pesos enteros (hacia abajo) y el resto se suma a la de este ciclo, así que suman exacto. El cálculo por día es interno: la frase habla en ciclos ("Para el 16 dic: aparta $16,875 en este ciclo y $3,125 en el siguiente"; con más de dos, "… y unos $X por ciclo después"). Llega a tiempo si lo que se aparta de siempre (`calcularMetaBase`, sin extras), repartido por los días de su ciclo, cubre lo que pide cada día: apartado × días hasta la fecha ≥ falta × días del ciclo más largo del reparto. Si no, "llegarías en N ciclos". Fecha vencida sin juntarlo: se dice, y se pide una fecha nueva. **Sin fecha:** cuánto falta y en cuántos ciclos se llegaría a ese ritmo. Siempre con su frase (regla #23).
- **Dónde:** renglón "Objetivos de ahorro" en Inicio (con el primero que aún no se logra) y en Ajustes → Tu plan. `lib/ui/objetivos/`.
- **Patrimonio por ciclo** (`patrimonioPorCiclo`, `domain/cuentas/saldos.dart`): el patrimonio al cierre de cada ciclo y a hoy en el que corre, hasta 6, en "Tus cuentas", con "Creció/Bajó $X desde el cierre de …". Sale de los mismos movimientos (`saldoDe(…, hasta:)`), no de una foto guardada; cada cuenta entra desde su `fechaSaldoInicial`, así que dar de alta una cuenta se ve como un salto (se avisa al pie).

### 7.3.4 [NUEVO] Categorías de ingreso e ingresos por categoría (2026-11-15)
Las categorías de siempre son de **gasto**. Aparte existe un catálogo de **categorías de ingreso** (Nómina, Rentas, Inversiones…) para decir de dónde viene el dinero que entra a las cuentas.

- **Modelo.** `CategoriaIngreso { id, nombre, emoji, activa }` en `categorias_ingreso.json` (se respalda en Drive, clave `id`). Sin presupuesto ni tipo: solo nombran el origen. Se archivan, no se borran. La primera vez se crean las sugeridas (Nómina, Rentas, Inversiones, Ventas, Regalos, Otros ingresos); el usuario las renombra, archiva o agrega.
- **Dónde se administran.** En la misma pantalla de Categorías (Ajustes → Tu plan → Categorías y presupuestos), con un selector **Gastos | Ingresos** arriba; el ＋ crea del tipo que se está viendo.
- **Abonos.** `MovimientoCuenta.categoriaIngresoId` (opcional, solo abonos). Al registrar un abono se elige la categoría entre las **de ingreso** activas (se puede crear una ahí mismo) y se escribe la nota, como en un gasto. En una tarjeta de crédito no se pide: un abono ahí baja la deuda, no es dinero que entra. Al registrar un **gasto** solo se ofrecen categorías de gasto. Los abonos de antes quedan "Sin categoría".
- **Análisis → Ingresos** (quinta vista, `domain/analisis/reporte_ingresos.dart`, `calcularReporteIngresos`). Ingreso = abono activo a una cuenta que no sea de crédito, con fecha en el rango (transferencias y ajustes no cuentan: no es dinero nuevo). Rango: **Este ciclo** (por omisión), Este año, Últimos 12 meses o Elegir fechas. Muestra: total, cuántos abonos y promedio por mes; **contra lo gastado** en las mismas fechas (cuánto quedó y qué parte de lo que entró se gastó); **por categoría** (monto y %; si una sola pasa de 80 %, lo dice: se depende de una fuente); **mes por mes** (≤ 13 meses); **a qué cuenta entró**; y el ingreso más grande. Solo consulta.
- **Filtro por cuenta (2026-11-15):** chips con las cuentas que no son de crédito; se puede elegir una, varias o todas (por omisión). Con filtro, todo el reporte —incluido "contra lo gastado", que entonces solo cuenta lo gastado con esas cuentas— se limita a ellas.
- No reemplaza al ingreso base ni a los ingresos extra del ciclo (§5.6.1), que siguen siendo los del presupuesto; un abono puede seguir marcándose "También es ingreso de este ciclo".

### 7.3.5 [NUEVO] Apartados dentro de una cuenta (2026-11-15)

Por qué: muchos bancos (y Cetes) dejan separar el dinero en "apartados" o "cajitas" dentro de la misma cuenta; el usuario quiere juntar ahí sus objetivos sin abrir otra cuenta.

- Un **apartado** es una cuenta de ahorro (`TipoCuenta.ahorro`) con `Cuenta.cuentaPadreId`: la cuenta de débito o de ahorro donde vive. No hay apartados de apartados, ni de efectivo o crédito. Siempre lleva saldo y no se paga con él (como toda cuenta de ahorro).
- **El dinero se mueve con transferencias** entre la cuenta y su apartado ("Guardar" y "Sacar"), igual que en el banco: lo que se guarda deja de estar disponible en la cuenta. Al crear el apartado se puede pasar de una vez lo que ya tiene. El saldo se calcula siempre (§7.3.1), nunca se guarda.
- **Patrimonio:** el apartado cuenta como ahorro (`sumaDeAhorros`), y su cuenta solo con lo que queda disponible: el total no cambia al guardar o sacar.
- **Pantallas:** el detalle de una cuenta de débito o de ahorro lista sus apartados, con "Nuevo apartado", y dice cuánto hay en total sumando lo apartado. En Tus cuentas los apartados van en "Ahorro", cada uno con la cuenta donde vive. El detalle de un apartado ofrece "Guardar" (desde su cuenta) y "Sacar" (a su cuenta) y "Actualizar valor" (rendimientos).
- **Objetivos (§7.3.3):** un objetivo se puede juntar en un apartado; se muestra como "Viaje · BBVA débito".
- **Eliminar un apartado (2026-11-15):** con confirmación, desde su detalle. Lo que tenga **regresa a su cuenta** con una transferencia ("De Viaje"), así el dinero se libera sin desaparecer; después el apartado se archiva y deja de verse (ni en sus apartados ni en las archivadas de Tus cuentas). No se borra el registro: los movimientos de la cuenta siguen diciendo de dónde vino el dinero (regla #3). Un objetivo que se juntaba ahí se queda en $0 hasta que se le elija otra cuenta.

### 7.3.6 [NUEVO] Categorías sin presupuesto: solo registrar (2026-11-15)

Por qué: hay quien no quiere presupuestar por categoría; solo quiere ver en qué se le va el dinero y cuánto le entra.

- Una categoría variable con presupuesto **$0 = sin presupuesto**: se registra y se analiza igual, pero **no se juzga** — sin barra de ritmo, sin "Vas bien/rápido", sin "Te pasaste", sin coberturas ni rebalanceo (no tiene exceso ni sobrante) y sin "Gasta hasta $X al día". Su renglón dice "Llevas $X · sin presupuesto". Las fijas siguen pidiendo su monto.
- Crear, editar e importar aceptan $0 (no negativos). En el onboarding, el paso de categorías tiene **"Solo quiero registrar mis gastos"**: deja todas en $0 y esconde los montos.
- **Totales:** "Llevas gastado $X de $Y" y el veredicto del ciclo solo comparan las categorías **con** presupuesto; lo de las demás se dice aparte ("Además, $Z en categorías sin presupuesto").
- **Modo solo registro** (ninguna variable con presupuesto): el héroe de Inicio dice "Llevas gastado $X este ciclo" —**todo** lo gastado del ciclo, fijas incluidas (2026-11-16: sin presupuestos no hay contra qué separar variables de fijas)— con lo que entró y cuánto queda de lo que entró, sin barra ni chip; el widget del iPhone y Siri, "Llevas gastado $X" con la misma cifra. Análisis cuenta lo gastado y lo que entró sin pedir presupuestos. La meta derivada de apartado sigue siendo ingreso − fijas − lo proyectado (§5.6.1).

### 7.4 [NUEVO] Exportación y portabilidad
Exportar todo a Excel/CSV cuando quieras. No quedas atrapado en la app — y te da una red de seguridad psicológica al abandonar el Excel.

**Formato de ida y vuelta (2026-10-29).** Lo que se exporta se puede reimportar sin perder nada del movimiento, y la plantilla de importación usa las mismas columnas:

| Columna | Al exportar | Al importar |
|---|---|---|
| Fecha | `aaaa-mm-dd`, con `HH:mm` si tiene hora | Obligatoria. También `dd/mm/aaaa` (y con hora, como la reescribe Excel) |
| Monto | `450.00`, sin símbolo | Obligatorio, mayor a 0. Tolera `$`, comas de miles y `MXN` |
| Categoría | Nombre | Se busca por nombre sin acentos/mayúsculas; si no existe se crea variable con presupuesto $0. Acepta el emoji pegado al inicio ("🛒 Súper"). **Vacía:** se adivina por la descripción con la cascada §6.1 (reglas del usuario → historial de comercios de la cuenta → lo que enseñan los renglones del mismo archivo que sí traen categoría); si nada resuelve, va a "Sin categoría" y la vista previa dice cuántos son, para moverlos después desde Gastos. Nunca se inventa una categoría en la que no se confía (§0.4) |
| Emoji | El de la categoría | Para la categoría nueva; vacío → sugerido por el nombre. Una categoría existente con el 📥 genérico de antes lo recibe |
| Presupuesto | Presupuesto mensual (variable) o monto fijo (fija) | Vacío → conserva el de la categoría existente; nueva: $0. `0` en una variable = solo registrar, sin presupuesto (§7.3.6). Inválido → se ignora con aviso |
| Tipo | `Fija` / `Variable` | Vacío → conserva el existente; nueva: Variable. Una fija sin monto mayor a 0 queda variable, con aviso. Nunca se infiere del nombre (regla #8) |
| Día de cobro | Solo fijas | 1–31. Vacío → conserva el existente; nueva: 1, con aviso |
| Necesaria / Activa | `Sí` / `No` | Vacío → conserva; nueva: No / Sí |
| Descripción | Texto | Vacía → nombre de la categoría |
| Medio de pago | `Tarjeta` / `Efectivo` | Vacío → Tarjeta. Otro texto → Tarjeta con aviso |
| Cuenta | Nombre de la cuenta con que se pagó (§7.3.1) | Se busca por nombre; si no existe se crea (efectivo si el medio lo dice, débito si el nombre o el medio dicen "débito"/"TDD", si no crédito) sin saldo, con aviso. La cuenta manda sobre el medio. Las cuentas nunca se eliminan al importar |
| Estado | `Activo` / `Anulado` / `Pendiente` | Vacío → Activo. Otro texto → Activo con aviso (nunca tumba el renglón). Lo anulado se guarda anulado, sin contar en totales |
| Cómo se registró | `Manual`, `Voz`, `Ticket`, `Recurrente`, `Importado` | Se conserva si se reconoce; si no, Importado |
| ID | `clientId` | Si viene, es el `clientId`: reimportar en la misma cuenta no duplica (regla #2). Vacío → huella estable del archivo + renglón |

Se exporta todo, también lo anulado: si no, reimportar revivía gastos que el usuario había quitado. El plan de cada categoría se repite en todos sus renglones; si dos renglones lo contradicen gana el primero, con aviso. Una categoría sin gastos sale en un renglón con Fecha y Monto vacíos.

**Importar reemplaza (2026-10-31, excepción a la regla #3 pedida por el usuario).** Al terminar, los gastos y categorías de la cuenta son exactamente los del archivo: lo que no viene se elimina físicamente, incluido lo que estaba anulado. La vista previa dice cuánto se elimina y hay que confirmarlo. Un gasto con el mismo ID conserva su `cicloId` (regla #5), foto y ticket; una categoría con el mismo nombre conserva su id. Con el respaldo activo, la copia de Drive se sobrescribe con el dispositivo en vez de fusionarse, porque la fusión revive lo eliminado; si no hay red, queda pendiente para la siguiente sincronización. No se tocan perfil, ingresos extra ni ciclos cerrados: sus fotos guardadas (`snapshot`) conservan los totales con que se cerraron.

**Ingresos y movimientos de cuentas (2026-11-16).** Ajustes → Tus datos → "Exportar ingresos y cuentas" da un segundo CSV (`exportarMovimientosCuentaCsv`): Fecha, Tipo (`Ingreso` / `Ajuste de saldo` / `Transferencia`), Monto (con signo solo en un ajuste que baja el saldo), Cuenta, Hacia la cuenta (transferencias), Categoría de ingreso (§7.3.4), Nota, Estado e ID; todo, también lo anulado. Va aparte porque sus columnas no son las de un gasto. Por ahora es solo de salida: la importación de CSV sigue siendo de gastos y categorías, y la plantilla le pide a la IA no incluir ingresos ni pagos de tarjeta.

Para mover la cuenta completa sigue estando el respaldo en Drive (§4.2.1). Excel en algunos idiomas guarda con `;`: la importación lo detecta.

**Instrucciones para la IA (2026-10-30).** La plantilla empieza con renglones `#` que le dicen a la IA del usuario cómo llenarla: archivo `.csv` UTF-8 con comas, encabezados intactos, formato de fecha y monto, valores permitidos (Tarjeta/Efectivo, Activo/Anulado, Fija/Variable), presupuesto por categoría y un emoji según su nombre. La importación ignora todo renglón cuya primera celda empiece con `#`.

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
