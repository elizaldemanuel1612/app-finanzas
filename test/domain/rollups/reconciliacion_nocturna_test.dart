import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/rollups/reconciliacion_nocturna.dart';
import 'package:app_finanzas/domain/rollups/rollup.dart';
import 'package:test/test.dart';

Rollup _rollup(String categoriaId, int pesos) => Rollup(
      categoriaId: categoriaId,
      cicloId: '2026-07',
      totalCentavos: Dinero.pesos(pesos),
      conteoMovimientos: 1,
      presupuestoCentavos: const Dinero.pesos(8000),
      ultimaActualizacion: DateTime(2026, 7, 30),
    );

void main() {
  test('sin diferencias cuando guardado y recalculado coinciden', () {
    final diffs = encontrarDesfaseRollups(
      guardados: [_rollup('super', 300)],
      recalculados: [_rollup('super', 300)],
    );
    expect(diffs, isEmpty);
  });

  test('detecta cuando el rollup guardado quedó desactualizado', () {
    final diffs = encontrarDesfaseRollups(
      guardados: [_rollup('super', 300)],
      recalculados: [_rollup('super', 500)],
    );
    expect(diffs, hasLength(1));
    expect(diffs.single.totalGuardado, const Dinero.pesos(300));
    expect(diffs.single.totalRecalculado, const Dinero.pesos(500));
    expect(diffs.single.diferencia, const Dinero.pesos(200));
  });

  test('una categoría recalculada sin rollup guardado también se reporta', () {
    final diffs = encontrarDesfaseRollups(
      guardados: const [],
      recalculados: [_rollup('super', 300)],
    );
    expect(diffs, hasLength(1));
    expect(diffs.single.totalGuardado, const Dinero.cero());
  });

  test('un rollup guardado que ya no aparece al recalcular también se reporta', () {
    final diffs = encontrarDesfaseRollups(
      guardados: [_rollup('categoria_borrada', 300)],
      recalculados: const [],
    );
    expect(diffs, hasLength(1));
    expect(diffs.single.totalRecalculado, const Dinero.cero());
  });

  test('varias categorías se comparan independientemente', () {
    final diffs = encontrarDesfaseRollups(
      guardados: [_rollup('super', 300), _rollup('auto', 150)],
      recalculados: [_rollup('super', 300), _rollup('auto', 200)],
    );
    expect(diffs, hasLength(1));
    expect(diffs.single.categoriaId, 'auto');
  });

  test('DiferenciaRollup.toString describe el desfase', () {
    final diffs = encontrarDesfaseRollups(
      guardados: [_rollup('super', 300)],
      recalculados: [_rollup('super', 500)],
    );
    final texto = diffs.single.toString();
    expect(texto, contains('super'));
    expect(texto, contains(r'$300.00'));
    expect(texto, contains(r'$500.00'));
  });
}
