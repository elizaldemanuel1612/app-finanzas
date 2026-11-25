import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_del_ciclo.dart';
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

  test('desde los datos: ingreso − fijas − el mayor entre presupuesto y cierre estimado (2026-11-25)', () {
    final ciclo = CalculadoraCiclo(1).calcularPara(DateTime(2026, 11, 15));
    var n = 0;
    Movimiento mov(String cat, int pesos, {String cicloId = '2026-11', EstadoMovimiento estado = EstadoMovimiento.activo}) =>
        Movimiento(
          clientId: 'm${n++}',
          fecha: DateTime(2026, 11, 3),
          cicloId: cicloId,
          periodoNatural: '2026-11',
          monto: Dinero.pesos(pesos),
          categoriaId: cat,
          medio: MedioPago.tarjeta,
          descripcion: 'x',
          estado: estado,
          origenCaptura: OrigenCaptura.manual,
        );
    const renta = CategoriaFija(
      id: 'renta', nombre: 'Renta', emoji: '🏠', activa: true, esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(5000), diaDelCiclo: 1,
    );
    const vieja = CategoriaFija(
      id: 'vieja', nombre: 'Vieja', emoji: '🏠', activa: false, esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(999), diaDelCiclo: 1,
    );
    const superm = CategoriaVariable(
      id: 'super', nombre: 'Súper', emoji: '🛒', activa: true, esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(3000),
    );
    final categorias = <Categoria>[renta, vieja, superm];
    final movimientos = [
      mov('renta', 5200),
      mov('renta', 999, estado: EstadoMovimiento.anulado),
      mov('renta', 999, cicloId: '2026-10'),
      mov('super', 2500),
    ];
    final hoy = DateTime(2026, 11, 15);
    final proyeccion = proyeccionTotal(estadosDeVariables(categorias: categorias, movimientos: movimientos, ciclo: ciclo, hoy: hoy));
    final variables = proyeccion > const Dinero.pesos(3000) ? proyeccion : const Dinero.pesos(3000);
    expect(
      estimarApartadoAlCierre(categorias: categorias, movimientos: movimientos, ciclo: ciclo, ingreso: const Dinero.pesos(20000), hoy: hoy),
      const Dinero.pesos(20000 - 5200) - variables,
    );
    expect(variables > const Dinero.pesos(2500), isTrue, reason: 'no supone que ya no se gasta nada');
  });
}
