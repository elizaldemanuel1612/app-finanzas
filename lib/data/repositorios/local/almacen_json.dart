import 'dart:convert';
import 'dart:io';

/// Lee y escribe una lista de objetos JSON en un archivo, con escritura
/// atómica (escribe a un temporal y renombra) para que un corte de luz a
/// medio guardar no deje el archivo corrupto.
///
/// Recibe el [archivo] por fuera (nunca decide la ruta él mismo) para que
/// se pueda probar con `dart test` sin `path_provider` ni un dispositivo:
/// las pruebas le pasan un directorio temporal cualquiera.
final class AlmacenJsonLista {
  final File archivo;
  const AlmacenJsonLista(this.archivo);

  Future<List<Map<String, dynamic>>> leer() async {
    if (!await archivo.exists()) return [];
    final contenido = await archivo.readAsString();
    if (contenido.trim().isEmpty) return [];
    final decodificado = jsonDecode(contenido) as List<dynamic>;
    return decodificado.cast<Map<String, dynamic>>();
  }

  Future<void> escribir(List<Map<String, dynamic>> items) async {
    await archivo.parent.create(recursive: true);
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(jsonEncode(items));
    await temporal.rename(archivo.path);
  }
}
