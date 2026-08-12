import 'dart:io';

import '../../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../ajuste_presupuesto_ciclo_repositorio.dart';
import 'almacen_json.dart';

final class AjustePresupuestoCicloRepositorioArchivo
    implements AjustePresupuestoCicloRepositorio {
  final AlmacenJsonLista _almacen;

  AjustePresupuestoCicloRepositorioArchivo(File archivo)
      : _almacen = AlmacenJsonLista(archivo);

  @override
  Future<List<AjustePresupuestoCiclo>> listarPorCiclo(String cicloId) async {
    final items = await _almacen.leer();
    return items
        .map(AjustePresupuestoCiclo.fromJson)
        .where((a) => a.cicloId == cicloId)
        .toList();
  }

  @override
  Future<void> agregarLote(List<AjustePresupuestoCiclo> ajustes) async {
    final items = await _almacen.leer();
    items.addAll(ajustes.map((a) => a.toJson()));
    await _almacen.escribir(items);
  }
}
