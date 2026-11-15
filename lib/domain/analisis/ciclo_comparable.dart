import '../../core/ciclo.dart';
import '../modelos/ciclo_guardado.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';

/// Días del inicio de un ciclo en los que ya debió haber registros para
/// tomarlo como completo: la primera semana.
const _diasDeGracia = 7;

/// Si [anterior] sirve para "contra el ciclo pasado"
/// (`docs/rediseno/plan-rediseno.md`, Etapa 0): solo un ciclo **cerrado**
/// y **completo**. Completo quiere decir que la app ya se usaba desde su
/// primera semana: el primer gasto registrado (de toda la historia) cae a
/// más tardar [_diasDeGracia] días después de su inicio. Sin esto, el
/// primer ciclo del usuario —que empezó a registrar a medias— salía como
/// "gastaste $11,550 más en Vivienda" solo porque antes no la había
/// anotado.
bool cicloComparable({
  required Ciclo anterior,
  required List<CicloGuardado> guardados,
  required List<Movimiento> movimientos,
}) {
  final guardado = guardados.where((g) => g.ciclo.id == anterior.id).firstOrNull;
  if (guardado == null || guardado.ciclo.estado != EstadoCiclo.cerrado) return false;
  DateTime? primero;
  for (final m in movimientos) {
    if (m.estado != EstadoMovimiento.activo) continue;
    if (primero == null || m.fecha.isBefore(primero)) primero = m.fecha;
  }
  if (primero == null) return false;
  final limite = DateTime(
    anterior.fechaInicio.year,
    anterior.fechaInicio.month,
    anterior.fechaInicio.day + _diasDeGracia,
  );
  return primero.isBefore(limite);
}
