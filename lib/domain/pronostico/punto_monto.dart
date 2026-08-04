/// Un monto con fecha, ya reducido a lo que el modelo de pronóstico
/// necesita — no es un [Movimiento] completo a propósito, para que
/// domain/pronostico/ no dependa de cómo se capturó el dato.
///
/// [monto] está en **centavos** (como `Dinero.centavos`), pero en `double`
/// — las matemáticas del modelo (medianas, MAD, EWMA) no son aritmética
/// monetaria exacta, son estadística sobre esos centavos. La salida final
/// de un pronóstico se redondea de vuelta a [Dinero] al construir
/// [PronosticoCategoria].
final class PuntoMonto {
  final DateTime fecha;
  final double monto;

  const PuntoMonto(this.fecha, this.monto);
}
