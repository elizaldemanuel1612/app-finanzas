import 'dart:convert';
import 'dart:io';

import '../../../domain/modelos/perfil.dart';
import '../../almacenamiento/archivo_texto.dart';
import '../../almacenamiento/archivo_texto_disco.dart';
import '../perfil_repositorio.dart';

final class PerfilRepositorioArchivo implements PerfilRepositorio {
  final ArchivoTexto texto;

  PerfilRepositorioArchivo(File archivo) : texto = ArchivoTextoDisco(archivo);

  /// Sobre cualquier [ArchivoTexto] (p. ej. el navegador en la web).
  const PerfilRepositorioArchivo.sobre(this.texto);

  @override
  Future<Perfil?> obtener() async {
    final contenido = await texto.leer();
    if (contenido == null || contenido.trim().isEmpty) return null;
    return Perfil.fromJson(jsonDecode(contenido) as Map<String, dynamic>);
  }

  @override
  Future<void> guardar(Perfil perfil) => texto.escribir(jsonEncode(perfil.toJson()));
}
