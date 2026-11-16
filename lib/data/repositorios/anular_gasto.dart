import '../../domain/cuentas/compra_a_meses.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import 'movimiento_repositorio.dart';

/// Anula [m] (regla #3: nada se borra). Si es una mensualidad, anula toda
/// su compra a meses (spec §7.3.1): no se quita una sola mensualidad.
Future<void> anularGasto(MovimientoRepositorio repo, Movimiento m) async {
  if (!m.esAMeses) return repo.anular(m.id ?? m.clientId);
  for (final x in mensualidadesDe(m.compraId!, await repo.listarTodos())) {
    if (x.estado != EstadoMovimiento.anulado) await repo.anular(x.id ?? x.clientId);
  }
}

/// El "Deshacer" de [anularGasto]: lo regresa a activo, con toda su compra.
Future<void> restaurarGasto(MovimientoRepositorio repo, Movimiento m) async {
  final lista = m.esAMeses ? mensualidadesDe(m.compraId!, await repo.listarTodos()) : [m];
  for (final x in lista) {
    await repo.actualizar(x.copyWith(estado: EstadoMovimiento.activo));
  }
}
