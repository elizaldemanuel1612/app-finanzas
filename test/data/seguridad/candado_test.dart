import 'dart:convert';

import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/seguridad/candado.dart';
import 'package:app_finanzas/domain/seguridad/politica_bloqueo.dart';
import 'package:test/test.dart';

void main() {
  late ArchivoTextoMemoria archivo;
  late DateTime ahora;
  late Candado candado;

  setUp(() {
    archivo = ArchivoTextoMemoria();
    ahora = DateTime(2026, 11, 2, 12);
    candado = Candado(archivo, reloj: () => ahora, iteraciones: 50);
  });

  test('sin nada guardado: sin PIN, método PIN y toca pedirlo', () async {
    final e = await candado.estado();
    expect(e.tienePin, isFalse);
    expect(e.tieneContrasena, isFalse);
    expect(e.metodo, MetodoDesbloqueo.pin);
    expect(e.tocaPin, isTrue);
    expect(e.esperarHasta, isNull);
    expect(e.requiereRecuperar, isFalse);
  });

  test('nunca guarda el PIN en claro, y lo reconoce', () async {
    await candado.definirPin('482915');
    expect(archivo.contenido, isNot(contains('482915')));
    expect(await candado.probarPin('482915'), isTrue);
    expect(await candado.probarPin('000001'), isFalse);
    expect((await candado.estado()).fallidos, 1);
  });

  test('dos PIN iguales dan huellas distintas (sal aleatoria)', () async {
    await candado.definirPin('482915');
    final primera = archivo.contenido;
    await candado.definirPin('482915');
    expect(archivo.contenido, isNot(primera));
  });

  test('el PIN se vuelve a pedir a la semana, y acertarlo reinicia la cuenta', () async {
    await candado.definirPin('482915');
    expect((await candado.estado()).tocaPin, isFalse);
    ahora = ahora.add(const Duration(days: 7));
    expect((await candado.estado()).tocaPin, isTrue);
    await candado.probarPin('482915');
    expect((await candado.estado()).tocaPin, isFalse);
  });

  test('contraseña y método', () async {
    await candado.definirContrasena('casa12');
    await candado.elegirMetodo(MetodoDesbloqueo.contrasena);
    final e = await candado.estado();
    expect(e.tieneContrasena, isTrue);
    expect(e.metodo, MetodoDesbloqueo.contrasena);
    expect(await candado.probarContrasena('casa12'), isTrue);
    expect(await candado.probarContrasena('casa13'), isFalse);
    // Acertar la contraseña no cuenta como haber usado el PIN.
    ahora = ahora.add(const Duration(days: 8));
    await candado.probarContrasena('casa12');
    expect((await candado.estado()).tocaPin, isTrue);
  });

  test('al quinto fallo espera; mientras espera ni el PIN correcto entra', () async {
    await candado.definirPin('482915');
    for (var i = 0; i < 5; i++) {
      await candado.probarPin('000001');
    }
    final e = await candado.estado();
    expect(e.esperarHasta, ahora.add(const Duration(seconds: 30)));
    expect(await candado.probarPin('482915'), isFalse);
    ahora = ahora.add(const Duration(seconds: 31));
    expect((await candado.estado()).esperarHasta, isNull);
    expect(await candado.probarPin('482915'), isTrue);
    expect((await candado.estado()).fallidos, 0);
  });

  test('al décimo fallo solo queda recuperar; reiniciar lo olvida todo', () async {
    await candado.definirPin('482915');
    for (var i = 0; i < 10; i++) {
      ahora = ahora.add(const Duration(hours: 2));
      await candado.probarPin('000001');
    }
    expect((await candado.estado()).requiereRecuperar, isTrue);
    ahora = ahora.add(const Duration(days: 1));
    expect(await candado.probarPin('482915'), isFalse);
    await candado.reiniciar();
    expect((await candado.estado()).tienePin, isFalse);
  });

  test('biometría y definir PIN limpian los fallos', () async {
    await candado.definirPin('482915');
    await candado.probarPin('000001');
    await candado.registrarBiometria();
    expect((await candado.estado()).fallidos, 0);
    await candado.probarPin('000001');
    await candado.definirPin('482916');
    expect((await candado.estado()).fallidos, 0);
  });

  test('sin PIN definido, probar falla sin romper', () async {
    expect(await candado.probarPin('482915'), isFalse);
  });

  test('un archivo dañado se toma como vacío', () async {
    archivo.contenido = 'no es json';
    expect((await candado.estado()).tienePin, isFalse);
    archivo.contenido = jsonEncode({'metodo': 'otro'});
    expect((await candado.estado()).metodo, MetodoDesbloqueo.pin);
  });

  test('PBKDF2-SHA256 da el vector conocido (RFC 7914 §11)', () {
    String hex(List<int> b) => [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
    expect(
      hex(pbkdf2Sha256('passwd', utf8.encode('salt'), 1)),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
    );
  });
}
