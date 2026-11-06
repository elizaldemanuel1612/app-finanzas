import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/cuentas/saldos.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

final _desde = DateTime(2026, 11, 1, 9);

Cuenta _debito([String id = 'bbva', int saldo = 1000]) => Cuenta(
      id: id,
      nombre: id.toUpperCase(),
      emoji: '💳',
      tipo: TipoCuenta.debito,
      llevaSaldo: true,
      saldoInicial: Dinero.pesos(saldo),
      fechaSaldoInicial: _desde,
    );

var _n = 0;
Movimiento _gasto(
  int pesos, {
  String? cuenta = 'bbva',
  DateTime? fecha,
  MedioPago medio = MedioPago.tarjeta,
  EstadoMovimiento estado = EstadoMovimiento.activo,
  String ciclo = '2026-11',
  String categoria = 'super',
}) =>
    Movimiento(
      clientId: 'g${_n++}',
      fecha: fecha ?? DateTime(2026, 11, 2),
      cicloId: ciclo,
      periodoNatural: '2026-11',
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: medio,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuenta,
    );

MovimientoCuenta _mc(
  int pesos, {
  bool entra = true,
  TipoMovimientoCuenta tipo = TipoMovimientoCuenta.abono,
  DateTime? fecha,
  EstadoMovimientoCuenta estado = EstadoMovimientoCuenta.activo,
}) =>
    MovimientoCuenta(
      clientId: 'm${_n++}',
      cuentaId: 'bbva',
      fecha: fecha ?? DateTime(2026, 11, 3),
      monto: Dinero.pesos(pesos),
      tipo: tipo,
      entra: entra,
      estado: estado,
    );

void main() {
  test('saldo = inicial + abonos ± ajustes − gastos activos desde la fecha inicial', () {
    final saldo = saldoDe(_debito(), [
      _gasto(100),
      _gasto(50, estado: EstadoMovimiento.anulado),
      _gasto(70, fecha: DateTime(2026, 10, 31)), // antes del saldo inicial
      _gasto(30, cuenta: 'otra'),
    ], [
      _mc(500),
      _mc(20, entra: false, tipo: TipoMovimientoCuenta.ajuste),
      _mc(999, estado: EstadoMovimientoCuenta.anulado),
      _mc(5, fecha: DateTime(2026, 10, 1)),
    ]);
    expect(saldo, const Dinero.pesos(1000 - 100 + 500 - 20));
  });

  test('puede quedar negativo', () {
    expect(saldoDe(_debito('bbva', 10), [_gasto(25)], const []), const Dinero.pesos(-15));
  });

  test('sin saldo (crédito o efectivo sin activar): null', () {
    expect(saldoDe(cuentasBase(_desde).first, const [], const []), isNull);
  });

  test('los gastos de antes de las cuentas caen en Tarjeta o Efectivo por su medio', () {
    expect(cuentaDe(_gasto(1, cuenta: null)), idCuentaTarjeta);
    expect(cuentaDe(_gasto(1, cuenta: null, medio: MedioPago.efectivo)), idCuentaEfectivo);
    final efectivo = cuentasBase(_desde).last.copyWith(llevaSaldo: true, saldoInicial: const Dinero.pesos(800));
    expect(saldoDe(efectivo, [_gasto(100, cuenta: null, medio: MedioPago.efectivo)], const []), const Dinero.pesos(700));
  });

  test('ajuste para cuadrar con el banco', () {
    expect(ajusteParaSaldo(actual: const Dinero.pesos(100), deseado: const Dinero.pesos(150)),
        (monto: const Dinero.pesos(50), entra: true));
    expect(ajusteParaSaldo(actual: const Dinero.pesos(100), deseado: const Dinero.pesos(40)),
        (monto: const Dinero.pesos(60), entra: false));
    expect(ajusteParaSaldo(actual: const Dinero.pesos(1), deseado: const Dinero.pesos(1)), isNull);
  });

  test('orden por uso: activas, la más usada primero; empate, su orden', () {
    final base = cuentasBase(_desde);
    final archivada = _debito('vieja').copyWith(activa: false);
    final cuentas = [...base, _debito(), archivada];
    final orden = ordenarCuentasPorUso(cuentas, [
      _gasto(1),
      _gasto(1),
      _gasto(1, cuenta: null, medio: MedioPago.efectivo),
      _gasto(1, cuenta: 'tarjeta', estado: EstadoMovimiento.anulado),
    ]);
    expect([for (final c in orden) c.id], ['bbva', 'efectivo', 'tarjeta']);
  });

  test('última cuenta usada: la del último gasto activo', () {
    expect(ultimaCuentaUsada(const []), isNull);
    expect(ultimaCuentaUsada([_gasto(1), _gasto(1, cuenta: 'amex'), _gasto(1, estado: EstadoMovimiento.anulado)]), 'amex');
  });

  test('copyWith: el tipo manda sobre si lleva saldo', () {
    final c = _debito();
    // Crédito lo elige el usuario: al pasar de débito se queda como estaba.
    expect(c.copyWith(tipo: TipoCuenta.credito).llevaSaldo, isTrue);
    expect(c.copyWith(tipo: TipoCuenta.credito, llevaSaldo: false).llevaSaldo, isFalse);
    expect(c.copyWith(tipo: TipoCuenta.efectivo, llevaSaldo: false).llevaSaldo, isFalse);
    expect(cuentasBase(_desde).first.copyWith(tipo: TipoCuenta.debito).llevaSaldo, isTrue);
    expect(TipoCuenta.debito.medio, MedioPago.tarjeta);
    expect(TipoCuenta.efectivo.medio, MedioPago.efectivo);
  });

  test('JSON de ida y vuelta', () {
    final c = _debito().copyWith(activa: false);
    expect(Cuenta.fromJson(c.toJson()).toJson(), c.toJson());
    expect(Cuenta.fromJson({...c.toJson()}..remove('activa')).activa, isTrue);
    final m = MovimientoCuenta(
      clientId: 'a',
      cuentaId: 'bbva',
      fecha: _desde,
      monto: const Dinero.pesos(5),
      tipo: TipoMovimientoCuenta.abono,
      entra: true,
      nota: 'quincena',
      ingresoExtraId: 'ing',
    );
    expect(MovimientoCuenta.fromJson(m.toJson()).toJson(), m.toJson());
    expect(m.anulado().estado, EstadoMovimientoCuenta.anulado);
    expect(m.anulado().ingresoExtraId, 'ing');
    expect(MovimientoCuenta.fromJson({...m.toJson()}..remove('nota')..remove('ingresoExtraId')).nota, '');
    final g = _gasto(1);
    expect(Movimiento.fromJson(g.toJson()), g);
    expect(g.copyWith(cuentaId: 'amex').cuentaId, 'amex');
  });

  test('resumen por cuenta del ciclo: gastado, %, conteo, principales y saldo', () {
    const superC = CategoriaVariable(
        id: 'super', nombre: 'Súper', emoji: '🛒', activa: true, esNecesaria: true,
        presupuestoMensualCentavos: Dinero.pesos(100));
    const salidas = CategoriaVariable(
        id: 'salidas', nombre: 'Salidas', emoji: '🍿', activa: true, esNecesaria: false,
        presupuestoMensualCentavos: Dinero.pesos(100));
    final cuentas = [...cuentasBase(_desde), _debito(), _debito('vieja').copyWith(activa: false)];
    final r = resumenPorCuenta(
      cuentas: cuentas,
      categorias: const [superC, salidas],
      gastos: [
        _gasto(300),
        _gasto(100, categoria: 'salidas'),
        _gasto(100, cuenta: null, medio: MedioPago.efectivo),
        _gasto(999, ciclo: '2026-10'),
        _gasto(50, categoria: 'borrada'),
      ],
      movimientosCuenta: const [],
      cicloId: '2026-11',
    );
    expect([for (final x in r) x.cuenta.id], ['bbva', 'efectivo', 'tarjeta']);
    expect(r.first.gastado, const Dinero.pesos(450));
    expect(r.first.conteo, 3);
    expect(r.first.porcentaje, 82);
    expect([for (final p in r.first.principales) p.categoria.id], ['super', 'salidas']);
    expect(r.first.saldo, isNotNull);
    expect(r.last.porcentaje, 0);
    expect(r.last.saldo, isNull);

    final vacio = resumenPorCuenta(
      cuentas: cuentasBase(_desde),
      categorias: const [],
      gastos: const [],
      movimientosCuenta: const [],
      cicloId: 'x',
    );
    expect(vacio.every((x) => x.porcentaje == 0), isTrue);
  });

  group('transferencias', () {
    MovimientoCuenta transferencia(int pesos, String de, String a, {EstadoMovimientoCuenta estado = EstadoMovimientoCuenta.activo}) =>
        MovimientoCuenta(
          clientId: 't${_n++}',
          cuentaId: de,
          cuentaDestinoId: a,
          fecha: DateTime(2026, 11, 3),
          monto: Dinero.pesos(pesos),
          tipo: TipoMovimientoCuenta.transferencia,
          entra: false,
          estado: estado,
        );

    test('resta en el origen y suma en el destino; anulada no cuenta', () {
      final efectivo = cuentasBase(_desde).last.copyWith(llevaSaldo: true, saldoInicial: const Dinero.pesos(100));
      final movs = [
        transferencia(300, 'bbva', 'efectivo'),
        transferencia(50, 'bbva', 'efectivo', estado: EstadoMovimientoCuenta.anulado),
      ];
      expect(saldoDe(_debito(), const [], movs), const Dinero.pesos(700));
      expect(saldoDe(efectivo, const [], movs), const Dinero.pesos(400));
    });

    test('pagar la tarjeta de crédito no es gasto: solo baja el débito', () {
      final pago = transferencia(500, 'bbva', idCuentaTarjeta);
      expect(saldoDe(_debito(), const [], [pago]), const Dinero.pesos(500));
      expect(pago.efectoEn('otra'), const Dinero.cero());
      expect(pago.toca(idCuentaTarjeta), isTrue);
      expect(_mc(10).efectoEn('otra'), const Dinero.cero());
      expect(MovimientoCuenta.fromJson(pago.toJson()).cuentaDestinoId, idCuentaTarjeta);
      expect(pago.anulado().cuentaDestinoId, idCuentaTarjeta);
    });

    test('la suma de tus cuentas: solo las activas que llevan saldo', () {
      final efectivo = cuentasBase(_desde).last.copyWith(llevaSaldo: true, saldoInicial: const Dinero.pesos(200));
      final cuentas = [...cuentasBase(_desde), efectivo, _debito(), _debito('vieja').copyWith(activa: false)];
      expect(sumaDeSaldos(cuentas, [_gasto(100)], const []), const Dinero.pesos(200 + 900));
    });
  });

  group('tarjeta de crédito', () {
    Cuenta amex({int debe = 3000, int? limite}) => Cuenta(
          id: 'bbva',
          nombre: 'Amex',
          emoji: '💳',
          tipo: TipoCuenta.credito,
          llevaSaldo: true,
          saldoInicial: Dinero.pesos(-debe),
          fechaSaldoInicial: _desde,
          limite: limite == null ? null : Dinero.pesos(limite),
        );

    test('cada gasto sube lo que debes; pagos y devoluciones lo bajan', () {
      final c = amex(limite: 10000);
      final pago = MovimientoCuenta(
        clientId: 'pago',
        cuentaId: 'debito',
        cuentaDestinoId: 'bbva',
        fecha: DateTime(2026, 11, 5),
        monto: const Dinero.pesos(2000),
        tipo: TipoMovimientoCuenta.transferencia,
        entra: false,
      );
      final deuda = deudaDe(c, [_gasto(500)], [pago, _mc(100)]);
      expect(deuda, const Dinero.pesos(3000 + 500 - 2000 - 100));
      final lectura = lecturaDeSaldo(c, saldoDe(c, [_gasto(500)], [pago, _mc(100)])!);
      expect(lectura.etiqueta, 'Debes');
      expect(lectura.monto, const Dinero.pesos(1400));
      expect(lectura.disponible, const Dinero.pesos(8600));
      expect(lectura.alerta, isFalse);
    });

    test('pasado del límite se marca; pagado de más queda a tu favor', () {
      final c = amex(debe: 9900, limite: 10000);
      final pasada = lecturaDeSaldo(c, saldoDe(c, [_gasto(200)], const [])!);
      expect(pasada.disponible, const Dinero.pesos(-100));
      expect(pasada.alerta, isTrue);
      final aFavor = lecturaDeSaldo(amex(debe: 0), const Dinero.pesos(50));
      expect(aFavor.etiqueta, 'A tu favor');
      expect(aFavor.monto, const Dinero.pesos(50));
      expect(lecturaDeSaldo(_debito(), const Dinero.pesos(-5)).alerta, isTrue);
    });

    test('lo que debes va aparte del total de tus cuentas', () {
      final cuentas = [_debito('debito'), amex(), amex(debe: 0).copyWith(activa: false)];
      final gastos = [_gasto(100, cuenta: 'debito')];
      expect(sumaDeSaldos(cuentas, gastos, const []), const Dinero.pesos(900));
      expect(sumaDeDeudas(cuentas, gastos, const []), const Dinero.pesos(3000));
      expect(deudaDe(_debito(), const [], const []), isNull);
      expect(deudaDe(cuentasBase(_desde).first, const [], const []), isNull);
    });

    test('el límite viaja en el JSON y se quita si deja de ser crédito', () {
      final c = amex(limite: 10000);
      expect(Cuenta.fromJson(c.toJson()).limite, const Dinero.pesos(10000));
      expect(c.copyWith(limite: () => null).limite, isNull);
      expect(c.copyWith(nombre: 'Otra').limite, const Dinero.pesos(10000));
      expect(c.copyWith(tipo: TipoCuenta.debito).limite, isNull);
    });
  });
}
