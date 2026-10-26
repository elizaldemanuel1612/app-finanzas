# Política de privacidad — MAVfin

_Última actualización: 2026-10-26._

MAVfin es una herramienta personal de registro y pronóstico de
gastos. Esta política describe, en términos llanos, qué datos usa la app,
dónde se guardan y qué control tienes sobre ellos.

## Qué NO hace la app

- **No da asesoría financiera.** Las cifras que muestra son estimaciones
  basadas en lo que tú capturas, no recomendaciones de inversión ni de
  crédito.
- **No se conecta a bancos ni tarjetas.** No hay integración bancaria de
  ningún tipo.
- **No maneja dinero real.** Nunca mueve, transfiere ni retiene fondos.
- **No guarda tus datos financieros en servidores propios.** Quien hace la
  app no tiene acceso a tus gastos, categorías ni ingresos: viven en tu
  dispositivo y, solo si tú lo activas, en tu propio Google Drive.

## Qué datos usa la app

| Dato | Para qué | Dónde se guarda |
|---|---|---|
| Correo y UID de tu cuenta de Google | Identificarte al iniciar sesión | Servidores de Firebase Authentication (Google) |
| Movimientos, categorías, ciclos, ingresos extra, metas y ajustes que capturas | El propósito completo de la app: registrar y pronosticar tus gastos | **En tu dispositivo** (en la versión web, en el almacenamiento de tu navegador). **Opcional:** una copia en **tu propio Google Drive**, solo si activas el respaldo |
| Fotos de tickets que adjuntas | Referencia visual de un gasto | **Solo en tu dispositivo**, en una carpeta propia de la app; nunca se suben |
| Audio de dictado por voz | Convertir tu voz a texto al capturar un gasto | Procesado por el motor de reconocimiento de voz del sistema operativo (Android/iOS); **la app no guarda el audio** |

## Respaldo en tu Google Drive (opcional)

Está **apagado** hasta que tú lo activas en Ajustes → "Respaldo en tu Google
Drive". Al activarlo:

- Google te pide permiso para que MAVfin use **solo su propia carpeta
  privada** en tu Drive (permiso `drive.appdata`). La app **no puede ver,
  leer ni modificar ningún otro archivo** de tu Drive.
- La copia es un archivo (`respaldo.json`) con tus movimientos, categorías,
  ciclos, ingresos extra, reglas aprendidas, ajustes de presupuesto y tu
  perfil (día de corte, ingreso, meta). Las fotos de tickets **no** se
  suben.
- Vive en tu cuenta de Google y ocupa tu espacio de Drive. **Quien hace la
  app no tiene acceso a ella**: la app la lee y la escribe directamente
  desde tu dispositivo, sin pasar por servidores propios.
- Sirve para recuperar tus datos en otro teléfono o en la versión web, y
  para mantenerlos iguales entre ellos. Se sincroniza al abrir y al salir
  de la app, o cuando tocas "Sincronizar ahora".

Puedes pausarlo cuando quieras (la copia se conserva) o borrar la copia
desde la misma pantalla. También puedes quitarle el permiso a MAVfin y
borrar sus datos desde Google Drive → Configuración → Administrar apps, o
desde [tu cuenta de Google](https://myaccount.google.com/permissions).

Si no lo activas, tus datos viven únicamente en tu dispositivo: si
desinstalas la app o usas otro dispositivo, no te acompañan
automáticamente — para eso también existe "Exportar mis gastos" en Ajustes.

## Versión web

En el navegador, tus datos se guardan en el almacenamiento de ese navegador
y, separados por cuenta, solo en ese equipo. El navegador puede borrarlos
si no usas el sitio por un tiempo o si borras los datos de navegación; por
eso la web recomienda activar el respaldo en tu Drive. Al iniciar sesión en
la web, la misma ventana de Google pide el permiso de Drive; puedes
desmarcarlo.

## Cifrado

- **En tránsito:** la comunicación con Firebase Authentication y con Google
  Drive usa HTTPS/TLS, el estándar de la plataforma.
- **En reposo:** los datos locales quedan protegidos por el cifrado de
  almacenamiento del sistema operativo de tu dispositivo (el mismo que
  protege cualquier otro archivo de tus apps). MAVfin no aplica un
  cifrado adicional propio sobre esos archivos.
- **Respaldo:** la copia en tu Drive queda protegida por la seguridad de tu
  cuenta de Google (Google cifra los archivos de Drive en reposo).

## Tus controles

- **Exportar:** Ajustes → "Exportar mis gastos" genera un CSV con todo tu
  historial que puedes compartir o guardar donde quieras.
- **Cerrar sesión:** tus datos locales permanecen en el dispositivo; puedes
  volver a entrar con la misma cuenta de Google.
- **Respaldo:** actívalo, páusalo o borra la copia de tu Drive en Ajustes →
  "Respaldo en tu Google Drive".
- **Eliminar cuenta:** Ajustes → "Eliminar cuenta" borra tu cuenta de
  Google Sign-In, todos los datos locales (movimientos, categorías,
  ciclos, ingresos extra, fotos de tickets) de ese dispositivo **y** la
  copia de respaldo en tu Drive, de forma irreversible. La app ofrece exportar tus datos antes de confirmar el
  borrado.

## Terceros involucrados

- **Google (Firebase Authentication, Google Sign-In):** procesa el inicio
  de sesión. Firebase solo conoce tu correo y tu identificador de cuenta,
  nunca tus datos financieros.
- **Google Drive (solo si activas el respaldo):** guarda la copia en tu
  propia cuenta. El uso que MAVfin hace de la información recibida de las
  APIs de Google se apega a la [Política de datos de usuario de los
  servicios de API de Google](https://developers.google.com/terms/api-services-user-data-policy),
  incluidos los requisitos de uso limitado: los datos de tu Drive se usan
  únicamente para guardar y recuperar tu respaldo, no se comparten con
  nadie y no se usan para publicidad. Consulta la [política de privacidad de
  Google](https://policies.google.com/privacy) para lo que Google hace con
  esos datos.
- **Motor de reconocimiento de voz del sistema (Android/iOS):** procesa el
  audio de dictado según la política de privacidad de tu sistema
  operativo. MAVfin no envía ese audio a servidores propios.

## Menores de edad

MAVfin no está dirigida a menores de edad y no recopila a sabiendas
información de menores.

## Cambios a esta política

Si esta política cambia de forma relevante, la fecha de "Última
actualización" se actualiza y, cuando el cambio sea significativo, se
avisa dentro de la app.

## Contacto

Para preguntas sobre esta política o para solicitar la eliminación de tus
datos, contacta a: elizaldemanuel1612@gmail.com.
