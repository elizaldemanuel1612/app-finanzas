import 'dart:convert';
import 'dart:io';

import '../../../domain/modelos/perfil.dart';
import '../perfil_repositorio.dart';

final class PerfilRepositorioArchivo implements PerfilRepositorio {
  final File archivo;

  const PerfilRepositorioArchivo(this.archivo);

  @override
  Future<Perfil?> obtener() async {
    if (!await archivo.exists()) return null;
    final contenido = await archivo.readAsString();
    if (contenido.trim().isEmpty) return null;
    return Perfil.fromJson(jsonDecode(contenido) as Map<String, dynamic>);
  }

  @override
  Future<void> guardar(Perfil perfil) async {
    await archivo.parent.create(recursive: true);
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(jsonEncode(perfil.toJson()));
    await temporal.rename(archivo.path);
  }
}
