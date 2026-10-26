# Política de privacidad — MAVfin

_Última actualización: 2026-08-07._

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

## Qué datos usa la app

| Dato | Para qué | Dónde se guarda |
|---|---|---|
| Correo y UID de tu cuenta de Google | Identificarte al iniciar sesión | Servidores de Firebase Authentication (Google) |
| Movimientos, categorías, ciclos, ingresos extra que capturas | El propósito completo de la app: registrar y pronosticar tus gastos | **Solo en tu dispositivo**, en archivos locales |
| Fotos de tickets que adjuntas | Referencia visual de un gasto | **Solo en tu dispositivo**, en una carpeta propia de la app |
| Audio de dictado por voz | Convertir tu voz a texto al capturar un gasto | Procesado por el motor de reconocimiento de voz del sistema operativo (Android/iOS); **la app no guarda el audio** |

Hoy no existe sincronización en la nube de tus movimientos, categorías ni
fotos: viven únicamente en el almacenamiento local de tu dispositivo. Si
desinstalas la app o usas otro dispositivo, esos datos no te acompañan
automáticamente — para eso existe "Exportar mis gastos" en Ajustes.

## Cifrado

- **En tránsito:** la comunicación con Firebase Authentication usa HTTPS/TLS,
  el estándar de la plataforma.
- **En reposo:** los datos locales quedan protegidos por el cifrado de
  almacenamiento del sistema operativo de tu dispositivo (el mismo que
  protege cualquier otro archivo de tus apps). MAVfin no aplica un
  cifrado adicional propio sobre esos archivos.

## Tus controles

- **Exportar:** Ajustes → "Exportar mis gastos" genera un CSV con todo tu
  historial que puedes compartir o guardar donde quieras.
- **Cerrar sesión:** tus datos locales permanecen en el dispositivo; puedes
  volver a entrar con la misma cuenta de Google.
- **Eliminar cuenta:** Ajustes → "Eliminar cuenta" borra tu cuenta de
  Google Sign-In **y** todos los datos locales (movimientos, categorías,
  ciclos, ingresos extra, fotos de tickets) de ese dispositivo, de forma
  irreversible. La app ofrece exportar tus datos antes de confirmar el
  borrado.

## Terceros involucrados

- **Google (Firebase Authentication, Google Sign-In):** procesa el inicio
  de sesión. Consulta la [política de privacidad de
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
