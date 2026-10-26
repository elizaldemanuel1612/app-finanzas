import 'package:shared_preferences/shared_preferences.dart';

import 'archivo_texto.dart';

/// [ArchivoTexto] para la web: una entrada del almacenamiento del navegador
/// (spec-app-finanzas-v2.md §4.2.2). El navegador puede borrarlo si el
/// sitio no se usa; por eso la web recomienda el respaldo en la nube.
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
