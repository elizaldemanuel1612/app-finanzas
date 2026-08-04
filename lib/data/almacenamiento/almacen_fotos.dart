import 'dart:io';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Copia la foto de un ticket a una carpeta propia de la app
/// (`<documentos>/tickets/`) y regresa la ruta final, para usarse como
/// `Movimiento.fotoUrl`. Local por ahora — cuando haya sincronización real
/// con Firestore, esto sube a Storage en vez de copiar a disco, pero el
/// contrato ("dame un File, te doy la URL/ruta final") no cambia.
///
/// [documentos] se recibe por fuera (normalmente
/// `getApplicationDocumentsDirectory()` de path_provider) en vez de
/// resolverse aquí adentro, para que esto se pueda probar con
/// `dart test` sin necesitar bindings de Flutter.
Future<String> guardarFotoTicket(File origen, {required Directory documentos}) async {
  final carpeta = Directory('${documentos.path}/tickets');
  if (!await carpeta.exists()) {
    await carpeta.create(recursive: true);
  }
  final extension = origen.path.contains('.') ? origen.path.split('.').last : 'jpg';
  final destino = File('${carpeta.path}/${_uuid.v4()}.$extension');
  await origen.copy(destino.path);
  return destino.path;
}
