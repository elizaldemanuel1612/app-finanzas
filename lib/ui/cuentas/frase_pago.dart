import '../../domain/cuentas/fechas_tarjeta.dart';
import '../comun/chip_estado.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';

/// Cómo se dice el pago de una tarjeta (spec §7.3.1, 2026-11-15), igual en
/// el aviso de Inicio, el detalle de la tarjeta y la lista de cuentas.
({String titulo, String apoyo, TonoEstado tono}) frasesDePago(PagoTarjeta p) {
  final nombre = p.cuenta.nombre;
  final monto = enPesos(p.monto);
  final corte = fechaCorta(p.corte);
  if (p.estado == EstadoPagoTarjeta.sinPendiente) {
    return (
      titulo: 'Sin pago pendiente de $nombre',
      apoyo: 'Próximo corte: ${fechaCorta(p.proximoCorte)}.',
      tono: TonoEstado.exito,
    );
  }
  final titulo = switch (p.diasParaPagar) {
    < 0 => 'Se pasó la fecha de pago de $nombre',
    0 => 'Hoy vence el pago de $nombre',
    1 => 'Mañana vence el pago de $nombre',
    _ => 'Paga $nombre antes del ${fechaCorta(p.fechaPago)}',
  };
  final apoyo = p.esReferencia
      ? (p.abonado.esPositivo
          ? 'Te faltan $monto: gastaste ${enPesos(p.gastadoPeriodo)} en el periodo que cortó el $corte '
              'y ya abonaste ${enPesos(p.abonado)}.'
          : 'Gastaste $monto con ella en el periodo que cortó el $corte.')
      : 'Para no pagar intereses: $monto (corte del $corte).';
  final tono = p.diasParaPagar < 0
      ? TonoEstado.peligro
      : p.diasParaPagar <= 7
          ? TonoEstado.atencion
          : TonoEstado.neutro;
  return (titulo: titulo, apoyo: apoyo, tono: tono);
}

/// Una línea para la lista de cuentas.
String lineaDePago(PagoTarjeta p) => switch (p.estado) {
      EstadoPagoTarjeta.sinPendiente => 'Corta el ${fechaCorta(p.proximoCorte)}',
      EstadoPagoTarjeta.vencido => 'Pago vencido el ${fechaCorta(p.fechaPago)}',
      EstadoPagoTarjeta.porPagar => 'Paga antes del ${fechaCorta(p.fechaPago)}',
    };
