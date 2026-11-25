import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io' show Directory;

import '../repositorios/local/almacen_local.dart';
import 'archivo_texto.dart';

/// [ArchivoTexto] para la web: una entrada del almacenamiento del navegador
/// (spec-app-finanzas-v2.md §4.2.2). El navegador puede borrarlo si el
/// sitio no se usa; por eso la web recomienda el respaldo en Drive.
///
/// Lo leído se guarda en memoria (2026-11-25): traer del navegador un
/// archivo grande (los gastos de años) es copiarlo y decodificarlo dos
/// veces, y al abrir la app se leía unas cinco veces — la app tardaba en
/// cargar y se quedaba pasmada. Otra pestaña con la app abierta puede
/// escribir lo mismo: `main.dart` llama a [olvidarLoLeido] cuando el
/// navegador avisa que cambió algo desde fuera (`plataforma/otra_pestana.dart`).
final class ArchivoTextoNavegador implements ArchivoTexto {
  final String clave;

  const ArchivoTextoNavegador(this.clave);

  static final _preferencias = SharedPreferencesAsync();

  /// Lo último leído o escrito de cada clave en esta pestaña.
  static final _enMemoria = <String, String?>{};

  /// Lo que otra pestaña pudo haber cambiado se vuelve a leer del navegador.
  static void olvidarLoLeido() => _enMemoria.clear();

  @override
  Future<String?> leer() async {
    if (_enMemoria.containsKey(clave)) return _enMemoria[clave];
    final contenido = await _preferencias.getString(clave);
    _enMemoria[clave] = contenido;
    return contenido;
  }

  @override
  Future<void> escribir(String contenido) async {
    _enMemoria.remove(clave);
    await _preferencias.setString(clave, contenido);
    _enMemoria[clave] = contenido;
  }

  @override
  Future<void> borrar() async {
    _enMemoria.remove(clave);
    await _preferencias.remove(clave);
    _enMemoria[clave] = null;
  }
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
      candado: ArchivoTextoNavegador('usuarios/$uid/candado.json'),
      ia: ArchivoTextoNavegador('usuarios/$uid/ia.json'),
      admiteFotos: false,
    );
