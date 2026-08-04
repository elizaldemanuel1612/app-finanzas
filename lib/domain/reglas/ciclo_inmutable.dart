import '../../core/ciclo.dart';
import '../../core/result.dart';

/// Regla no negociable #5: el `cicloId` se asigna al crear el movimiento y
/// **jamás se recalcula**. [Movimiento] no expone forma de cambiarlo (no
/// hay `copyWith` con ese campo) — esta función es la comprobación
/// explícita para cuando se reconstruye un movimiento desde almacenamiento
/// y hay que verificar que nadie coló un cicloId distinto en el camino.
Resultado<void> validarCicloSinCambios({
  required String cicloIdOriginal,
  required String cicloIdPropuesto,
}) {
  if (cicloIdOriginal != cicloIdPropuesto) {
    return Falla(
      'El ciclo de un movimiento no se recalcula: era $cicloIdOriginal, '
      'se intentó cambiar a $cicloIdPropuesto.',
    );
  }
  return const Exito(null);
}

/// Regla no negociable #6: un ciclo cerrado no cambia. Modificar un
/// movimiento que pertenece a un ciclo cerrado exige reabrirlo primero, de
/// forma explícita (ver [Ciclo.reabrir]).
Resultado<void> validarPuedeModificarse(Ciclo ciclo) {
  if (ciclo.estado == EstadoCiclo.cerrado) {
    return Falla(
      'El ciclo ${ciclo.id} está cerrado. Reábrelo explícitamente '
      '(Ciclo.reabrir) antes de modificar sus movimientos.',
    );
  }
  return const Exito(null);
}
