# Paquete de construcción — App de finanzas personales
### iOS + Android · versión final de diseño

Este documento es el que se le entrega a quien vaya a construir la app. Consolida todas las decisiones tomadas y agrega lo necesario para que corra en las dos tiendas.

---

## 0. Inventario de entregables

| Archivo | Contenido |
|---|---|
| **paquete-construccion-final.md** | Este documento. Punto de entrada. |
| **spec-app-finanzas-v2.md** | Integridad de datos, rendimiento, seguridad, migración |
| **modelo-pronostico-ciclo.md** | Motor de pronóstico (MPC) con todas sus fórmulas |
| **addendum-v3-ajuste-y-ux.md** | Plan de ajuste, principios de simplicidad y motivación |
| **como-funciona-la-ia.md** | Cascada de clasificación y uso de IA |
| **app-finanzas-onboarding-INTERACTIVO.html** | Prototipo navegable con lógica real y panel de pruebas |
| **app-finanzas-mockup-v2.html** | Inicio, plan de ajuste, captura, progreso, notificaciones |
| **app-finanzas-gastos-v3.html** | Lista de gastos, búsqueda, filtros, detalle de categoría |
| **app-finanzas-voz-v4.html** | Dictado por voz con varios gastos en un dictado |
| **app-finanzas-onboarding-v5.html** | Onboarding, versión estática |
| **app-finanzas-fijos-cierre-v6.html** | Fijos vs variables, cierre de ciclo, trazabilidad |
| **app-finanzas-ticket-v7.html** | Foto de ticket, división por categorías, fallas |
| **app-finanzas-rebalanceo-v8.html** | Rebalanceo entre categorías |
| **app-finanzas-estados-v9.html** | Estados vacíos y de error |
| **app-finanzas-eliminar-reembolsos-v10.html** | Deslizar, eliminar, editar, reembolsables |
| **app-finanzas-ingresos-ajustes-v11.html** | Ingresos extra y pantalla de ajustes |

Todos verificados: HTML balanceado, CSS sin clases huérfanas, JavaScript compilando, y cifras cruzadas entre archivos coincidiendo con los datos reales de origen.

---

## 1. Decisión de plataforma

### 1.1 Recomendación: **Flutter + Firebase**

El requisito cambió: ya no es solo iOS, sino iOS y Android con posibilidad de publicar en ambas tiendas. Eso descarta Swift nativo como única base.

| Opción | A favor | En contra | Veredicto |
|---|---|---|---|
| **Flutter** | Un solo código para ambas · OCR y voz en el dispositivo con plugins maduros · Firebase de primera clase · rendimiento nativo real en listas largas | Los widgets de pantalla de inicio y los atajos de voz del sistema sí requieren código nativo por plataforma | **Elegida** |
| React Native / Expo | Comunidad enorme · si el desarrollador sabe JavaScript, arranca rápido | OCR y voz en el dispositivo con soporte más frágil · listas largas rinden peor | Alternativa |
| Kotlin Multiplatform | Máxima calidad de interfaz en cada sistema | Se escribe la interfaz dos veces: casi el doble de trabajo y de mantenimiento | Descartada por costo |
| Swift + Kotlin nativos | Lo mejor de cada plataforma | Dos apps que hay que mantener sincronizadas para siempre | Descartada |

**Por qué Flutter y no otra:** el corazón de esta app no es la interfaz, es la lógica — aritmética de dinero, ciclos, el motor de pronóstico, la cascada de clasificación. Todo eso debe existir **una sola vez** y estar probado una sola vez. Duplicarlo es duplicar la probabilidad de que las cifras de iOS y Android no coincidan, que es el peor error posible en una app de finanzas.

### 1.2 Stack completo

| Capa | Tecnología | Aplica a |
|---|---|---|
| Interfaz | Flutter (Dart) | Ambas |
| Lógica de negocio | Dart puro, sin dependencias de UI | Ambas |
| Base de datos local | Firestore con persistencia offline | Ambas |
| Nube | Firebase: Auth, Firestore, Storage, Cloud Functions | Ambas |
| OCR de tickets | Google ML Kit Text Recognition (en el dispositivo) | Ambas |
| Voz a texto | plugin `speech_to_text` sobre las APIs nativas | Ambas |
| Clasificación IA | Cloud Function → API de modelo de lenguaje | Servidor |
| Biometría | plugin `local_auth` (Face ID / BiometricPrompt) | Ambas |
| Notificaciones | Firebase Cloud Messaging | Ambas |
| Gráficas | `fl_chart` | Ambas |
| Widgets de inicio | WidgetKit (iOS) · Glance (Android) | **Nativo por plataforma** |
| Atajos de voz | App Intents (iOS) · App Actions (Android) | **Nativo por plataforma** |

---

## 2. Arquitectura y estructura de carpetas

```
lib/
├── core/
│   ├── money.dart            ← aritmética en centavos enteros. NUNCA double
│   ├── ciclo.dart            ← cálculo y estado de ciclos
│   └── result.dart
├── domain/                   ← Dart puro, cero dependencias externas
│   ├── modelos/
│   ├── pronostico/           ← el MPC completo (§5)
│   ├── clasificacion/        ← cascada de 4 niveles (§7)
│   ├── presupuesto/          ← reparto, fijos vs variables, rebalanceo
│   └── reglas/               ← invariantes del §6
├── data/
│   ├── repositorios/
│   └── firebase/
├── ui/
│   ├── inicio/  gastos/  captura/  progreso/  ajustes/
│   └── comun/                ← tokens de diseño, el "carril", componentes
└── plataforma/
    ├── ios/                  ← widget, App Intents
    └── android/              ← widget, App Actions

test/
├── domain/                   ← obligatorio: 100% de lo que toca dinero
└── integracion/
```

**Regla dura de arquitectura:** la carpeta `domain/` no puede importar Flutter, Firebase ni nada de plataforma. Debe poder ejecutarse con `dart test` en cualquier máquina, sin emulador. Eso es lo que hace posible verificar el motor de pronóstico y la aritmética de dinero de forma independiente.

---

## 3. Paridad iOS / Android: diferencias a resolver una por una

No basta con "compila en ambas". Estas son las diferencias reales que hay que atender explícitamente.

| Tema | iOS | Android | Cómo se resuelve |
|---|---|---|---|
| **Entrar con Apple** | Obligatorio si hay otro login social | Disponible vía web | Se ofrece en ambas, para que la cuenta sea la misma |
| **Entrar con Google** | Disponible | Nativo | Igual en ambas |
| **Biometría** | Face ID / Touch ID | BiometricPrompt (huella, rostro, PIN) | `local_auth`. El texto se adapta: "Face ID" vs "tu huella" |
| **Voz a texto** | `SFSpeechRecognizer`, modelo ya instalado | Puede requerir descargar el modelo de idioma | En Android, si falta el modelo, se ofrece descargarlo una vez y se explica por qué |
| **OCR** | ML Kit vía pod | ML Kit nativo | Igual en ambas. En iOS se puede usar además Vision como respaldo |
| **Notificaciones** | Permiso explícito, APNs | Permiso desde Android 13, canales | FCM unifica. Un canal por tipo de aviso en Android, para que se puedan apagar por separado igual que en iOS |
| **Widget de inicio** | WidgetKit + App Group para compartir datos | Glance / AppWidget | Código nativo por plataforma. Muestra lo mismo: cuánto queda al día |
| **Atajo de voz** | "Oye Siri, registra un gasto" | "Ok Google, registra un gasto" | App Intents / App Actions. Ambos abren el mismo flujo de dictado |
| **Compartir / exportar** | Share sheet | Intent de compartir | API de Flutter, igual en ambas |
| **Botón atrás** | No existe; gesto de regresar | Botón físico o gestual | Toda pantalla debe manejar "atrás" sin perder datos capturados a medias |
| **Formato de moneda** | `es_MX` | `es_MX` | Se fija por configuración de la app, **no** por la del sistema, para que las cifras no cambien de formato entre equipos |
| **Zona horaria** | — | — | Todo se guarda en UTC. Los ciclos se calculan con la zona del usuario, guardada en su perfil |
| **Fuentes** | Se empaquetan con la app | Se empaquetan con la app | Nunca depender de fuentes del sistema: el diseño debe verse idéntico |

### 3.1 Lo que sí debe verse distinto
No se busca que Android parezca iOS. Se respeta: la posición de los botones de acción, el estilo de los diálogos, el gesto de regresar y las transiciones de cada sistema. **Lo que nunca cambia son las cifras, los textos y la lógica.**

### 3.2 Prueba de paridad obligatoria
Antes de cada publicación, sobre el mismo juego de datos de prueba, en un iPhone y en un Android:
1. El cierre estimado del ciclo debe ser **idéntico al centavo**
2. El plan de ajuste debe proponer **el mismo monto diario**
3. La lista de gastos debe traer **el mismo número de movimientos y el mismo total**
4. Un gasto registrado en uno debe aparecer en el otro **en menos de 5 segundos**

Cualquier diferencia aquí es un bloqueante de publicación, no un detalle.

---

## 4. Modelo de datos consolidado (Firestore)

Todo cuelga de `cuentas/{cuentaId}` desde el día uno — es lo que permite el multiusuario a futuro sin rehacer nada.

```
cuentas/{cuentaId}
├── miembros/{uid}        rol: propietario | editor | lector
├── perfil                zonaHoraria, moneda, tipoIngreso: fijo|variable
├── ciclos/{cicloId}      fechaInicio, fechaFin, estado: abierto|cerrado, snapshot
├── categorias/{catId}    nombre, emoji, tipo: fija|variable,
│                         montoFijoCentavos, diaDelCiclo,      ← solo si fija
│                         presupuestoMensualCentavos,          ← solo si variable
│                         activa, esNecesaria (piso del plan de ajuste)
├── movimientos/{movId}   clientId (idempotencia), fecha, cicloId, periodoNatural,
│                         montoCentavos, categoriaId, medio, descripcion,
│                         estado: activo|propuesto|anulado,
│                         origenCaptura: manual|voz|ticket|recurrente,
│                         ticketId, fotoUrl, esReembolsable, reembolsoId,
│                         clasificadoPorIA, confianzaIA, granularidad
│   └── auditoria/        valor anterior → nuevo, cuándo, desde qué dispositivo
├── reembolsos/{rId}      movimientoId, estado: porCobrar|cobrado,
│                         montoEsperadoCentavos, montoCobradoCentavos, fechaCobro
├── ingresos/{ingId}      tipo: base|extra, montoCentavos, fecha, cicloId,
│                         destinoExtra: apartado|repartido|gasto
├── destinos/{dId}        nombre (default "Reserva"), acumuladoCentavos
├── metas/                pctApartado, montoMetaCentavos, historialPorCiclo
├── reglasAprendidas/{r}  patron, categoriaId, confirmaciones, origen: usuario|ia
├── rollups/{...}         agregados precalculados por ciclo y categoría
├── pronosticos/{...}     salida del MPC (§5)
└── bitacoraPresupuesto/  rebalanceos y cambios de montos fijos
```

**Índices compuestos a declarar por adelantado:**
`(cuentaId, cicloId, estado)` · `(cuentaId, categoriaId, fecha)` · `(cuentaId, fecha desc)` · `(cuentaId, esReembolsable, estado)`

---

## 5. Motor de pronóstico

Especificado completo en **modelo-pronostico-ciclo.md**. Lo que este paquete agrega:

- Vive en `domain/pronostico/` como **Dart puro**, sin dependencias.
- Se ejecuta en dos lugares con **el mismo código**: en la Cloud Function (fuente de verdad) y en el dispositivo (respuesta inmediata al capturar). Si difieren, gana el servidor.
- Las categorías **fijas no entran al modelo**. El cierre estimado es `Σ fijas + MPC(variables)`.
- Cada pronóstico guarda la versión del modelo que lo produjo, para poder auditar después.

---

## 6. Reglas de negocio no negociables

Lista de verificación para quien construya. Cada una tiene su prueba automatizada.

**Dinero**
1. Todo monto se guarda como **entero en centavos**. Prohibido `double` en cualquier operación monetaria.
2. Toda captura lleva `clientId` generado en el dispositivo. El servidor ignora duplicados.
3. Ningún registro financiero se elimina físicamente antes de 30 días. Se anula.
4. Toda edición de monto o categoría se registra en `auditoria/`.

**Ciclos**
5. El `cicloId` se asigna al crear el movimiento y **jamás se recalcula**.
6. Un ciclo cerrado no cambia. Modificarlo exige reabrirlo de forma explícita.
7. Todo movimiento guarda su ciclo de tarjeta **y** su mes natural.

**Categorías**
8. El tipo fija/variable **lo declara el usuario**, no se infiere.
9. Las fijas no se pronostican, no entran al plan de ajuste, no se rebalancean.
10. Las fijas se respetan al repartir presupuesto; solo el sobrante va a las variables. Si las fijas exceden lo disponible, se bloquea y se informa cuánto falta.

**Presupuesto y metas**
11. El total presupuestado **nunca puede exceder** el disponible sin que la app lo señale y ofrezca dos salidas.
12. El rebalanceo mueve presupuesto, **jamás movimientos**.
13. La holgura ofrecida en rebalanceo es **proyectada**, no saldo sin gastar.
14. El alcance del objetivo se muestra siempre junto a la tasa de ahorro, y los ciclos con ingreso extra van marcados.

**Reembolsables**
15. Un reembolsable no cuenta como gasto ni el reembolso como ingreso. Se emparejan.
16. Si el reembolso excede lo pagado, la diferencia entra como ingreso extra.

**Captura**
17. La captura **nunca depende de la red**. Escritura local optimista siempre.
18. Lo que el usuario registra entra activo de inmediato. Solo lo que genera el sistema nace `propuesto`.
19. Las partes de un ticket dividido deben sumar el total al centavo, o no se registra.
20. Antes de eliminar o editar se muestra el efecto exacto en las cifras afectadas.

**Interfaz**
21. Un solo elemento que aprender: la marca de ritmo. Idéntica en toda la app.
22. Cada pantalla que muestra un problema ofrece al menos una salida concreta.
23. Ningún pronóstico se muestra sin una frase que lo explique.
24. Cero jerga técnica y cero códigos de error en textos al usuario.

---

## 7. Cascada de clasificación

Detallada en **como-funciona-la-ia.md**. Resumen para implementación:

| Nivel | Fuente | Dónde corre | Costo |
|---|---|---|---|
| 0 | Catálogo semilla (~300 términos del español de México) empaquetado con la app | Dispositivo, offline | 0 |
| 1 | Reglas explícitas del usuario | Dispositivo, offline | 0 |
| 2 | Historial: comercio o texto ya clasificado antes | Dispositivo, offline | 0 |
| 3 | Modelo de lenguaje vía API | Cloud Function | centavos |

- Umbrales: ≥0.90 aplica marcando "sugerida" · 0.60–0.89 pregunta · <0.60 va a Otros.
- Cada corrección del usuario se guarda en `reglasAprendidas/` y sube al Nivel 1.
- Tope mensual de llamadas configurable. Al alcanzarlo, la app opera con niveles 0–2.
- **Nada identificable sale del dispositivo:** solo el texto de la descripción y los nombres de las categorías.
- Se puede apagar por completo en Ajustes sin perder ninguna función esencial.

---

## 8. Requisitos para publicar en las tiendas

### App Store (Apple)
- **Eliminación de cuenta dentro de la app** — obligatorio. Ya está en Ajustes.
- **Privacy Manifest** declarando qué se recolecta. La app no rastrea: no requiere permiso de seguimiento.
- **Etiquetas de privacidad:** datos financieros vinculados al usuario, no usados para publicidad ni rastreo.
- Sign in with Apple presente por ofrecer login de Google.
- Justificar en la ficha de revisión el uso de micrófono (dictado) y cámara (tickets).

### Play Store (Google)
- **Formulario de Seguridad de datos** coherente con las etiquetas de Apple. Deben decir lo mismo.
- Declarar cifrado en tránsito y en reposo, y el mecanismo de borrado de cuenta.
- Política de permisos: micrófono y cámara solo con uso en primer plano.
- Nivel de API objetivo al día según la política vigente.

### Ambas
- **Política de privacidad y términos** publicados en una URL propia.
- **Aviso claro de que la app no da asesoría financiera** ni maneja dinero: solo registra lo que el usuario captura. No se conecta a bancos, no mueve fondos. Esto la mantiene fuera de regulación financiera.
- Textos de la ficha en español de México, con capturas de pantalla de ambos tamaños.

---

## 9. Fases de construcción con criterios de aceptación

| Fase | Alcance | Se considera terminada cuando |
|---|---|---|
| **0 · Cimientos** | Proyecto Flutter, `domain/` puro, aritmética en centavos, ciclos, idempotencia, reglas de seguridad, ambiente de pruebas | `dart test` pasa al 100% en `domain/` sin emulador |
| **1 · Núcleo** | Login Apple/Google, categorías fijas/variables, captura manual, offline-first, migración desde Excel con reconciliación | Un ciclo completo capturado a mano cuadra al centavo contra el Excel de origen |
| **2 · Cifras** | Rollups, reconciliación nocturna, Inicio con el carril, detalle de categoría, lista con búsqueda y filtros | El dashboard carga en menos de 300 ms con 5,000 movimientos cargados |
| **3 · Captura rápida** | Dictado con varios gastos, foto de ticket con división, duplicar, deslizar para eliminar y editar | El parser de voz pasa su juego de 15 frases reales; las partes de un ticket siempre suman el total |
| **4 · Inteligencia** | MPC completo, cascada de clasificación, plan de ajuste, rebalanceo, alertas por ritmo | El pronóstico se reproduce idéntico en servidor y dispositivo |
| **5 · Ciclo de vida** | Cierre de ciclo, alcance y tasa de ahorro, trazabilidad, ingresos extra, reembolsables | Tres ciclos simulados de punta a punta sin descuadre |
| **6 · Paridad y tiendas** | Widgets, atajos de voz, accesibilidad, pruebas de paridad, fichas de tienda | La prueba de paridad del §3.2 pasa en ambos sistemas |

---

## 10. Suite de pruebas obligatoria

| Tipo | Qué cubre | Umbral |
|---|---|---|
| Unitarias de `domain/` | Aritmética de dinero, ciclos, reparto con fijos, MPC, cascada de clasificación | **100% de cobertura**, sin excepciones |
| De reconciliación | Los rollups siempre igualan la suma de movimientos crudos | Diferencia = 0 |
| De idempotencia | La misma captura enviada N veces produce un solo movimiento | Siempre |
| Offline | Capturar sin red, recuperar red, verificar que todo subió | Sin pérdidas |
| De conflicto | Editar el mismo gasto en dos dispositivos | Se conserva lo más reciente **por campo** |
| De migración | Importar el Excel real y comparar totales | Cuadre al centavo o se detiene |
| **De paridad** | El §3.2 completo | Idéntico en iOS y Android |
| De interfaz | Estados vacíos, de error, y que ningún botón lleve a un callejón | Todos los caminos |

---

## 11. Riesgos y decisiones pendientes

| Tema | Situación |
|---|---|
| **Historial corto** | Con 3 ciclos el pronóstico opera en confianza media. Alcanza precisión plena alrededor del ciclo 7. Ya está declarado en la interfaz; no ocultarlo. |
| **Frecuencia por movimiento en mayo y junio** | Esos ciclos se importaron como totales diarios, sin conteo de movimientos. El modelo de frecuencia × severidad solo se entrena de julio en adelante. |
| **Widgets y atajos** | Es el único código que se escribe dos veces. Mantenerlos deliberadamente simples para que no se desincronicen. |
| **Costo de IA con muchos usuarios** | Hoy es irrelevante para un usuario. Si la app crece, conviene evaluar un modelo pequeño en el dispositivo para el Nivel 3. |
| **Multiusuario** | El modelo ya lo soporta. Lo que falta diseñar es la interfaz de invitaciones, roles y vista compartida. |
| **Accesibilidad** | Falta especificar tamaños de texto dinámicos, lectores de pantalla y contraste. Debe entrar en la fase 6, no después. |

---

## 12. La prueba que decide si la app está bien hecha

Una sola, y es la que hay que repetir cada ciclo:

> **Al cerrar el mes, ¿la app cuadra al centavo contra el estado de cuenta?**

Si cuadra, todo lo demás —los pronósticos, las alertas, los planes de ajuste— tiene sobre qué pararse. Si no cuadra, ninguna de esas funciones sirve de nada, por bien diseñadas que estén.
