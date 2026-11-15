import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/reporte_ingresos.dart';
import 'package:app_finanzas/domain/analisis/resumen_periodo.dart';
import 'package:app_finanzas/domain/modelos/categoria_ingreso.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §7.3.4 (2026-11-15).

Cuenta _cuenta(String id, TipoCuenta tipo) => Cuenta(
      id: id,
      nombre: id,
      emoji: '💳',
      tipo: tipo,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026),
    );

var _n = 0;
MovimientoCuenta _abono(
  int pesos,
  DateTime fecha, {
  String cuenta = 'bbva',
  String? categoria,
  TipoMovimientoCuenta tipo = TipoMovimientoCuenta.abono,
  EstadoMovimientoCuenta estado = EstadoMovimientoCuenta.activo,
}) =>
    MovimientoCuenta(
      clientId: 'a${_n++}',
      cuentaId: cuenta,
      fecha: fecha,
      monto: Dinero.pesos(pesos),
      tipo: tipo,
      entra: true,
      estado: estado,
      categoriaIngresoId: categoria,
      cuentaDestinoId: tipo == TipoMovimientoCuenta.transferencia ? 'cetes' : null,
    );

Movimiento _gasto(int pesos, DateTime fecha, {EstadoMovimiento estado = EstadoMovimiento.activo, String? cuenta}) =>
    Movimiento(
      clientId: 'g${_n++}',
      fecha: fecha,
      cicloId: 'c',
      periodoNatural: '2026-11',
      monto: Dinero.pesos(pesos),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuenta,
    );

void main() {
  final cuentas = [_cuenta('bbva', TipoCuenta.debito), _cuenta('cetes', TipoCuenta.ahorro), _cuenta('oro', TipoCuenta.credito)];
  const categorias = categoriasIngresoSugeridas;
  final rango = RangoFechas(DateTime(2026, 10), DateTime(2026, 11, 30));

  test('suma solo abonos activos a cuentas que no son de crédito, por categoría, cuenta y mes', () {
    final r = calcularReporteIngresos(
      movimientosCuenta: [
        _abono(30000, DateTime(2026, 10, 15), categoria: 'ing-nomina'),
        _abono(30000, DateTime(2026, 11, 15), categoria: 'ing-nomina'),
        _abono(8000, DateTime(2026, 11, 3), categoria: 'ing-rentas', cuenta: 'cetes'),
        _abono(2000, DateTime(2026, 11, 20)), // sin categoría
        _abono(500, DateTime(2026, 11, 21), categoria: 'ya-no-existe'), // también sin categoría
        _abono(999, DateTime(2026, 11, 5), cuenta: 'oro'), // crédito: baja deuda
        _abono(999, DateTime(2026, 11, 5), cuenta: 'borrada'),
        _abono(999, DateTime(2026, 11, 5), estado: EstadoMovimientoCuenta.anulado),
        _abono(999, DateTime(2026, 11, 5), tipo: TipoMovimientoCuenta.transferencia),
        _abono(999, DateTime(2026, 11, 5), tipo: TipoMovimientoCuenta.ajuste),
        _abono(999, DateTime(2026, 9, 30), categoria: 'ing-nomina'), // fuera del rango
      ],
      categorias: categorias,
      cuentas: cuentas,
      gastos: [
        _gasto(40000, DateTime(2026, 11, 2)),
        _gasto(5000, DateTime(2026, 11, 2), estado: EstadoMovimiento.anulado),
        _gasto(5000, DateTime(2026, 12, 1)),
      ],
      rango: rango,
    );
    expect(r.vacio, isFalse);
    expect(r.total, Dinero.pesos(70500));
    expect(r.conteo, 5);
    expect(r.promedioMensual, Dinero((7050000 * 30.4375 / 61).round()));
    expect(
      [for (final c in r.porCategoria) (c.categoria?.nombre, c.total.centavos ~/ 100, c.porcentaje, c.conteo)],
      [('Nómina', 60000, 85, 2), ('Rentas', 8000, 11, 1), (null, 2500, 4, 2)],
    );
    expect([for (final c in r.porCuenta) (c.cuenta.id, c.porcentaje)], [('bbva', 89), ('cetes', 11)]);
    expect([for (final m in r.meses) (m.mes, m.total.centavos ~/ 100)], [(10, 30000), (11, 40500)]);
    expect(r.mesMasAlto!.mes, 11);
    expect(r.mayor!.monto, Dinero.pesos(30000));
    expect(r.gastado, Dinero.pesos(40000));
    expect(r.quedo, Dinero.pesos(30500));
    expect(r.porcentajeGastado, 57);
    expect(r.fuenteDominante!.categoria!.id, 'ing-nomina');
  });

  test('filtro por cuenta: solo sus abonos y lo gastado con ellas; vacío = todas', () {
    ReporteIngresos con(Set<String>? solo) => calcularReporteIngresos(
          movimientosCuenta: [
            _abono(30000, DateTime(2026, 11, 15), categoria: 'ing-nomina'),
            _abono(8000, DateTime(2026, 11, 3), categoria: 'ing-rentas', cuenta: 'cetes'),
          ],
          categorias: categorias,
          cuentas: cuentas,
          gastos: [_gasto(1000, DateTime(2026, 11, 4), cuenta: 'bbva'), _gasto(500, DateTime(2026, 11, 4))],
          rango: rango,
          soloCuentas: solo,
        );
    final bbva = con({'bbva'});
    expect(bbva.total, const Dinero.pesos(30000));
    expect(bbva.porCuenta.single.cuenta.id, 'bbva');
    expect(bbva.gastado, const Dinero.pesos(1000), reason: 'el gasto sin cuenta cae en la tarjeta base');
    expect(con({'bbva', 'cetes'}).total, const Dinero.pesos(38000));
    expect(con(const {}).total, const Dinero.pesos(38000));
    expect(con(null).gastado, const Dinero.pesos(1500));
  });

  test('sin fuente dominante: repartido, un solo abono o todo sin categoría', () {
    ReporteIngresos con(List<MovimientoCuenta> abonos) => calcularReporteIngresos(
          movimientosCuenta: abonos,
          categorias: categorias,
          cuentas: cuentas,
          gastos: const [],
          rango: rango,
        );
    expect(
      con([
        _abono(600, DateTime(2026, 11, 1), categoria: 'ing-nomina'),
        _abono(400, DateTime(2026, 11, 2), categoria: 'ing-rentas'),
      ]).fuenteDominante,
      isNull,
    );
    expect(con([_abono(600, DateTime(2026, 11, 1), categoria: 'ing-nomina')]).fuenteDominante, isNull);
    expect(con([_abono(600, DateTime(2026, 11, 1)), _abono(600, DateTime(2026, 11, 2))]).fuenteDominante, isNull);
  });

  test('sin ingresos: todo en ceros y sin barras si el rango es de más de 13 meses', () {
    final r = calcularReporteIngresos(
      movimientosCuenta: const [],
      categorias: categorias,
      cuentas: cuentas,
      gastos: [_gasto(100, DateTime(2026, 11, 2))],
      rango: RangoFechas(DateTime(2025), DateTime(2026, 11, 30)),
    );
    expect(r.vacio, isTrue);
    expect(r.porCategoria, isEmpty);
    expect(r.meses, isEmpty);
    expect(r.mesMasAlto, isNull);
    expect(r.mayor, isNull);
    expect(r.porcentajeGastado, isNull);
    expect(r.fuenteDominante, isNull);
    expect(r.quedo, Dinero.pesos(-100));
  });

  test('la categoría de ingreso y el abono con categoría van y vuelven en JSON', () {
    final c = CategoriaIngreso.fromJson(categoriasIngresoSugeridas.first.copyWith(nombre: 'Sueldo', activa: false).toJson());
    expect((c.id, c.nombre, c.emoji, c.activa), ('ing-nomina', 'Sueldo', '💼', false));
    expect(categoriasIngresoSugeridas.first.copyWith().nombre, 'Nómina');
    final a = _abono(100, DateTime(2026, 11, 1), categoria: 'ing-rentas');
    expect(MovimientoCuenta.fromJson(a.toJson()).categoriaIngresoId, 'ing-rentas');
    expect(a.anulado().categoriaIngresoId, 'ing-rentas');
    expect(_abono(1, DateTime(2026)).toJson().containsKey('categoriaIngresoId'), isFalse);
  });
}
