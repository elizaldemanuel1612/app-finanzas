import 'dart:io';

import '../../../domain/modelos/estado_movimiento.dart';
import '../../../domain/modelos/movimiento.dart';
import '../movimiento_repositorio.dart';
import 'almacen_json.dart';

/// Implementación local, respaldada por un archivo JSON — el interino de
/// la Fase 1 mientras no hay un proyecto Firebase provisionado. Cumple el
/// contrato [MovimientoRepositorio] completo, así que cuando llegue la
/// implementación de Firestore, ui/ y domain/ no cambian ni una línea.
///
/// Nota de concurrencia: lee todo el archivo, modifica en memoria y
/// reescribe completo. Correcto para el uso serial de un solo dispositivo
/// (que es todo lo que existe hasta que haya sincronización real); no
/// soporta escrituras concurrentes desde dos sitios a la vez.
final class MovimientoRepositorioArchivo implements MovimientoRepositorio {
  final AlmacenJsonLista _almacen;

  MovimientoRepositorioArchivo(File archivo) : _almacen = AlmacenJsonLista(archivo);

  @override
  Future<Movimiento> guardar(Movimiento movimiento) async {
    final items = await _almacen.leer();

    // Regla no negociable #2: si el clientId ya existe, se ignora la
    // escritura y se regresa lo que ya había — sin duplicar.
    for (final item in items) {
      if (item['clientId'] == movimiento.clientId) {
        return Movimiento.fromJson(item);
      }
    }

    final conId =
        movimiento.id == null ? movimiento.copyWith(id: movimiento.clientId) : movimiento;
    items.add(conId.toJson());
    await _almacen.escribir(items);
    return conId;
  }

  @override
  Future<void> actualizar(Movimiento movimiento) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((item) => item['id'] == movimiento.id);
    if (indice == -1) {
      throw StateError('No existe un movimiento con id ${movimiento.id}.');
    }
    items[indice] = movimiento.toJson();
    await _almacen.escribir(items);
  }

  @override
  Future<void> anular(String id) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((item) => item['id'] == id);
    if (indice == -1) {
      throw StateError('No existe un movimiento con id $id.');
    }
    final anulado =
        Movimiento.fromJson(items[indice]).copyWith(estado: EstadoMovimiento.anulado);
    items[indice] = anulado.toJson();
    await _almacen.escribir(items);
  }

  @override
  Future<List<Movimiento>> listarPorCiclo(String cicloId) async {
    final items = await _almacen.leer();
    return items
        .map(Movimiento.fromJson)
        .where((m) => m.cicloId == cicloId)
        .toList();
  }

  @override
  Future<List<Movimiento>> listarTodos() async {
    final items = await _almacen.leer();
    return items.map(Movimiento.fromJson).toList();
  }

  @override
  Future<bool> existeClientId(String clientId) async {
    final items = await _almacen.leer();
    return items.any((item) => item['clientId'] == clientId);
  }
}
