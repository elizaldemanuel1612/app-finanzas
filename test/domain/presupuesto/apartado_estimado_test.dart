import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/presupuesto/apartado_estimado.dart';
import 'package:test/test.dart';

Dinero _estimado({
  int ingreso = 20000,
  int presupuestoFijas = 5400,
  int gastadoFijas = 0,
  int presupuestoVariables = 12600,
  int gastadoVariables = 0,
  int dia = 1,
  int dias = 30,
}) =>
    calcularApartadoEstimado(
      ingreso: Dinero.pesos(ingreso),
      presupuestoFijas: Dinero.pesos(presupuestoFijas),
      gastadoFijas: Dinero.pesos(gastadoFijas),
      presupuestoVariables: Dinero.pesos(presupuestoVariables),
      gastadoVariables: Dinero.pesos(gastadoVariables),
      diaDelCiclo: dia,
      diasDelCiclo: dias,
    );

void main() {
  test('el día 1 sin gastos no promete de más: asume lo planeado', () {
    expect(_estimado(), const Dinero.pesos(2000));
  });

  test('gastar más rápido que lo planeado baja el estimado', () {
    // Día 10 de 30 con 6,000 → proyecta 18,000 en variables.
    expect(_estimado(gastadoVariables: 6000, dia: 10), const Dinero.pesos(-3400));
  });

  test('gastar menos que lo planeado no sube el estimado antes de tiempo', () {
    expect(_estimado(gastadoVariables: 1000, dia: 15), const Dinero.pesos(2000));
  });

  test('fijas pagadas de más cuentan completas', () {
    expect(_estimado(gastadoFijas: 6000), const Dinero.pesos(1400));
  });

  test('día fuera de rango no divide entre cero ni proyecta hacia atrás', () {
    expect(_estimado(gastadoVariables: 13000, dia: 0), _estimado(gastadoVariables: 13000, dia: 1));
    expect(_estimado(gastadoVariables: 13000, dia: 31, dias: 30), const Dinero.pesos(1600));
  });
}
