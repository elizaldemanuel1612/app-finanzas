import 'package:app_finanzas/domain/importacion/mapeo_columnas.dart';
import 'package:test/test.dart';

void main() {
  test('detecta las cinco columnas por su nombre exacto', () {
    final mapeo = detectarColumnas(
      ['Fecha', 'Categoría', 'Descripción', 'Monto', 'Medio de pago'],
    );
    expect(mapeo[CampoImportado.fecha], 0);
    expect(mapeo[CampoImportado.categoria], 1);
    expect(mapeo[CampoImportado.descripcion], 2);
    expect(mapeo[CampoImportado.monto], 3);
    expect(mapeo[CampoImportado.medio], 4);
    expect(mapeo.esImportable, isTrue);
  });

  test('detecta alias en cualquier orden, mayúsculas y acentos', () {
    final mapeo = detectarColumnas(['IMPORTE', 'fec', 'rubro', 'concepto', 'forma de pago']);
    expect(mapeo[CampoImportado.monto], 0);
    expect(mapeo[CampoImportado.fecha], 1);
    expect(mapeo[CampoImportado.categoria], 2);
    expect(mapeo[CampoImportado.descripcion], 3);
    expect(mapeo[CampoImportado.medio], 4);
  });

  test('sin columna de fecha, no es importable aunque haya monto', () {
    final mapeo = detectarColumnas(['total', 'concepto']);
    expect(mapeo[CampoImportado.fecha], isNull);
    expect(mapeo.esImportable, isFalse);
  });

  test('sin columna de monto, no es importable aunque haya fecha', () {
    final mapeo = detectarColumnas(['fecha', 'concepto']);
    expect(mapeo[CampoImportado.monto], isNull);
    expect(mapeo.esImportable, isFalse);
  });

  test('categoría, descripción y medio son opcionales', () {
    final mapeo = detectarColumnas(['fecha', 'total']);
    expect(mapeo.esImportable, isTrue);
    expect(mapeo[CampoImportado.categoria], isNull);
    expect(mapeo[CampoImportado.descripcion], isNull);
    expect(mapeo[CampoImportado.medio], isNull);
  });

  test('encabezados sin ningún alias no matchean nada', () {
    final mapeo = detectarColumnas(['columna x', 'columna y']);
    expect(mapeo.indicePorCampo, isEmpty);
  });

  test('si dos columnas calzan con el mismo campo, gana la primera', () {
    final mapeo = detectarColumnas(['fecha', 'date']);
    expect(mapeo[CampoImportado.fecha], 0);
  });
}
