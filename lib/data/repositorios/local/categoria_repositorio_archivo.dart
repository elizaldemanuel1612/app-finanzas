import 'dart:io';

import '../../../domain/modelos/categoria.dart';
import '../categoria_repositorio.dart';
import 'almacen_json.dart';

final class CategoriaRepositorioArchivo implements CategoriaRepositorio {
  final AlmacenJsonLista _almacen;

  CategoriaRepositorioArchivo(File archivo) : _almacen = AlmacenJsonLista(archivo);

  @override
  Future<void> guardar(Categoria categoria) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((item) => item['id'] == categoria.id);
    if (indice == -1) {
      items.add(categoria.toJson());
    } else {
      items[indice] = categoria.toJson();
    }
    await _almacen.escribir(items);
  }

  @override
  Future<List<Categoria>> listarActivas() async {
    final todas = await listarTodas();
    return todas.where((c) => c.activa).toList();
  }

  @override
  Future<List<Categoria>> listarTodas() async {
    final items = await _almacen.leer();
    return items.map(Categoria.fromJson).toList();
  }

  @override
  Future<Categoria?> buscarPorId(String id) async {
    final items = await _almacen.leer();
    for (final item in items) {
      if (item['id'] == id) return Categoria.fromJson(item);
    }
    return null;
  }

  @override
  Future<void> eliminar(String id) async {
    final items = await _almacen.leer();
    items.removeWhere((item) => item['id'] == id);
    await _almacen.escribir(items);
  }
}
