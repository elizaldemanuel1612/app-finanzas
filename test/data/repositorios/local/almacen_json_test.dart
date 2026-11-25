import 'dart:io';

import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_json.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('leer un archivo que no existe regresa lista vacía', () async {
    final almacen = AlmacenJsonLista(File('${temp.path}/no_existe.json'));
    expect(await almacen.leer(), isEmpty);
  });

  test('escribir y volver a leer regresa los mismos datos', () async {
    final almacen = AlmacenJsonLista(File('${temp.path}/datos.json'));
    await almacen.escribir([
      {'a': 1},
      {'b': 2},
    ]);
    final leido = await almacen.leer();
    expect(leido, [
      {'a': 1},
      {'b': 2},
    ]);
  });

  test('escribir crea las carpetas intermedias si no existen', () async {
    final almacen = AlmacenJsonLista(File('${temp.path}/sub/carpeta/datos.json'));
    await almacen.escribir([
      {'x': 1},
    ]);
    expect(await File('${temp.path}/sub/carpeta/datos.json').exists(), isTrue);
  });

  test('escribir dos veces sobreescribe, no acumula', () async {
    final almacen = AlmacenJsonLista(File('${temp.path}/datos.json'));
    await almacen.escribir([
      {'a': 1},
    ]);
    await almacen.escribir([
      {'b': 2},
    ]);
    expect(await almacen.leer(), [
      {'b': 2},
    ]);
  });

  test('un archivo vacío se trata como lista vacía', () async {
    final archivo = File('${temp.path}/vacio.json');
    await archivo.create(recursive: true);
    final almacen = AlmacenJsonLista(archivo);
    expect(await almacen.leer(), isEmpty);
  });

  test('no queda un .tmp huérfano después de escribir', () async {
    final almacen = AlmacenJsonLista(File('${temp.path}/datos.json'));
    await almacen.escribir([
      {'a': 1},
    ]);
    expect(await File('${temp.path}/datos.json.tmp').exists(), isFalse);
  });

  group('lo ya decodificado (2026-11-25)', () {
    test('cada lectura da una lista nueva: modificarla no cambia la siguiente', () async {
      final almacen = AlmacenJsonLista.sobre(ArchivoTextoMemoria('[{"a":1}]'));
      final primera = await almacen.leer();
      primera.add({'a': 2});
      expect(await almacen.leer(), [
        {'a': 1},
      ]);
    });

    test('si el archivo cambió por fuera (Siri, otra pestaña), se vuelve a leer', () async {
      final archivo = ArchivoTextoMemoria('[{"a":1}]');
      final almacen = AlmacenJsonLista.sobre(archivo);
      await almacen.leer();
      await archivo.escribir('[{"a":3}]');
      expect(await almacen.leer(), [
        {'a': 3},
      ]);
    });

    test('lo recién escrito se lee igual', () async {
      final almacen = AlmacenJsonLista.sobre(ArchivoTextoMemoria());
      final items = [
        {'a': 1},
      ];
      await almacen.escribir(items);
      items.add({'a': 2});
      expect(await almacen.leer(), [
        {'a': 1},
      ]);
    });
  });
}
