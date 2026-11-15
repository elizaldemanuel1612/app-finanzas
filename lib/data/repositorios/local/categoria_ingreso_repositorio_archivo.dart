import '../../../domain/modelos/categoria_ingreso.dart';
import '../../almacenamiento/archivo_texto.dart';
import '../categoria_ingreso_repositorio.dart';
import 'almacen_json.dart';

final class CategoriaIngresoRepositorioArchivo implements CategoriaIngresoRepositorio {
  final AlmacenJsonLista _almacen;

  CategoriaIngresoRepositorioArchivo.sobre(ArchivoTexto texto) : _almacen = AlmacenJsonLista.sobre(texto);

  @override
  Future<List<CategoriaIngreso>> listarTodas() async {
    // Sin archivo todavía: se siembran las sugeridas. Un archivo que existe
    // (aunque el respaldo lo haya dejado vacío) se respeta.
    if (await _almacen.texto.leer() == null) {
      await _almacen.escribir([for (final c in categoriasIngresoSugeridas) c.toJson()]);
    }
    return (await _almacen.leer()).map(CategoriaIngreso.fromJson).toList();
  }

  @override
  Future<void> guardar(CategoriaIngreso categoria) async {
    final items = [for (final c in await listarTodas()) c.toJson()];
    final indice = items.indexWhere((i) => i['id'] == categoria.id);
    if (indice == -1) {
      items.add(categoria.toJson());
    } else {
      items[indice] = categoria.toJson();
    }
    await _almacen.escribir(items);
  }
}
