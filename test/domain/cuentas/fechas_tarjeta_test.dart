import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/cuentas/fechas_tarjeta.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §7.3.1 (2026-11-15): corte y fecha de pago.

Cuenta _tarjeta({int? corte = 5, int? pago = 25, bool conSaldo = true, int debe = 0, String id = 'platino'}) => Cuenta(
      id: id,
      nombre: 'Platino',
      emoji: '💳',
      tipo: TipoCuenta.credito,
      llevaSaldo: conSaldo,
      saldoInicial: Dinero.pesos(-debe),
      fechaSaldoInicial: DateTime(2026, 10, 1),
      diaCorte: corte,
      diaPago: pago,
    );

var _n = 0;
Movimiento _gasto(int pesos, DateTime fecha, {String cuenta = 'platino', EstadoMovimiento estado = EstadoMovimiento.activo}) =>
    Movimiento(
      clientId: 'g${_n++}',
      fecha: fecha,
      cicloId: '2026-11',
      periodoNatural: '2026-11',
      monto: Dinero.pesos(pesos),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuenta,
    );

MovimientoCuenta _pago(int pesos, DateTime fecha) => MovimientoCuenta(
      clientId: 'p${_n++}',
      cuentaId: 'platino',
      fecha: fecha,
      monto: Dinero.pesos(pesos),
      tipo: TipoMovimientoCuenta.abono,
      entra: true,
    );

MovimientoCuenta _transferencia(int pesos, DateTime fecha, {String de = 'nomina', String a = 'platino'}) =>
    MovimientoCuenta(
      clientId: 't${_n++}',
      cuentaId: de,
      cuentaDestinoId: a,
      fecha: fecha,
      monto: Dinero.pesos(pesos),
      tipo: TipoMovimientoCuenta.transferencia,
      entra: false,
    );

void main() {
  group('fechas', () {
    test('el último corte incluye hoy y si no, es el del mes pasado', () {
      expect(ultimoCorte(5, DateTime(2026, 11, 5, 18)), DateTime(2026, 11, 5));
      expect(ultimoCorte(5, DateTime(2026, 11, 4)), DateTime(2026, 10, 5));
      expect(ultimoCorte(20, DateTime(2026, 1, 3)), DateTime(2025, 12, 20));
    });

    test('en meses cortos el día de corte cae en el último', () {
      expect(ultimoCorte(31, DateTime(2026, 2, 28)), DateTime(2026, 2, 28));
      expect(corteSiguiente(31, DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });

    test('la fecha de pago es la primera con ese día después del corte', () {
      expect(fechaDePago(DateTime(2026, 11, 5), 25), DateTime(2026, 11, 25));
      expect(fechaDePago(DateTime(2026, 11, 20), 10), DateTime(2026, 12, 10));
      expect(fechaDePago(DateTime(2026, 11, 20), 20), DateTime(2026, 12, 20));
    });
  });

  group('pagoDeTarjeta', () {
    test('sin días o si no es de crédito no hay pago', () {
      expect(pagoDeTarjeta(_tarjeta(corte: null), [], [], hoy: DateTime(2026, 11, 10)), isNull);
      expect(pagoDeTarjeta(_tarjeta(pago: null), [], [], hoy: DateTime(2026, 11, 10)), isNull);
      final debito = _tarjeta().copyWith(tipo: TipoCuenta.debito);
      expect(debito.diaCorte, isNull);
      expect(pagoDeTarjeta(debito, [], [], hoy: DateTime(2026, 11, 10)), isNull);
    });

    test('con saldo: lo del corte menos lo pagado; lo de después va al siguiente', () {
      final gastos = [
        _gasto(1000, DateTime(2026, 10, 20)),
        _gasto(500, DateTime(2026, 11, 5, 21)), // el día del corte cuenta
        _gasto(300, DateTime(2026, 11, 8)), // después del corte
        _gasto(999, DateTime(2026, 11, 2), estado: EstadoMovimiento.anulado),
        _gasto(777, DateTime(2026, 11, 2), cuenta: 'otra'),
      ];
      final p = pagoDeTarjeta(_tarjeta(debe: 200), gastos, [_pago(400, DateTime(2026, 11, 9))], hoy: DateTime(2026, 11, 10))!;
      expect(p.corte, DateTime(2026, 11, 5));
      expect(p.fechaPago, DateTime(2026, 11, 25));
      expect(p.proximoCorte, DateTime(2026, 12, 5));
      expect(p.monto, Dinero.pesos(200 + 1000 + 500 - 400));
      expect(p.esReferencia, isFalse);
      expect(p.estado, EstadoPagoTarjeta.porPagar);
      expect(p.diasParaPagar, 15);
    });

    test('pagado por completo no queda pendiente; sin pagar y pasada la fecha, vencido', () {
      final gastos = [_gasto(1000, DateTime(2026, 11, 1)), _gasto(300, DateTime(2026, 11, 8))];
      final pagado = pagoDeTarjeta(_tarjeta(), gastos, [_pago(1000, DateTime(2026, 11, 9))], hoy: DateTime(2026, 11, 10))!;
      expect(pagado.monto, const Dinero.cero());
      expect(pagado.estado, EstadoPagoTarjeta.sinPendiente);

      final vencido = pagoDeTarjeta(_tarjeta(), gastos, [], hoy: DateTime(2026, 11, 27))!;
      expect(vencido.monto, Dinero.pesos(1000));
      expect(vencido.estado, EstadoPagoTarjeta.vencido);
      expect(vencido.diasParaPagar, -2);
    });

    test('sin saldo: lo gastado en el periodo como referencia; pasada la fecha ya no avisa', () {
      final gastos = [
        _gasto(100, DateTime(2026, 10, 5)), // corte anterior: ya no entra
        _gasto(600, DateTime(2026, 10, 6)),
        _gasto(400, DateTime(2026, 11, 5)),
        _gasto(50, DateTime(2026, 11, 6)),
      ];
      final p = pagoDeTarjeta(_tarjeta(conSaldo: false), gastos, [], hoy: DateTime(2026, 11, 20))!;
      expect(p.monto, Dinero.pesos(1000));
      expect(p.esReferencia, isTrue);
      expect(p.estado, EstadoPagoTarjeta.porPagar);

      final despues = pagoDeTarjeta(_tarjeta(conSaldo: false), gastos, [], hoy: DateTime(2026, 11, 26))!;
      expect(despues.estado, EstadoPagoTarjeta.sinPendiente);
      final vacio = pagoDeTarjeta(_tarjeta(conSaldo: false), [], [], hoy: DateTime(2026, 11, 20))!;
      expect(vacio.estado, EstadoPagoTarjeta.sinPendiente);
    });
  });

  group('abonos y transferencias a la tarjeta (2026-11-24)', () {
    final gastos = [_gasto(600, DateTime(2026, 10, 10)), _gasto(400, DateTime(2026, 11, 3))];

    test('con saldo: una transferencia desde débito baja el pago igual que un abono', () {
      final p = pagoDeTarjeta(_tarjeta(), gastos, [_transferencia(300, DateTime(2026, 11, 1))], hoy: DateTime(2026, 11, 10))!;
      expect(p.monto, Dinero.pesos(700));
      expect(p.abonado, const Dinero.cero());
    });

    test('sin saldo: se descuenta lo abonado después de la fecha de pago anterior', () {
      final movimientos = [
        _pago(250, DateTime(2026, 10, 25)), // pagó el corte anterior (vencía ese día)
        _pago(300, DateTime(2026, 10, 30)), // durante el periodo
        _transferencia(200, DateTime(2026, 11, 8)), // ya cortado
        _transferencia(90, DateTime(2026, 11, 9), de: 'platino', a: 'nomina'), // sale: no es pago
        _pago(999, DateTime(2026, 11, 9)).anulado(),
        MovimientoCuenta(
          clientId: 'aj',
          cuentaId: 'platino',
          fecha: DateTime(2026, 11, 9),
          monto: Dinero.pesos(50),
          tipo: TipoMovimientoCuenta.ajuste,
          entra: true,
        ),
        _transferencia(80, DateTime(2026, 11, 9), a: 'otra'), // a otra cuenta
      ];
      final p = pagoDeTarjeta(_tarjeta(conSaldo: false), gastos, movimientos, hoy: DateTime(2026, 11, 10))!;
      expect(p.gastadoPeriodo, Dinero.pesos(1000));
      expect(p.abonado, Dinero.pesos(500));
      expect(p.monto, Dinero.pesos(500));
      expect(p.estado, EstadoPagoTarjeta.porPagar);
    });

    test('sin saldo: pagado por completo (o de más) ya no queda pendiente', () {
      final p = pagoDeTarjeta(_tarjeta(conSaldo: false), gastos, [_pago(1200, DateTime(2026, 11, 6))], hoy: DateTime(2026, 11, 10))!;
      expect(p.monto, const Dinero.cero());
      expect(p.estado, EstadoPagoTarjeta.sinPendiente);
    });
  });

  test('el más urgente: vencido o dentro de 7 días, de las activas', () {
    final gastos = [
      _gasto(1000, DateTime(2026, 11, 1)),
      _gasto(500, DateTime(2026, 11, 1), cuenta: 'oro'),
      _gasto(500, DateTime(2026, 11, 1), cuenta: 'vieja'),
    ];
    final cuentas = [
      _tarjeta(),
      _tarjeta(id: 'oro', pago: 20),
      _tarjeta(id: 'vieja', pago: 19).copyWith(activa: false),
      _tarjeta(id: 'sin', corte: null),
    ];
    expect(pagoMasUrgente(cuentas, gastos, [], hoy: DateTime(2026, 11, 10)), isNull);
    expect(pagoMasUrgente(cuentas, gastos, [], hoy: DateTime(2026, 11, 15))!.cuenta.id, 'oro');
    expect(pagoMasUrgente(cuentas, gastos, [], hoy: DateTime(2026, 11, 22))!.cuenta.id, 'oro');
  });

  test('corte y pago van y vuelven en JSON y se quitan al dejar de ser crédito', () {
    final t = _tarjeta();
    final ida = Cuenta.fromJson(t.toJson());
    expect((ida.diaCorte, ida.diaPago), (5, 25));
    final sinCampos = Map<String, dynamic>.from(_tarjeta(corte: null, pago: null).toJson());
    expect(sinCampos.containsKey('diaCorte'), isFalse);
    expect(t.copyWith(diaCorte: () => 10).diaCorte, 10);
    expect(t.copyWith(diaPago: () => null).diaPago, isNull);
    expect(t.copyWith(tipo: TipoCuenta.efectivo).diaPago, isNull);
  });
}
