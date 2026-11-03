import 'dart:convert';

import 'package:app_finanzas/data/seguridad/autenticacion_reciente.dart';
import 'package:test/test.dart';

String _token(Map<String, dynamic> carga) {
  String parte(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${parte({'alg': 'RS256'})}.${parte(carga)}.firma';
}

void main() {
  final ahora = DateTime(2026, 11, 2, 12);
  int segundos(DateTime f) => f.millisecondsSinceEpoch ~/ 1000;

  test('contraseña escrita hace un minuto: se acepta', () {
    final token = _token({'auth_time': segundos(ahora.subtract(const Duration(minutes: 1)))});
    expect(verificarAutenticacionReciente(idToken: token, ahora: ahora), isNull);
  });

  test('sesión abierta de hace días: se rechaza', () {
    final token = _token({'auth_time': segundos(ahora.subtract(const Duration(days: 3)))});
    expect(verificarAutenticacionReciente(idToken: token, ahora: ahora), MotivoNoReciente.sesionAbierta);
  });

  test('reloj del teléfono atrasado de más: se rechaza', () {
    final token = _token({'auth_time': segundos(ahora.add(const Duration(minutes: 10)))});
    expect(verificarAutenticacionReciente(idToken: token, ahora: ahora), MotivoNoReciente.sesionAbierta);
  });

  test('sin auth_time, sin token o token roto: no se puede saber, se rechaza', () {
    for (final token in [
      _token({'sub': 'x'}),
      _token({'auth_time': 'ayer'}),
      null,
      'no.es.jwt!',
      'dos.partes',
    ]) {
      expect(verificarAutenticacionReciente(idToken: token, ahora: ahora), MotivoNoReciente.sinHora, reason: '$token');
    }
  });
}
