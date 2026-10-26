import 'dart:io';

import 'archivo_texto.dart';

/// [ArchivoTexto] respaldado por un archivo del dispositivo, con escritura
/// atómica (escribe a un temporal y renombra) para que un corte de luz a
/// medio guardar no deje el archivo corrupto.
final class ArchivoTextoDisco implements ArchivoTexto {
  final File archivo;

  const ArchivoTextoDisco(this.archivo);

  @override
  Future<String?> leer() async {
    if (!await archivo.exists()) return null;
    return archivo.readAsString();
  }

  @override
  Future<void> escribir(String contenido) async {
    await archivo.parent.create(recursive: true);
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(contenido);
    await temporal.rename(archivo.path);
  }

  @override
  Future<void> borrar() async {
    if (await archivo.exists()) await archivo.delete();
  }
}
