import 'package:app_finanzas/domain/importacion/csv.dart';
import 'package:test/test.dart';

void main() {
  test('CSV simple sin comillas', () {
    expect(leerCsv('a,b,c\n1,2,3\n'), [
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  test('archivo vacío no produce renglones', () {
    expect(leerCsv(''), <List<String>>[]);
  });

  test('tolera CRLF igual que LF', () {
    expect(leerCsv('a,b\r\nc,d\r\n'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
  });

  test('última línea sin salto final se lee igual', () {
    expect(leerCsv('a,b\nc,d'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
  });

  test('sin salto final no agrega un renglón fantasma', () {
    expect(leerCsv('a,b\nc,d\n'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
  });

  test('quita el BOM UTF-8 inicial', () {
    expect(leerCsv('﻿a,b\n1,2\n'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  test('campo entre comillas con coma embebida', () {
    expect(leerCsv('a,"1,234.56",c\n'), [
      ['a', '1,234.56', 'c'],
    ]);
  });

  test('campo entre comillas con salto de línea embebido', () {
    expect(leerCsv('"linea1\nlinea2",b\n'), [
      ['linea1\nlinea2', 'b'],
    ]);
  });

  test('comillas dobles dentro de un campo entre comillas son una comilla literal', () {
    expect(leerCsv('"dijo ""hola""",b\n'), [
      ['dijo "hola"', 'b'],
    ]);
  });

  test('campo vacío al final de un renglón', () {
    expect(leerCsv('a,b,\n'), [
      ['a', 'b', ''],
    ]);
  });

  test('renglón en blanco produce un campo vacío', () {
    expect(leerCsv('a,b\n\nc,d\n'), [
      ['a', 'b'],
      [''],
      ['c', 'd'],
    ]);
  });
}
