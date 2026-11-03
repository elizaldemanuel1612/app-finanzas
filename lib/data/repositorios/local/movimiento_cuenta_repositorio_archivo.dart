import '../../../domain/modelos/movimiento_cuenta.dart';
import '../../almacenamiento/archivo_texto.dart';
import '../movimiento_cuenta_repositorio.dart';
import 'almacen_json.dart';

final class MovimientoCuentaRepositorioArchivo implements MovimientoCuentaRepositorio {
  final AlmacenJsonLista _almacen;

  MovimientoCuentaRepositorioArchivo.sobre(ArchivoTexto texto) : _almacen = AlmacenJsonLista.sobre(texto);

  @override
  Future<MovimientoCuenta> guardar(MovimientoCuenta movimiento) async {
    final items = await _almacen.leer();
    for (final i in items) {
      if (i['clientId'] == movimiento.clientId) return MovimientoCuenta.fromJson(i);
    }
    items.add(movimiento.toJson());
    await _almacen.escribir(items);
    return movimiento;
  }

  @override
  Future<List<MovimientoCuenta>> listarTodos() async => (await _almacen.leer()).map(MovimientoCuenta.fromJson).toList();

  @override
  Future<void> anular(String clientId) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((i) => i['clientId'] == clientId);
    if (indice == -1) throw StateError('No existe el movimiento de cuenta $clientId.');
    items[indice] = MovimientoCuenta.fromJson(items[indice]).anulado().toJson();
    await _almacen.escribir(items);
  }
}
