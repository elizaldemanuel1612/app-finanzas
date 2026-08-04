import '../../core/result.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';

/// Regla no negociable #18 (paquete-construccion-final.md §6) y spec-app-
/// finanzas-v2.md §1.4: lo que el usuario registra entra `activo` de
/// inmediato — sin bandeja de pendientes. Solo lo que el sistema genera
/// solo (recurrencias de fijos) nace `propuesto` y exige confirmación.
Resultado<void> validarEstadoInicial({
  required OrigenCaptura origenCaptura,
  required EstadoMovimiento estado,
}) {
  final esGeneradoPorElSistema = origenCaptura == OrigenCaptura.recurrente;

  if (estado == EstadoMovimiento.anulado) {
    return const Falla(
      'Un movimiento no puede nacer anulado; se anula después de existir.',
    );
  }

  if (esGeneradoPorElSistema && estado != EstadoMovimiento.propuesto) {
    return Falla(
      'Los movimientos de origen "${origenCaptura.name}" deben nacer '
      'propuesto, no ${estado.name} — el usuario no los escribió.',
    );
  }

  if (!esGeneradoPorElSistema && estado != EstadoMovimiento.activo) {
    return Falla(
      'Los movimientos de origen "${origenCaptura.name}" deben nacer '
      'activo, no ${estado.name} — el usuario los escribió y cuentan de '
      'inmediato.',
    );
  }

  return const Exito(null);
}
