import 'dart:typed_data';

import 'elegir_archivo/elegir_archivo_nativo.dart'
    if (dart.library.js_interop) 'elegir_archivo/elegir_archivo_web.dart' as impl;

/// Un archivo que eligió el usuario, ya leído.
final class ArchivoElegido {
  final String nombre;
  final Uint8List bytes;

  const ArchivoElegido(this.nombre, this.bytes);
}

/// Abre el selector de archivos del sistema filtrando por [extensiones] (sin
/// punto). `null` si el usuario cancela.
///
/// En la web no se usa `file_picker`: su versión web da por cancelado el
/// selector cuando la página recupera el foco y el archivo no llegó en
/// 500 ms, y en iPhone (Archivos/iCloud) casi nunca llega tan rápido, así
/// que elegir un CSV "no hacía nada" (2026-10-28).
Future<ArchivoElegido?> elegirArchivo({required List<String> extensiones}) =>
    impl.elegirArchivo(extensiones);
