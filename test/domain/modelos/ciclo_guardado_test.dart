import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);
final _ciclo = _calculadora.calcularPara(DateTime(2026, 7, 15));

SnapshotCiclo _snapshot() => SnapshotCiclo(
      cicloId: _ciclo.id,
      fechaCierre: DateTime(2026, 8, 12),
      ingresoTotal: const Dinero.pesos(87000),
      metaApartado: const Dinero.pesos(34800),
      totalGastado: const Dinero.pesos(42674),
      renglones: const [],
    );

CicloGuardado _guardado() => CicloGuardado(ciclo: _ciclo, snapshot: _snapshot());

void main() {
  test('guarda ciclo y snapshot', () {
    final g = _guardado();
    expect(g.ciclo, _ciclo);
    expect(g.snapshot, _snapshot());
  });

  test('el snapshot es opcional (ciclo guardado sin cerrar todavía)', () {
    final g = CicloGuardado(ciclo: _ciclo);
    expect(g.snapshot, isNull);
  });

  test('igualdad y hashCode son consistentes entre dos instancias equivalentes', () {
    expect(_guardado(), _guardado());
    expect(_guardado().hashCode, _guardado().hashCode);
  });

  test('un snapshot distinto rompe la igualdad', () {
    expect(_guardado() == CicloGuardado(ciclo: _ciclo), isFalse);
  });

  test('ida y vuelta de JSON conserva ciclo y snapshot', () {
    final original = _guardado();
    final reconstruido = CicloGuardado.fromJson(original.toJson());
    expect(reconstruido, original);
  });

  test('ida y vuelta de JSON sin snapshot regresa snapshot null', () {
    final original = CicloGuardado(ciclo: _ciclo);
    final reconstruido = CicloGuardado.fromJson(original.toJson());
    expect(reconstruido.snapshot, isNull);
  });

  test('el ciclo cerrado se conserva a través del JSON', () {
    final cerrado = CicloGuardado(ciclo: _ciclo.cerrar().valorOLanza, snapshot: _snapshot());
    final reconstruido = CicloGuardado.fromJson(cerrado.toJson());
    expect(reconstruido.ciclo.estado, EstadoCiclo.cerrado);
  });
}
