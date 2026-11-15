import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/corte_pareto.dart';
import 'package:test/test.dart';

List<Dinero> _pesos(List<int> p) => [for (final x in p) Dinero.pesos(x)];

void main() {
  test('las primeras que juntas llegan al 80 %', () {
    // 8000+8000+5000+3800+3000+3000 = 30800 de 37950 → 81 %.
    final c = calcularCortePareto(_pesos([8000, 8000, 5000, 3800, 3000, 3000, 2200, 1500, 1450, 1000, 1000]))!;
    expect(c.cuantas, 6);
    expect(c.porcentaje, 81);
  });

  test('justo en el 80 % cuenta como llegar', () {
    final c = calcularCortePareto(_pesos([80, 10, 10]))!;
    expect(c.cuantas, 1);
    expect(c.porcentaje, 80);
  });

  test('sin línea: sin total, sin categorías o si hacen falta todas', () {
    expect(calcularCortePareto(const []), isNull);
    expect(calcularCortePareto(_pesos([0, 0])), isNull);
    expect(calcularCortePareto(_pesos([5000])), isNull);
    expect(calcularCortePareto(_pesos([50, 50])), isNull);
  });
}
