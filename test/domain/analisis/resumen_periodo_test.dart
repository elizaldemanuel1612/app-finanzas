import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/resumen_periodo.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §5.7, "Periodo" (2026-11-15).

const _renta = CategoriaFija(
  id: 'renta',
  nombre: 'Renta',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: Dinero.pesos(5000),
  diaDelCiclo: 1,
);
const _super = CategoriaVariable(
  id: 'super',
  nombre: 'Súper',
  emoji: '🛒',
  activa: true,
  esNecesaria: false,
  presupuestoMensualCentavos: Dinero.pesos(4000),
);

var _n = 0;
Movimiento _mov(DateTime fecha, int pesos, String categoria, {EstadoMovimiento estado = EstadoMovimiento.activo}) =>
    Movimiento(
      clientId: 'm${_n++}',
      fecha: fecha,
      cicloId: 'c',
      periodoNatural: '${fecha.year}-${fecha.month}',
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: MedioPago.tarjeta,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

void main() {
  group('rangos', () {
    final hoy = DateTime(2026, 11, 15, 20);

    test('este año, últimos 12 meses y año pasado', () {
      expect(rangoEsteAnio(hoy), RangoFechas(DateTime(2026), DateTime(2026, 11, 15)));
      expect(rangoUltimos12Meses(hoy), RangoFechas(DateTime(2025, 11, 16), DateTime(2026, 11, 15)));
      expect(rangoAnioPasado(hoy), RangoFechas(DateTime(2025), DateTime(2025, 12, 31)));
      expect(rangoAnioPasado(hoy).dias, 365);
    });

    test('contiene los dos extremos y el año anterior ajusta el 29 de febrero', () {
      final r = RangoFechas(DateTime(2028, 2, 1), DateTime(2028, 2, 29, 23));
      expect(r.contiene(DateTime(2028, 2, 29, 22)), isTrue);
      expect(r.contiene(DateTime(2028, 3, 1)), isFalse);
      expect(r.anioAnterior(), RangoFechas(DateTime(2027, 2, 1), DateTime(2027, 2, 28)));
      expect(r.hashCode, RangoFechas(DateTime(2028, 2, 1), DateTime(2028, 2, 29)).hashCode);
    });
  });

  test('total, fijas y variables, meses, categorías y lo más alto', () {
    final movs = [
      _mov(DateTime(2026, 1, 3), 5000, 'renta'),
      _mov(DateTime(2026, 1, 10), 800, 'super'),
      _mov(DateTime(2026, 3, 2), 1200, 'super'),
      _mov(DateTime(2026, 3, 5), 999, 'super', estado: EstadoMovimiento.anulado),
      _mov(DateTime(2026, 3, 9), 100, 'borrada'), // categoría que ya no existe
      _mov(DateTime(2025, 12, 31), 700, 'super'), // fuera del rango
    ];
    final r = calcularResumenPeriodo(
      movimientos: movs,
      categorias: const [_renta, _super],
      rango: RangoFechas(DateTime(2026), DateTime(2026, 3, 31)),
    );
    expect(r.vacio, isFalse);
    expect(r.total, Dinero.pesos(7100));
    expect(r.fijas, Dinero.pesos(5000));
    expect(r.variables, Dinero.pesos(2000));
    expect(r.conteo, 4);
    // 7100 ÷ 90 días × 30.4375
    expect(r.promedioMensual, Dinero((710000 * 30.4375 / 90).round()));
    expect([for (final m in r.meses) (m.mes, m.total.centavos ~/ 100)], [(1, 5800), (2, 0), (3, 1300)]);
    expect(r.mesMasAlto!.mes, 1);
    expect(r.mayorGasto!.monto, Dinero.pesos(5000));
    expect([for (final c in r.categorias) (c.categoria.id, c.porcentaje, c.conteo)], [('renta', 70, 1), ('super', 28, 2)]);
    // Empezó a registrar el 31 dic 2025: no hay con qué comparar el año pasado.
    expect(r.totalAnioAnterior, isNull);
    expect(r.cambioContraAnioAnterior, isNull);
  });

  test('contra el año anterior solo si se registraba desde su primera semana', () {
    final rango = RangoFechas(DateTime(2026), DateTime(2026, 1, 31));
    final movs = [
      _mov(DateTime(2025, 1, 5), 1000, 'super'),
      _mov(DateTime(2025, 1, 20), 1000, 'super'),
      _mov(DateTime(2026, 1, 10), 2500, 'super'),
    ];
    final r = calcularResumenPeriodo(movimientos: movs, categorias: const [_super], rango: rango);
    expect(r.totalAnioAnterior, Dinero.pesos(2000));
    expect(r.cambioContraAnioAnterior, 25);

    final cero = calcularResumenPeriodo(
      movimientos: [_mov(DateTime(2024, 6, 1), 10, 'super'), _mov(DateTime(2026, 1, 2), 10, 'super')],
      categorias: const [_super],
      rango: rango,
    );
    expect(cero.totalAnioAnterior, const Dinero.cero());
    expect(cero.cambioContraAnioAnterior, isNull);

    final tarde = calcularResumenPeriodo(
      movimientos: [_mov(DateTime(2025, 1, 9), 10, 'super')],
      categorias: const [_super],
      rango: rango,
    );
    expect(tarde.totalAnioAnterior, isNull);
  });

  test('sin gastos y con más de 13 meses no hay barras ni mes más alto', () {
    final r = calcularResumenPeriodo(
      movimientos: const [],
      categorias: const [_super],
      rango: RangoFechas(DateTime(2024), DateTime(2026, 1, 31)),
    );
    expect(r.vacio, isTrue);
    expect(r.meses, isEmpty);
    expect(r.mesMasAlto, isNull);
    expect(r.mayorGasto, isNull);
    expect(r.promedioMensual, const Dinero.cero());
  });
}
