import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/reparto_ingreso.dart';
import 'package:app_finanzas/domain/analisis/reporte_analisis.dart';
import 'package:test/test.dart';

ReporteAnalisis _reporte({
  required int gastadoFijas,
  required int presupuestoFijas,
  required int gastadoVariables,
  required int proyeccion,
}) {
  final ciclo = const CalculadoraCiclo(1).calcularPara(DateTime(2026, 8, 10));
  return ReporteAnalisis(
    ciclo: ciclo,
    diaDelCiclo: 10,
    diasDelCiclo: 31,
    gastado: Dinero.pesos(gastadoFijas + gastadoVariables),
    gastadoVariables: Dinero.pesos(gastadoVariables),
    gastadoFijas: Dinero.pesos(gastadoFijas),
    presupuestoVariables: const Dinero.pesos(5000),
    presupuestoFijas: Dinero.pesos(presupuestoFijas),
    promedioDiarioVariables: const Dinero.cero(),
    proyeccionVariables: Dinero.pesos(proyeccion),
    porCategoria: const [],
    acumuladoVariablesPorDia: const [],
    variablesAnteriorMismoDia: null,
    contraAnterior: const [],
    ultimosCiclos: const [],
    promedioPorDiaSemana: const [],
    diasConDatos: 0,
    dondeMasGastas: const [],
    conTarjeta: const Dinero.cero(),
    enEfectivo: const Dinero.cero(),
    gastosPequenos: 0,
    totalGastosPequenos: const Dinero.cero(),
  );
}

void main() {
  test('hasta hoy y al cierre: fijas completas y variables a su proyección', () {
    final r = calcularRepartoIngreso(
      reporte: _reporte(gastadoFijas: 4000, presupuestoFijas: 6000, gastadoVariables: 1000, proyeccion: 3100),
      ingreso: const Dinero.pesos(20000),
    );
    expect(r.hoy.fijas, const Dinero.pesos(4000));
    expect(r.hoy.variables, const Dinero.pesos(1000));
    expect(r.hoy.sobra, const Dinero.pesos(15000));
    expect(r.hoy.porcentaje(r.hoy.sobra), 75);
    expect(r.alCierre.fijas, const Dinero.pesos(6000));
    expect(r.alCierre.variables, const Dinero.pesos(3100));
    expect(r.alCierre.gastos, const Dinero.pesos(9100));
    expect(r.alCierre.porcentaje(r.alCierre.fijas), 30);
  });

  test('si ya se pagó más de lo planeado en fijas, cuenta lo pagado', () {
    final r = calcularRepartoIngreso(
      reporte: _reporte(gastadoFijas: 7000, presupuestoFijas: 6000, gastadoVariables: 3000, proyeccion: 2000),
      ingreso: const Dinero.pesos(8000),
    );
    expect(r.alCierre.fijas, const Dinero.pesos(7000));
    expect(r.alCierre.variables, const Dinero.pesos(3000));
    expect(r.alCierre.sobra, const Dinero.pesos(-2000));
  });

  test('sin ingreso, los porcentajes son cero', () {
    final r = calcularRepartoIngreso(
      reporte: _reporte(gastadoFijas: 1, presupuestoFijas: 1, gastadoVariables: 1, proyeccion: 1),
      ingreso: const Dinero.cero(),
    );
    expect(r.hoy.porcentaje(r.hoy.fijas), 0);
  });
}
