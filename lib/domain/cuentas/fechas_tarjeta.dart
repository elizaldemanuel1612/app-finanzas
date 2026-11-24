import '../../core/money.dart';
import '../modelos/cuenta.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../modelos/movimiento_cuenta.dart';
import 'saldos.dart';

// Corte y fecha de pago de una tarjeta de crédito
// (spec-app-finanzas-v2.md §7.3.1, 2026-11-15).

/// En qué va el pago del último corte.
enum EstadoPagoTarjeta {
  /// No hay nada que pagar de ese corte.
  sinPendiente,

  /// Falta pagar y la fecha no ha pasado (o es hoy).
  porPagar,

  /// Pasó la fecha y aún se debe algo del corte (solo con saldo).
  vencido,
}

/// El pago que toca de una tarjeta.
final class PagoTarjeta {
  final Cuenta cuenta;

  /// El último corte (hoy incluido) y la fecha límite que le toca.
  final DateTime corte;
  final DateTime fechaPago;
  final DateTime proximoCorte;

  /// Lo que hay que pagar para no generar intereses. Si la tarjeta no lleva
  /// saldo, es lo gastado en el periodo menos lo abonado: una referencia
  /// ([esReferencia]).
  final Dinero monto;

  /// Solo sin saldo: lo gastado en el periodo y lo que ya se abonó a este
  /// corte (abonos y transferencias que entraron después de la fecha de pago
  /// del corte anterior). Con saldo, los dos son cero: ya están en la deuda.
  final Dinero gastadoPeriodo;
  final Dinero abonado;
  final bool esReferencia;
  final EstadoPagoTarjeta estado;

  /// Días de hoy a [fechaPago]: 0 si vence hoy, negativo si ya pasó.
  final int diasParaPagar;

  const PagoTarjeta({
    required this.cuenta,
    required this.corte,
    required this.fechaPago,
    required this.proximoCorte,
    required this.monto,
    this.gastadoPeriodo = const Dinero.cero(),
    this.abonado = const Dinero.cero(),
    required this.esReferencia,
    required this.estado,
    required this.diasParaPagar,
  });
}

/// El día [dia] de ese mes; en meses más cortos, el último. Acepta meses
/// fuera de 1–12 (se recorren al año que toque).
DateTime _enDia(int anio, int mes, int dia) {
  final ultimo = DateTime(anio, mes + 1, 0).day;
  return DateTime(anio, mes, dia < ultimo ? dia : ultimo);
}

DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// El último día de corte, hoy incluido.
DateTime ultimoCorte(int diaCorte, DateTime hoy) {
  final dia = _soloFecha(hoy);
  final este = _enDia(dia.year, dia.month, diaCorte);
  return este.isAfter(dia) ? _enDia(dia.year, dia.month - 1, diaCorte) : este;
}

/// El corte que sigue a [corte].
DateTime corteSiguiente(int diaCorte, DateTime corte) => _enDia(corte.year, corte.month + 1, diaCorte);

/// La fecha límite que le toca a [corte]: la primera con [diaPago] después
/// del corte.
DateTime fechaDePago(DateTime corte, int diaPago) {
  final mismoMes = _enDia(corte.year, corte.month, diaPago);
  return mismoMes.isAfter(corte) ? mismoMes : _enDia(corte.year, corte.month + 1, diaPago);
}

/// El pago que toca de [cuenta]; `null` si no es de crédito o le falta el
/// día de corte o el de pago.
PagoTarjeta? pagoDeTarjeta(
  Cuenta cuenta,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  required DateTime hoy,
}) {
  final diaCorte = cuenta.diaCorte;
  final diaPago = cuenta.diaPago;
  if (cuenta.tipo != TipoCuenta.credito || diaCorte == null || diaPago == null) return null;
  final corte = ultimoCorte(diaCorte, hoy);
  final corteAnterior = _enDia(corte.year, corte.month - 1, diaCorte);
  final pago = fechaDePago(corte, diaPago);
  final finDelCorte = corte.add(const Duration(days: 1));
  // Redondeado: un cambio de horario no debe mover un día.
  final dias = (pago.difference(_soloFecha(hoy)).inHours / 24).round();

  bool deEsta(Movimiento g) => cuentaDe(g) == cuenta.id && g.estado == EstadoMovimiento.activo;
  Dinero suma(bool Function(DateTime) enRango) => Dinero(gastos
      .where((g) => deEsta(g) && enRango(g.fecha))
      .fold<int>(0, (total, g) => total + g.monto.centavos));

  final deuda = deudaDe(cuenta, gastos, movimientosCuenta);
  final Dinero monto;
  final EstadoPagoTarjeta estado;
  var gastadoPeriodo = const Dinero.cero();
  var abonado = const Dinero.cero();
  if (deuda != null) {
    // Lo de después del corte va al siguiente; los pagos de después ya
    // bajaron la deuda.
    final despues = suma((f) => !f.isBefore(finDelCorte) && !f.isBefore(cuenta.fechaSaldoInicial));
    final pendiente = deuda - despues;
    monto = pendiente.esPositivo ? pendiente : const Dinero.cero();
    estado = !monto.esPositivo
        ? EstadoPagoTarjeta.sinPendiente
        : (dias < 0 ? EstadoPagoTarjeta.vencido : EstadoPagoTarjeta.porPagar);
  } else {
    final inicioPeriodo = corteAnterior.add(const Duration(days: 1));
    gastadoPeriodo = suma((f) => !f.isBefore(inicioPeriodo) && f.isBefore(finDelCorte));
    // Lo que entró a la tarjeta (abonos y transferencias) después de la fecha
    // de pago del corte anterior es para este corte; lo de antes pagó aquel.
    final desde = fechaDePago(corteAnterior, diaPago).add(const Duration(days: 1));
    abonado = Dinero(movimientosCuenta
        .where((m) =>
            m.tipo != TipoMovimientoCuenta.ajuste &&
            m.estado == EstadoMovimientoCuenta.activo &&
            m.toca(cuenta.id) &&
            !m.fecha.isBefore(desde))
        .map((m) => m.efectoEn(cuenta.id).centavos)
        .where((c) => c > 0)
        .fold<int>(0, (total, c) => total + c));
    final pendiente = gastadoPeriodo - abonado;
    monto = pendiente.esPositivo ? pendiente : const Dinero.cero();
    // Sin saldo no se sabe si ya se pagó: pasada la fecha, ya no se avisa.
    estado = monto.esPositivo && dias >= 0 ? EstadoPagoTarjeta.porPagar : EstadoPagoTarjeta.sinPendiente;
  }
  return PagoTarjeta(
    cuenta: cuenta,
    corte: corte,
    fechaPago: pago,
    proximoCorte: corteSiguiente(diaCorte, corte),
    monto: monto,
    gastadoPeriodo: gastadoPeriodo,
    abonado: abonado,
    esReferencia: deuda == null,
    estado: estado,
    diasParaPagar: dias,
  );
}

/// El aviso de Inicio: el pago más urgente que esté vencido o venza en los
/// próximos [dias] días, de las tarjetas activas. `null` si no hay.
PagoTarjeta? pagoMasUrgente(
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  required DateTime hoy,
  int dias = 7,
}) {
  PagoTarjeta? urgente;
  for (final c in cuentas) {
    if (!c.activa) continue;
    final pago = pagoDeTarjeta(c, gastos, movimientosCuenta, hoy: hoy);
    if (pago == null || pago.estado == EstadoPagoTarjeta.sinPendiente || pago.diasParaPagar > dias) continue;
    if (urgente == null || pago.diasParaPagar < urgente.diasParaPagar) urgente = pago;
  }
  return urgente;
}
