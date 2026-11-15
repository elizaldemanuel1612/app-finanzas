import '../../../domain/modelos/objetivo.dart';
import '../../almacenamiento/archivo_texto.dart';
import '../objetivo_repositorio.dart';
import 'almacen_json.dart';

final class ObjetivoRepositorioArchivo implements ObjetivoRepositorio {
  final AlmacenJsonLista _almacen;

  ObjetivoRepositorioArchivo.sobre(ArchivoTexto texto) : _almacen = AlmacenJsonLista.sobre(texto);

  @override
  Future<List<Objetivo>> listarTodos() async => (await _almacen.leer()).map(Objetivo.fromJson).toList();

  @override
  Future<void> guardar(Objetivo objetivo) async {
    final items = await _almacen.leer();
    final indice = items.indexWhere((i) => i['id'] == objetivo.id);
    if (indice == -1) {
      items.add(objetivo.toJson());
    } else {
      items[indice] = objetivo.toJson();
    }
    await _almacen.escribir(items);
  }

  @override
  Future<void> eliminar(String id) async {
    final items = await _almacen.leer();
    final antes = items.length;
    items.removeWhere((i) => i['id'] == id);
    if (items.length != antes) await _almacen.escribir(items);
  }
}
