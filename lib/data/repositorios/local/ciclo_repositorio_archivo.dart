import 'dart:io';

import '../../../domain/modelos/ciclo_guardado.dart';
import '../ciclo_repositorio.dart';
import 'almacen_json.dart';

final class CicloRepositorioArchivo implements CicloRepositorio {
  final AlmacenJsonLista _almacen;

  CicloRepositorioArchivo(File archivo) : _almacen = AlmacenJsonLista(archivo);

  @override
  Future<CicloGuardado?> buscarPorId(String id) async {
    final items = await _almacen.leer();
    for (final item in items) {
      if (item['id'] == id) return CicloGuardado.fromJson(item);
    }
    return null;
  }

  @override
  Future<List<CicloGuardado>> listarTodos() async {
    final items = await _almacen.leer();
    return items.map(CicloGuardado.fromJson).toList();
  }

  @override
  Future<void> guardar(CicloGuardado guardado) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((item) => item['id'] == guardado.ciclo.id);
    if (indice == -1) {
      items.add(guardado.toJson());
    } else {
      items[indice] = guardado.toJson();
    }
    await _almacen.escribir(items);
  }
}
