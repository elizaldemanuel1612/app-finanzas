import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'estado_inicial.dart';
import 'idempotencia.dart';
import 'monto.dart';

/// Punto de entrada único para crear un [Movimiento] nuevo: aplica las
/// reglas no negociables de idempotencia (#2), monto (#1) y estado inicial
/// (#18) antes de construirlo. Si algo no cumple, regresa [Falla] en vez
/// de un movimiento a medio validar.
///
/// El [cicloId] y [periodoNatural] se calculan aquí, a partir de [fecha] y
/// [calculadoraCiclo] — exactamente una vez, como exige la regla #5.
Resultado<Movimiento> crearMovimiento({
  required String clientId,
  required DateTime fecha,
  required CalculadoraCiclo calculadoraCiclo,
  required Dinero monto,
  required String categoriaId,
  required MedioPago medio,
  required String descripcion,
  required OrigenCaptura origenCaptura,
  bool esReembolsable = false,
}) {
  final clientIdValido = validarClientId(clientId);
  if (clientIdValido case Falla(:final mensaje)) return Falla(mensaje);

  final montoValido = validarMontoPositivo(monto, etiqueta: 'monto del gasto');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  final estado = origenCaptura == OrigenCaptura.recurrente
      ? EstadoMovimiento.propuesto
      : EstadoMovimiento.activo;

  final estadoValido =
      validarEstadoInicial(origenCaptura: origenCaptura, estado: estado);
  if (estadoValido case Falla(:final mensaje)) return Falla(mensaje);

  final ciclo = calculadoraCiclo.calcularPara(fecha);

  return Exito(Movimiento(
    clientId: clientId,
    fecha: fecha,
    cicloId: ciclo.id,
    periodoNatural: periodoNatural(fecha),
    monto: monto,
    categoriaId: categoriaId,
    medio: medio,
    descripcion: descripcion,
    estado: estado,
    origenCaptura: origenCaptura,
    esReembolsable: esReembolsable,
  ));
}
