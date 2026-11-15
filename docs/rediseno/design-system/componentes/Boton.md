# Boton

El botón dice la acción con el monto o el resultado: "Mover $620", no "Aceptar".

- **Primario**: uno por pantalla, máximo. Fondo `accion`, texto `sobre-accion`. Alto 52, radio `radio-m`.
- **Secundario**: borde `borde-control` de 1.5 px. Para la segunda acción de una pantalla.
- **Texto**: subrayado, para "Ver todo" y acciones terciarias. Alto táctil 44.
- **Ícono**: 44 × 44 con `aria-label` siempre.
- **FAB ＋**: el único uso de `oro` en controles. 60 × 60, sombra `sombra-fab`, vive en la barra inferior y nunca se oculta en pantallas raíz.
- Estados: reposo, presionado (`accion-presionada`), enfocado (anillo `foco` de 2 px con 2 px de aire), cargando (spinner y verbo en gerundio, sin cambiar el ancho), deshabilitado (`superficie-hundida` + `texto-desactivado`).
- No: dos primarios en la misma vista; texto dorado; botones de solo ícono sin etiqueta accesible.
