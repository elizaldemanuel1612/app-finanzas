import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/cuentas/compra_a_meses.dart';
import 'package:app_finanzas/domain/cuentas/resumen_a_meses.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

// Análisis › A meses (spec-app-finanzas-v2.md §7.3.1, 2026-11-27).

List<Movimiento> _compra(String id, {required int pesos, required int meses, required DateTime fecha, String cuenta = 'bbva', int diferido = 0}) =>
    switch (crearCompraAMeses(
      compraId: 'compra-$id-0001',
      fecha: fecha,
      calculadoraCiclo: const CalculadoraCiclo(1),
      total: Dinero.pesos(pesos),
      meses: meses,
      categoriaId: 'casa',
      descripcion: id,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuenta,
      diferido: diferido,
    )) {
      Exito(:final valor) => valor,
      Falla(:final mensaje) => throw StateError(mensaje),
    };

Cuenta _cuenta(String id) => Cuenta(
      id: id,
      nombre: id,
      emoji: '💳',
      tipo: TipoCuenta.credito,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 1, 1),
    );

void main() {
  final hoy = DateTime(2026, 11, 27);
  // Pantalla: 12 × $1,000 desde el 10 de sep (van 3). Celular: 3 × $300
  // desde el 1 de oct (termina el 1 de dic). Sala: diferida 3 meses, 6 ×
  // $2,000 desde el 20 de feb, en otra tarjeta. Una vieja ya terminada y una
  // anulada no cuentan.
  final gastos = [
    ..._compra('pantalla', pesos: 12000, meses: 12, fecha: DateTime(2026, 9, 10)),
    ..._compra('celular', pesos: 900, meses: 3, fecha: DateTime(2026, 10, 1)),
    ..._compra('sala', pesos: 12000, meses: 6, fecha: DateTime(2026, 11, 20), cuenta: 'amex', diferido: 3),
    ..._compra('vieja', pesos: 600, meses: 3, fecha: DateTime(2026, 1, 5)),
    for (final m in _compra('anulada', pesos: 600, meses: 3, fecha: DateTime(2026, 11, 1))) m.copyWith(estado: EstadoMovimiento.anulado),
  ];

  test('cuánto se debe, cuánto va pagado y lo de cada mes', () {
    final r = resumirComprasAMeses(gastos: gastos, hoy: hoy);
    expect([for (final c in r.compras) c.descripcion], ['sala', 'celular', 'pantalla']);
    expect(r.debes, const Dinero.pesos(9000 + 300 + 12000));
    expect(r.pagado, const Dinero.pesos(3000 + 600));
    expect(r.total, const Dinero.pesos(12000 + 900 + 12000));
    expect(r.esteMes, const Dinero.pesos(1300));
    expect(r.siguienteMes, const Dinero.pesos(1300));
    expect([for (final p in r.proximosMeses.take(4)) p.monto.centavos ~/ 100], [1300, 1300, 1000, 3000]);
    expect(r.proximosMeses.first.mes, DateTime(2026, 11));
    expect(r.proximosMeses, hasLength(12));
    expect(r.porEmpezar.single.descripcion, 'sala');
    expect(r.primerAlivio!.mes, DateTime(2027, 1));
    expect(r.primerAumento!.mes, DateTime(2027, 2));
    expect(r.ultimoPago, DateTime(2027, 8, 10));
    expect(r.porcentajeDe(const Dinero.pesos(20000)), 7);
    expect(r.porcentajeDe(const Dinero.cero()), isNull);
    expect(r.vacio, isFalse);
  });

  test('por cuenta, de la que más se debe; y filtrado a una', () {
    final r = resumirComprasAMeses(gastos: gastos, hoy: hoy);
    expect([for (final c in r.porCuenta) (c.cuentaId, c.debes, c.esteMes, c.compras)], [
      ('amex', const Dinero.pesos(12000), const Dinero.cero(), 1),
      ('bbva', const Dinero.pesos(9300), const Dinero.pesos(1300), 2),
    ]);
    final soloBbva = resumirComprasAMeses(gastos: gastos, hoy: hoy, soloCuentas: {'bbva'});
    expect(soloBbva.debes, const Dinero.pesos(9300));
    expect(soloBbva.porEmpezar, isEmpty);
    expect(cuentasConMeses([_cuenta('amex'), _cuenta('bbva'), _cuenta('nu')], r).map((c) => c.id), ['amex', 'bbva']);
  });

  test('si no baja en los meses que se ven, no hay alivio', () {
    final r = resumirComprasAMeses(gastos: _compra('pantalla', pesos: 24000, meses: 24, fecha: DateTime(2026, 11, 1)), hoy: hoy);
    expect(r.primerAlivio, isNull);
    expect(r.primerAumento, isNull);
  });

  test('sin compras a meses', () {
    final r = resumirComprasAMeses(gastos: const [], hoy: hoy);
    expect(r.vacio, isTrue);
    expect(r.ultimoPago, isNull);
    expect(r.esteMes, const Dinero.cero());
  });
}
