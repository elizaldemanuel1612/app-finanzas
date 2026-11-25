import 'otra_pestana/otra_pestana_nativo.dart'
    if (dart.library.js_interop) 'otra_pestana/otra_pestana_web.dart' as impl;

/// En la web, [accion] corre cuando otra pestaña con la app abierta cambia
/// el almacenamiento del navegador (evento `storage`). Fuera de la web no
/// hace nada.
void alCambiarEnOtraPestana(void Function() accion) => impl.alCambiarEnOtraPestana(accion);
