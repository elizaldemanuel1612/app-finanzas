import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/presupuesto/apartado_estimado.dart';
import 'package:test/test.dart';

Dinero _estimado({
  int ingreso = 20000,
  int presupuestoFijas = 5400,
  int gastadoFijas = 0,
  int presupuestoVariables = 12600,
  int proyeccionVariables = 0,
}) =>
    calcularApartadoEstimado(
      ingreso: Dinero.pesos(ingreso),
      presupuestoFijas: Dinero.pesos(presupuestoFijas),
      gastadoFijas: Dinero.pesos(gastadoFijas),
      presupuestoVariables: Dinero.pesos(presupuestoVariables),
      proyeccionVariables: Dinero.pesos(proyeccionVariables),
    );

void main() {
  test('sin pronóstico arriba del plan no promete de más: asume lo planeado', () {
    expect(_estimado(), const Dinero.pesos(2000));
    expect(_estimado(proyeccionVariables: 9000), const Dinero.pesos(2000));
  });

  test('un cierre estimado arriba del plan baja el estimado', () {
    expect(_estimado(proyeccionVariables: 18000), const Dinero.pesos(-3400));
  });

  test('fijas pagadas de más cuentan completas', () {
    expect(_estimado(gastadoFijas: 6000), const Dinero.pesos(1400));
  });
}
