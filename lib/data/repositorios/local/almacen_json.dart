import 'dart:convert';
import 'dart:io';

import '../../almacenamiento/archivo_texto.dart';
import '../../almacenamiento/archivo_texto_disco.dart';

/// Lee y escribe una lista de objetos JSON en un [ArchivoTexto] — un
/// archivo del dispositivo o, en la web, el almacenamiento del navegador
/// (spec-app-finanzas-v2.md §4.2.2). En disco la escritura es atómica
/// (temporal + renombrar) para que un corte a medio guardar no lo corrompa.
///
/// Recibe el destino por fuera (nunca decide la ruta él mismo) para que se
/// pueda probar con `dart test` sin `path_provider` ni un dispositivo.
final class AlmacenJsonLista {
  final ArchivoTexto texto;

  AlmacenJsonLista(File archivo) : texto = ArchivoTextoDisco(archivo);

  const AlmacenJsonLista.sobre(this.texto);

  Future<List<Map<String, dynamic>>> leer() async {
    final contenido = await texto.leer();
    if (contenido == null || contenido.trim().isEmpty) return [];
    final decodificado = jsonDecode(contenido) as List<dynamic>;
    return decodificado.cast<Map<String, dynamic>>();
  }

  Future<void> escribir(List<Map<String, dynamic>> items) => texto.escribir(jsonEncode(items));
}
