import 'dart:convert';

import 'package:app_finanzas/data/nube/respaldo_drive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Un Drive falso: la carpeta de la app con sus archivos por id.
final class _DriveFalso {
  final archivos = <String, String>{};
  final peticiones = <http.Request>[];
  var siguienteId = 1;

  /// Tokens que Drive acepta.
  final validos = <String>{'t1'};

  late final cliente = MockClient((r) async {
    peticiones.add(r);
    final token = r.headers['Authorization']?.replaceFirst('Bearer ', '');
    if (!validos.contains(token)) return http.Response('{}', 401);
    final ruta = r.url.path;
    if (r.method == 'GET' && ruta == '/drive/v3/files') {
      expect(r.url.queryParameters['spaces'], 'appDataFolder');
      return http.Response(jsonEncode({'files': [for (final id in archivos.keys.toList().reversed) {'id': id}]}), 200);
    }
    if (r.method == 'GET' && ruta.startsWith('/drive/v3/files/')) {
      final id = ruta.split('/').last;
      return archivos.containsKey(id) ? http.Response.bytes(utf8.encode(archivos[id]!), 200) : http.Response('', 404);
    }
    if (r.method == 'POST' && ruta == '/upload/drive/v3/files') {
      final partes = r.body.split('--respaldo-mavfin');
      expect(partes[1], contains('"parents":["appDataFolder"]'));
      final contenido = partes[2].split('\r\n\r\n').last.trim();
      final id = 'f${siguienteId++}';
      archivos[id] = contenido;
      return http.Response(jsonEncode({'id': id}), 200);
    }
    if (r.method == 'PATCH' && ruta.startsWith('/upload/drive/v3/files/')) {
      archivos[ruta.split('/').last] = r.body;
      return http.Response('{}', 200);
    }
    if (r.method == 'DELETE') {
      return archivos.remove(ruta.split('/').last) == null ? http.Response('', 404) : http.Response('', 204);
    }
    return http.Response('no esperado', 500);
  });
}

void main() {
  late _DriveFalso drive;
  late List<String?> tokens;
  late List<String> invalidados;
  late RespaldoDrive respaldo;

  setUp(() {
    drive = _DriveFalso();
    tokens = ['t1'];
    invalidados = [];
    respaldo = RespaldoDrive(
      token: ({required interactivo}) async => tokens.isEmpty ? null : tokens.removeAt(0),
      invalidar: (t) async => invalidados.add(t),
      cliente: drive.cliente,
    );
  });

  test('sin respaldo, descargar devuelve null', () async {
    expect(await respaldo.tieneAcceso(interactivo: false), isTrue);
    expect(await respaldo.descargar(), isNull);
  });

  test('la primera subida crea el archivo en appDataFolder y la segunda lo reemplaza', () async {
    await respaldo.tieneAcceso(interactivo: true);
    await respaldo.subir({
      'movimientos.json': [
        {'clientId': 'm1', 'concepto': 'Café ☕'},
      ],
    });
    expect(drive.archivos, hasLength(1));
    expect((await respaldo.descargar())!['movimientos.json']!.single['concepto'], 'Café ☕');

    await respaldo.subir({'movimientos.json': []});
    expect(drive.archivos, hasLength(1));
    expect(drive.peticiones.where((p) => p.method == 'PATCH'), hasLength(1));
    expect((await respaldo.descargar())!['movimientos.json'], isEmpty);
    expect(jsonDecode(drive.archivos.values.single)['formato'], 1);
  });

  test('si Drive rechaza el token, lo invalida y reintenta con uno nuevo', () async {
    tokens = ['viejo', 't1'];
    await respaldo.tieneAcceso(interactivo: false);
    expect(await respaldo.descargar(), isNull);
    expect(invalidados, ['viejo']);
  });

  test('sin token no hay acceso ni peticiones', () async {
    tokens = [];
    expect(await respaldo.tieneAcceso(interactivo: false), isFalse);
    expect(() => respaldo.descargar(), throwsA(isA<ErrorDrive>().having((e) => e.codigo, 'codigo', 401)));
    expect(drive.peticiones, isEmpty);
  });

  test('dos rechazos seguidos son un error', () async {
    tokens = ['malo1', 'malo2'];
    await respaldo.tieneAcceso(interactivo: false);
    await expectLater(respaldo.descargar(), throwsA(isA<ErrorDrive>()));
    expect(ErrorDrive(401, 'x').toString(), contains('401'));
  });

  test('un error de Drive llega como ErrorDrive', () async {
    drive.archivos['roto'] = 'x';
    final conError = RespaldoDrive(
      token: ({required interactivo}) async => 't1',
      invalidar: (_) async {},
      cliente: MockClient((_) async => http.Response('cuota', 403)),
    );
    await expectLater(conError.descargar(), throwsA(isA<ErrorDrive>().having((e) => e.codigo, 'codigo', 403)));
  });

  test('borrar quita todas las copias, aunque haya más de una', () async {
    drive.archivos
      ..['a'] = '{}'
      ..['b'] = '{}';
    await respaldo.tieneAcceso(interactivo: true);
    await respaldo.borrar();
    expect(drive.archivos, isEmpty);
    await respaldo.borrar();
  });
}
