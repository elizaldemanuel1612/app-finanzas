import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/presupuesto/disponible_por_dia.dart';
import 'package:test/test.dart';

/// Ciclo del 12 oct al 11 nov (inclusive), como el de un corte el día 12.
final _ciclo = Ciclo(
  id: '2026-10',
  fechaInicio: DateTime(2026, 10, 12),
  fechaFin: DateTime(2026, 11, 11),
  etiqueta: 'Oct',
  estado: EstadoCiclo.abierto,
);

void main() {
  test('reparte lo que queda entre los días que faltan, contando hoy', () {
    // 24 oct → faltan 18 días después de hoy → 19 días contando hoy.
    final disponible = calcularDisponiblePorDia(
      presupuestoVariables: const Dinero.pesos(15800),
      gastadoVariables: const Dinero.pesos(65),
      ciclo: _ciclo,
      hoy: DateTime(2026, 10, 24, 19, 30),
    );
    // (15,800 − 65) / 19 = 828.157… → 828.15 (hacia abajo al centavo).
    expect(disponible, const Dinero(82815));
  });

  test('el último día del ciclo, todo lo que queda es para hoy', () {
    final disponible = calcularDisponiblePorDia(
      presupuestoVariables: const Dinero.pesos(1000),
      gastadoVariables: const Dinero.pesos(400),
      ciclo: _ciclo,
      hoy: DateTime(2026, 11, 11),
    );
    expect(disponible, const Dinero.pesos(600));
  });

  test('si ya se gastó todo el presupuesto, queda cero', () {
    final disponible = calcularDisponiblePorDia(
      presupuestoVariables: const Dinero.pesos(1000),
      gastadoVariables: const Dinero.pesos(1000),
      ciclo: _ciclo,
      hoy: DateTime(2026, 10, 24),
    );
    expect(disponible, const Dinero.cero());
  });

  test('si ya se pasó del presupuesto, queda cero y nunca negativo', () {
    final disponible = calcularDisponiblePorDia(
      presupuestoVariables: const Dinero.pesos(1000),
      gastadoVariables: const Dinero.pesos(1500),
      ciclo: _ciclo,
      hoy: DateTime(2026, 10, 24),
    );
    expect(disponible, const Dinero.cero());
  });

  test('después del fin del ciclo cuenta como un solo día', () {
    final disponible = calcularDisponiblePorDia(
      presupuestoVariables: const Dinero.pesos(300),
      gastadoVariables: const Dinero.cero(),
      ciclo: _ciclo,
      hoy: DateTime(2026, 11, 20),
    );
    expect(disponible, const Dinero.pesos(300));
  });
}
