# Formulario de Seguridad de datos (Play) / App Privacy (App Store)

Auditoría de qué recoge la app de verdad, para responder el formulario de
Play Console **y** las etiquetas de privacidad de Apple con las mismas
respuestas — §8 del paquete de construcción exige que digan lo mismo.
Escrito para copiarse verbatim entre ambos formularios.

## Inventario real de datos (auditado contra el código)

| Dato | Se recolecta | Se comparte con terceros | Dónde vive | Por qué |
|---|---|---|---|---|
| Correo electrónico | Sí | Sí — Google (autenticación) | Firebase Authentication | Iniciar sesión |
| Identificador de usuario (UID de Google) | Sí | Sí — Google (autenticación) | Firebase Authentication | Identificar la cuenta |
| Movimientos financieros (monto, categoría, fecha, descripción) | Sí | No | Solo local, JSON en disco del dispositivo (`AlmacenJsonLista`) | El propósito de la app |
| Categorías y presupuestos | Sí | No | Solo local | El propósito de la app |
| Fotos de tickets | Sí | No | Solo local, `<documentos>/tickets/` (`AlmacenFotos`) | Referencia visual del gasto |
| Audio de dictado por voz | Procesado, no almacenado | Sí — el motor de reconocimiento de voz del sistema operativo (Google/Apple), fuera del control de la app | No se guarda | Convertir voz a texto al capturar |
| Identificadores de dispositivo, publicidad, ubicación, contactos, etc. | **No** | — | — | La app no los pide ni los usa |

## Respuestas sugeridas — Google Play (Seguridad de datos)

- **¿La app recopila o comparte alguno de los tipos de datos requeridos?**
  Sí.
- **Información personal → Correo electrónico:** recopilada, compartida con
  Google (autenticación), no opcional (necesaria para usar la app).
- **Información financiera → Otra información financiera** (los
  movimientos que el usuario captura): recopilada, **no compartida**, uso:
  "Funcionalidad de la app", el usuario puede solicitar que se borre
  (Ajustes → Eliminar cuenta).
- **Fotos:** recopiladas (fotos de tickets adjuntas por el usuario), **no
  compartidas**, uso: "Funcionalidad de la app".
- **Audio:** procesado transitoriamente para dictado; **no se recolecta ni
  se almacena** por la app — declarar como "no recolectado", con nota de
  que el sistema operativo procesa el audio bajo su propia política.
- **Cifrado en tránsito:** Sí (HTTPS/TLS, vía Firebase).
- **Los usuarios pueden solicitar que se borren los datos:** Sí — dentro
  de la app (Ajustes → Eliminar cuenta) y por la URL web de solicitud de
  eliminación de cuenta (bloqueante de publicación, ver
  `docs/paridad-3-2-procedimiento.md` y Bloque 2.5 del plan de Fase 6).

## Respuestas sugeridas — App Store (App Privacy / "Nutrition Labels")

Mismo inventario, mapeado a las categorías de Apple:

- **Contact Info → Email Address:** vinculado a la identidad del usuario,
  usado para autenticación de cuenta. No usado para tracking.
- **Financial Info → Other Financial Info:** vinculado a la identidad del
  usuario (los movimientos capturados), usado únicamente para la
  funcionalidad de la app. No usado para tracking.
- **User Content → Photos or Videos:** vinculado a la identidad del
  usuario (fotos de tickets), usado únicamente para la funcionalidad de la
  app.
- **Audio Data:** **no recolectado por la app** — el dictado lo procesa el
  motor de voz del sistema.
- **Identifiers, Location, Contacts, Usage Data, Diagnostics:** no
  recolectados.
- **Data Not Linked to You / Tracking:** la app no usa los datos para
  rastrear al usuario entre apps o sitios de terceros — "No" en tracking.

## Nota de auditoría

Este inventario se generó leyendo directamente `lib/data/` (qué
repositorios existen y qué guardan) y `lib/domain/voz/` (que el audio se
transcribe con `speech_to_text` sin persistirlo). Si se agrega una
integración nueva (por ejemplo, Firestore real, o un proveedor de IA en el
Nivel 3 de la cascada de clasificación), **este documento y ambos
formularios deben actualizarse antes de la siguiente publicación** — no
después.
