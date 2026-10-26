import 'dart:convert';

import 'package:http/http.dart' as http;

import 'respaldo_remoto.dart';

/// Pide el token de acceso de Google con el permiso `drive.appdata`. Con
/// [interactivo] puede mostrar la ventana de permiso; sin él devuelve
/// `null` si haría falta preguntar.
typedef ProveedorTokenDrive = Future<String?> Function({required bool interactivo});

/// Respaldo en el Google Drive del propio usuario (spec-app-finanzas-v2.md
/// §4.2.1): un solo archivo, `respaldo.json`, en la carpeta privada de la
/// app (`appDataFolder`). No aparece entre sus archivos, solo esta app lo
/// lee, y quien desarrolla la app no tiene acceso.
///
/// API REST de Drive v3 directa con `http`: son cuatro llamadas y no
/// justifican el paquete `googleapis` completo.
final class RespaldoDrive implements RespaldoRemoto {
  final ProveedorTokenDrive token;

  /// Avisa que un token dejó de servir (401) para que no se reuse.
  final Future<void> Function(String token) invalidar;
  final http.Client _http;

  RespaldoDrive({required this.token, required this.invalidar, http.Client? cliente})
      : _http = cliente ?? http.Client();

  static const nombreArchivo = 'respaldo.json';
  static const _formato = 1;
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _subida = 'https://www.googleapis.com/upload/drive/v3/files';

  /// El último token que funcionó; se pide de nuevo si Drive lo rechaza.
  String? _tokenActual;

  @override
  Future<bool> tieneAcceso({required bool interactivo}) async {
    _tokenActual = await token(interactivo: interactivo);
    return _tokenActual != null;
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>?> descargar() async {
    final id = await _buscarArchivo();
    if (id == null) return null;
    final r = await _pedir((h) => _http.get(Uri.parse('$_api/$id?alt=media'), headers: h));
    final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final colecciones = (json['colecciones'] as Map<String, dynamic>?) ?? {};
    return {
      for (final e in colecciones.entries) e.key: (e.value as List<dynamic>).cast<Map<String, dynamic>>(),
    };
  }

  @override
  Future<void> subir(Map<String, List<Map<String, dynamic>>> colecciones) async {
    final contenido = jsonEncode({
      'formato': _formato,
      'actualizado': DateTime.now().toUtc().toIso8601String(),
      'colecciones': colecciones,
    });
    final id = await _buscarArchivo();
    if (id != null) {
      await _pedir((h) => _http.patch(
            Uri.parse('$_subida/$id?uploadType=media'),
            headers: {...h, 'Content-Type': 'application/json; charset=utf-8'},
            body: utf8.encode(contenido),
          ));
      return;
    }
    const frontera = 'respaldo-mavfin';
    final metadatos = jsonEncode({
      'name': nombreArchivo,
      'parents': ['appDataFolder'],
    });
    final cuerpo = '--$frontera\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadatos\r\n'
        '--$frontera\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$contenido\r\n'
        '--$frontera--';
    await _pedir((h) => _http.post(
          Uri.parse('$_subida?uploadType=multipart'),
          headers: {...h, 'Content-Type': 'multipart/related; boundary=$frontera'},
          body: utf8.encode(cuerpo),
        ));
  }

  @override
  Future<void> borrar() async {
    // Si dos dispositivos crearon el archivo a la vez puede haber más de
    // uno: se borran todos.
    for (final id in await _listarArchivos()) {
      await _pedir((h) => _http.delete(Uri.parse('$_api/$id'), headers: h), aceptar404: true);
    }
  }

  Future<String?> _buscarArchivo() async {
    final ids = await _listarArchivos();
    return ids.isEmpty ? null : ids.first;
  }

  /// Ids de `respaldo.json` en la carpeta de la app, el más reciente primero.
  Future<List<String>> _listarArchivos() async {
    final uri = Uri.parse(_api).replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "name = '$nombreArchivo' and trashed = false",
      'fields': 'files(id)',
      'orderBy': 'modifiedTime desc',
      'pageSize': '10',
    });
    final r = await _pedir((h) => _http.get(uri, headers: h));
    final archivos = (jsonDecode(r.body) as Map<String, dynamic>)['files'] as List<dynamic>? ?? [];
    return [for (final a in archivos) (a as Map<String, dynamic>)['id'] as String];
  }

  /// Hace la petición con el token; si Drive lo rechaza (401), lo invalida
  /// y reintenta una vez con uno nuevo, sin mostrar ventanas.
  Future<http.Response> _pedir(
    Future<http.Response> Function(Map<String, String> encabezados) peticion, {
    bool aceptar404 = false,
  }) async {
    for (var intento = 0; intento < 2; intento++) {
      final vigente = _tokenActual ?? await token(interactivo: false);
      if (vigente == null) throw const ErrorDrive(401, 'Sin permiso para Google Drive.');
      _tokenActual = vigente;
      final r = await peticion({'Authorization': 'Bearer $vigente'});
      if (r.statusCode == 401 && intento == 0) {
        _tokenActual = null;
        await invalidar(vigente);
        continue;
      }
      if (r.statusCode >= 200 && r.statusCode < 300) return r;
      if (aceptar404 && r.statusCode == 404) return r;
      throw ErrorDrive(r.statusCode, r.body);
    }
    throw const ErrorDrive(401, 'Google Drive rechazó el permiso.');
  }
}

/// Drive respondió con un error.
final class ErrorDrive implements Exception {
  final int codigo;
  final String detalle;

  const ErrorDrive(this.codigo, this.detalle);

  @override
  String toString() => 'ErrorDrive($codigo): $detalle';
}
