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

  AlmacenJsonLista.sobre(this.texto);

  /// El último texto decodificado y su resultado (2026-11-25): Inicio,
  /// el traslado y cada pestaña leen todos los gastos; si el archivo no
  /// cambió, no se vuelve a decodificar. Comparar el texto es mucho más
  /// barato que decodificarlo, y así lo que escriba Siri en el disco sí
  /// se ve.
  String? _ultimoTexto;
  List<Map<String, dynamic>> _ultimo = const [];

  /// Una lista nueva cada vez (quien la recibe la modifica para guardar);
  /// los mapas se comparten y nadie los modifica en su lugar.
  Future<List<Map<String, dynamic>>> leer() async {
    final contenido = await texto.leer();
    if (contenido == null || contenido.trim().isEmpty) return [];
    if (contenido != _ultimoTexto) {
      _ultimo = List<Map<String, dynamic>>.from(jsonDecode(contenido) as List<dynamic>);
      _ultimoTexto = contenido;
    }
    return List.of(_ultimo);
  }

  Future<void> escribir(List<Map<String, dynamic>> items) async {
    final contenido = jsonEncode(items);
    _ultimoTexto = null;
    await texto.escribir(contenido);
    _ultimo = List.of(items);
    _ultimoTexto = contenido;
  }
}
