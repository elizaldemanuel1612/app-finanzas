import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io' show Directory;

import '../repositorios/local/almacen_local.dart';
import 'archivo_texto.dart';

/// [ArchivoTexto] para la web: una entrada del almacenamiento del navegador
/// (spec-app-finanzas-v2.md §4.2.2). El navegador puede borrarlo si el
/// sitio no se usa; por eso la web recomienda el respaldo en Drive.
final class ArchivoTextoNavegador implements ArchivoTexto {
  final String clave;

  const ArchivoTextoNavegador(this.clave);

  static final _preferencias = SharedPreferencesAsync();

  @override
  Future<String?> leer() => _preferencias.getString(clave);

  @override
  Future<void> escribir(String contenido) => _preferencias.setString(clave, contenido);

  @override
  Future<void> borrar() => _preferencias.remove(clave);
}

/// Los datos de la cuenta [uid] en la web: almacenamiento del navegador,
/// separado por cuenta igual que en el teléfono (§4.2.2).
AlmacenLocal almacenEnNavegador(String uid) => AlmacenLocal.con(
      directorio: Directory('navegador/$uid'),
      archivos: {
        for (final nombre in AlmacenLocal.nombresDeArchivo)
          nombre: ArchivoTextoNavegador('usuarios/$uid/$nombre'),
      },
      estadoNube: ArchivoTextoNavegador('usuarios/$uid/nube.json'),
      admiteFotos: false,
    );
