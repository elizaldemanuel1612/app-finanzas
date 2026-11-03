import '../data/seguridad/candado.dart';
import 'derivar_clave/derivar_clave_nativo.dart'
    if (dart.library.js_interop) 'derivar_clave/derivar_clave_web.dart' as impl;

/// PBKDF2-SHA256 para el [Candado]: en la web, la del navegador (WebCrypto,
/// nativa y asíncrona); en el teléfono, la de Dart. Dan la misma huella, así
/// que un PIN creado con una se reconoce con la otra.
const DerivarClave derivarClave = impl.derivarClave;
