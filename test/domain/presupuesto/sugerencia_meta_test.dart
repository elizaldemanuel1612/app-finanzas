import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/presupuesto/sugerencia_meta.dart';
import 'package:test/test.dart';

void main() {
  test('sin fijas declaradas (arranque en frío), sugiere 10%', () {
    final s = sugerirPorcentaje(
      ingresoBase: const Dinero.pesos(87000),
      totalFijas: const Dinero.cero(),
    );
    expect(s.porcentaje, 10);
    expect(s.motivo, MotivoSugerencia.arranqueEnFrio);
  });

  test('caso del mockup: ingreso 87,000 y fijas 15,700 sugiere 40%', () {
    final s = sugerirPorcentaje(
      ingresoBase: const Dinero.pesos(87000),
      totalFijas: const Dinero.pesos(15700),
    );
    expect(s.porcentaje, 40);
    expect(s.motivo, MotivoSugerencia.margenLibre);
  });

  test('el escalón que empata justo con el techo también cuenta como que cabe', () {
    // margen libre = 1000-600 = 400; mitad = 200; 20% de 1000 = 200 exacto.
    final s = sugerirPorcentaje(
      ingresoBase: const Dinero.pesos(1000),
      totalFijas: const Dinero.pesos(600),
    );
    expect(s.porcentaje, 20);
    expect(s.motivo, MotivoSugerencia.margenLibre);
  });

  test('margen tan estrecho que ni el escalón más bajo cabe, cae a 5%', () {
    final s = sugerirPorcentaje(
      ingresoBase: const Dinero.pesos(1000),
      totalFijas: const Dinero.pesos(990),
    );
    expect(s.porcentaje, 5);
    expect(s.motivo, MotivoSugerencia.margenEstrecho);
  });

  test('fijas que exceden el ingreso también caen a 5% sin tronar', () {
    final s = sugerirPorcentaje(
      ingresoBase: const Dinero.pesos(1000),
      totalFijas: const Dinero.pesos(1200),
    );
    expect(s.porcentaje, 5);
    expect(s.motivo, MotivoSugerencia.margenEstrecho);
  });

  test('toString describe la sugerencia', () {
    final s = sugerirPorcentaje(
      ingresoBase: const Dinero.pesos(87000),
      totalFijas: const Dinero.cero(),
    );
    expect(s.toString(), contains('SugerenciaMeta'));
  });
}
