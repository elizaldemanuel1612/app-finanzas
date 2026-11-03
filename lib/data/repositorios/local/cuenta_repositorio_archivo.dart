import '../../../domain/modelos/cuenta.dart';
import '../../almacenamiento/archivo_texto.dart';
import '../cuenta_repositorio.dart';
import 'almacen_json.dart';

final class CuentaRepositorioArchivo implements CuentaRepositorio {
  final AlmacenJsonLista _almacen;
  final DateTime Function() _reloj;

  CuentaRepositorioArchivo.sobre(ArchivoTexto texto, {DateTime Function()? reloj})
      : _almacen = AlmacenJsonLista.sobre(texto),
        _reloj = reloj ?? DateTime.now;

  @override
  Future<List<Cuenta>> listarTodas() async {
    final items = await _almacen.leer();
    final ids = {for (final i in items) i['id']};
    final faltan = [for (final c in cuentasBase(_reloj())) if (!ids.contains(c.id)) c];
    if (faltan.isNotEmpty) {
      items.addAll([for (final c in faltan) c.toJson()]);
      await _almacen.escribir(items);
    }
    return items.map(Cuenta.fromJson).toList();
  }

  @override
  Future<void> guardar(Cuenta cuenta) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((i) => i['id'] == cuenta.id);
    if (indice == -1) {
      items.add(cuenta.toJson());
    } else {
      items[indice] = cuenta.toJson();
    }
    await _almacen.escribir(items);
  }
}
