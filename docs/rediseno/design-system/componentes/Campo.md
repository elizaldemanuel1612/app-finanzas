# Campo

El campo de monto es el corazón de Registrar: "$" fijo, comas de miles automáticas y centavos atenuados.

- **Monto**: `cifra-heroe` a 56 px; el "$" y los centavos en `texto-2`. Teclado numérico propio de la app (sin teclado del sistema), con ⌫ y punto.
- **Texto**: alto 52, borde `borde-control`. La etiqueta va como placeholder solo si el campo es opcional y obvio; si no, etiqueta arriba.
- **Enfocado**: borde de 2 px en `foco`. **Error**: borde `peligro-texto` y mensaje debajo con ícono, que dice cómo arreglarlo.
- **Búsqueda**: fondo `superficie-hundida`, sin borde, ícono a la izquierda.
- No: validar mientras se escribe; mensajes técnicos ("formato inválido").
