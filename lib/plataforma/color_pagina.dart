import 'color_pagina/color_pagina_nativo.dart'
    if (dart.library.js_interop) 'color_pagina/color_pagina_web.dart' as impl;

/// En la web, pinta el fondo de la página y el `theme-color` con [argb], el
/// fondo de la app. Safari colorea la franja de la hora y la batería con el
/// fondo de la página: sin esto se veía blanca arriba de la app en modo
/// oscuro (2026-11-15). En el teléfono no hace nada (la barra la maneja
/// `SystemUiOverlayStyle`).
void pintarFondoDePagina(int argb) => impl.pintarFondoDePagina(argb);
