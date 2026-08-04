import '../../core/money.dart';
import '../../core/result.dart';

/// Regla no negociable #19: las partes de un ticket dividido deben sumar
/// el total al centavo, o no se registra (ver también app-finanzas-
/// ticket-v7.html §3: "Suma de las partes… cuadra exacto con el total").
Resultado<void> validarPartesTicket({
  required Dinero total,
  required List<Dinero> partes,
}) {
  if (partes.isEmpty) {
    return const Falla('Un ticket dividido necesita al menos una parte.');
  }
  final suma = Dinero.suma(partes);
  if (suma != total) {
    final diferencia = total - suma;
    return Falla(
      'Las partes suman ${suma.formateado()} pero el ticket es '
      '${total.formateado()} — faltan ${diferencia.formateado()}.',
    );
  }
  return const Exito(null);
}
