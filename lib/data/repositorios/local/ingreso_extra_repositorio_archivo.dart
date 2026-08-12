import 'dart:io';

import '../../../domain/modelos/ingreso_extra.dart';
import '../ingreso_extra_repositorio.dart';
import 'almacen_json.dart';

final class IngresoExtraRepositorioArchivo implements IngresoExtraRepositorio {
  final AlmacenJsonLista _almacen;

  IngresoExtraRepositorioArchivo(File archivo) : _almacen = AlmacenJsonLista(archivo);

  @override
  Future<IngresoExtra> guardar(IngresoExtra ingreso) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((item) => item['id'] == ingreso.id);
    if (indice == -1) {
      items.add(ingreso.toJson());
    } else {
      items[indice] = ingreso.toJson();
    }
    await _almacen.escribir(items);
    return ingreso;
  }

  @override
  Future<List<IngresoExtra>> listarPorCiclo(String cicloId) async {
    final items = await _almacen.leer();
    return items.map(IngresoExtra.fromJson).where((i) => i.cicloId == cicloId).toList();
  }

  @override
  Future<List<IngresoExtra>> listarTodos() async {
    final items = await _almacen.leer();
    return items.map(IngresoExtra.fromJson).toList();
  }

  @override
  Future<void> anular(String id) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((item) => item['id'] == id);
    if (indice == -1) {
      throw StateError('No existe un ingreso extra con id $id.');
    }
    final anulado = IngresoExtra.fromJson(items[indice]).copyWith(estado: EstadoIngreso.anulado);
    items[indice] = anulado.toJson();
    await _almacen.escribir(items);
  }
}
