import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../reglas/monto.dart';

/// Construye un [Movimiento] a partir de un renglón `HIST-####` del Excel
/// (spec-app-finanzas-v2.md §8.1). A diferencia de `crearMovimiento`
/// (domain/reglas/creacion_movimiento.dart), no pasa por las reglas de
/// idempotencia de captura en vivo — [idOrigen] ya es la llave estable que
/// identifica el renglón de origen, así que se reusa como `clientId`.
///
/// Nace `activo`: es dinero que de verdad se movió en el pasado, no algo
/// que el usuario tiene que confirmar.
///
/// Sin UI todavía; se conecta en la fase de importación (ver "Estado
/// actual" en CLAUDE.md). Se conserva sin consumidor a propósito.
Resultado<Movimiento> crearMovimientoMigrado({
  required String idOrigen,
  required DateTime fecha,
  required CalculadoraCiclo calculadoraCiclo,
  required Dinero monto,
  required String categoriaId,
  required MedioPago medio,
  required String descripcion,
  bool granularidadAgregadaDiaria = false,
}) {
  if (idOrigen.trim().isEmpty) {
    return const Falla('idOrigen no puede estar vacío para un movimiento migrado.');
  }

  final montoValido = validarMontoPositivo(monto, etiqueta: 'monto migrado');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  final ciclo = calculadoraCiclo.calcularPara(fecha);

  return Exito(Movimiento(
    clientId: idOrigen,
    idOrigen: idOrigen,
    fecha: fecha,
    cicloId: ciclo.id,
    periodoNatural: periodoNatural(fecha),
    monto: monto,
    categoriaId: categoriaId,
    medio: medio,
    descripcion: descripcion,
    estado: EstadoMovimiento.activo,
    origenCaptura: OrigenCaptura.migracion,
    granularidad:
        granularidadAgregadaDiaria ? Granularidad.agregadoDiario : null,
  ));
}
