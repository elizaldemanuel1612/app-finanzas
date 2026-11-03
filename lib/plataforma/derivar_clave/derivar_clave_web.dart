import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../data/seguridad/candado.dart';

/// `crypto.subtle.deriveBits` con PBKDF2-SHA256. Si el navegador no lo
/// ofrece (sin HTTPS, por ejemplo), cae a la versión de Dart.
Future<List<int>> derivarClave(String secreto, List<int> sal, int iteraciones) async {
  try {
    final sutil = web.window.crypto.subtle;
    final clave = await sutil
        .importKey(
          'raw',
          Uint8List.fromList(utf8.encode(secreto)).toJS,
          'PBKDF2'.toJS,
          false,
          ['deriveBits'.toJS].toJS,
        )
        .toDart;
    final algoritmo = JSObject()
      ..setProperty('name'.toJS, 'PBKDF2'.toJS)
      ..setProperty('hash'.toJS, 'SHA-256'.toJS)
      ..setProperty('salt'.toJS, Uint8List.fromList(sal).toJS)
      ..setProperty('iterations'.toJS, iteraciones.toJS);
    final bits = await sutil.deriveBits(algoritmo, clave, 256).toDart;
    return bits.toDart.asUint8List().toList();
  } catch (_) {
    return pbkdf2Sha256(secreto, sal, iteraciones);
  }
}
