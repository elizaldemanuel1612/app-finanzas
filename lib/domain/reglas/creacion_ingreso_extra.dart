import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/ingreso_extra.dart';
import 'monto.dart';

/// Punto de entrada único para crear un [IngresoExtra] nuevo — espejo de
/// `crearMovimiento` (creacion_movimiento.dart): aplica las reglas no
/// negociables de monto (#1) antes de construirlo.
///
/// El [cicloId] se calcula aquí, a partir de [fecha] y [calculadoraCiclo] —
/// exactamente una vez, como exige la regla #5.
Resultado<IngresoExtra> crearIngresoExtra({
  required String id,
  required DateTime fecha,
  required CalculadoraCiclo calculadoraCiclo,
  required Dinero monto,
  required String etiqueta,
  required DestinoExtra destino,
}) {
  final montoValido = validarMontoPositivo(monto, etiqueta: 'monto del ingreso');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  if (etiqueta.trim().isEmpty) {
    return const Falla('La etiqueta del ingreso no puede estar vacía.');
  }

  final ciclo = calculadoraCiclo.calcularPara(fecha);

  return Exito(IngresoExtra(
    id: id,
    cicloId: ciclo.id,
    etiqueta: etiqueta,
    monto: monto,
    fecha: fecha,
    destino: destino,
    estado: EstadoIngreso.activo,
  ));
}
