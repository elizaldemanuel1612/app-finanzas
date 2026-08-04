import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/rollups/rollup.dart';
import 'package:test/test.dart';

Rollup _rollup({Dinero? presupuesto = const Dinero.pesos(8000), Dinero? total}) =>
    Rollup(
      categoriaId: 'super',
      cicloId: '2026-07',
      totalCentavos: total ?? const Dinero.pesos(4000),
      conteoMovimientos: 3,
      presupuestoCentavos: presupuesto,
      ultimaActualizacion: DateTime(2026, 7, 30),
    );

void main() {
  test('porcentajeUsado calcula la fracción correcta', () {
    expect(_rollup().porcentajeUsado, 0.5);
  });

  test('porcentajeUsado es null sin presupuesto', () {
    expect(_rollup(presupuesto: null).porcentajeUsado, isNull);
  });

  test('porcentajeUsado es null con presupuesto cero (evita división entre cero)', () {
    expect(_rollup(presupuesto: const Dinero.cero()).porcentajeUsado, isNull);
  });

  test('porcentajeUsado puede pasar de 1.0 (sobregasto)', () {
    expect(_rollup(total: const Dinero.pesos(9000)).porcentajeUsado, 9000 / 8000);
  });

  test('igualdad estructural', () {
    expect(_rollup(), _rollup());
    expect(_rollup().hashCode, _rollup().hashCode);
  });

  test('toString incluye categoría, ciclo y total', () {
    final texto = _rollup().toString();
    expect(texto, contains('super'));
    expect(texto, contains('2026-07'));
  });
}
