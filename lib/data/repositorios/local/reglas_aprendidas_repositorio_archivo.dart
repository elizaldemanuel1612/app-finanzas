import 'dart:io';

import '../../../domain/clasificacion/regla_aprendida.dart';
import '../reglas_aprendidas_repositorio.dart';
import '../../almacenamiento/archivo_texto.dart';
import 'almacen_json.dart';

final class ReglasAprendidasRepositorioArchivo implements ReglasAprendidasRepositorio {
  final AlmacenJsonLista _almacen;

  ReglasAprendidasRepositorioArchivo(File archivo) : _almacen = AlmacenJsonLista(archivo);


  /// Sobre cualquier [ArchivoTexto] (p. ej. el navegador en la web).

  ReglasAprendidasRepositorioArchivo.sobre(ArchivoTexto texto) : _almacen = AlmacenJsonLista.sobre(texto);

  @override
  Future<List<ReglaAprendida>> listarTodas() async {
    final items = await _almacen.leer();
    return items.map(ReglaAprendida.fromJson).toList();
  }

  @override
  Future<void> guardarTodas(List<ReglaAprendida> reglas) async {
    await _almacen.escribir(reglas.map((r) => r.toJson()).toList());
  }
}
