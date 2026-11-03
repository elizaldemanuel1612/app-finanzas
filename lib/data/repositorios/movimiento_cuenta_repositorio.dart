import '../../domain/modelos/movimiento_cuenta.dart';

/// Abonos y ajustes de las cuentas (spec §7.3.1). Sin borrar: se anulan.
abstract interface class MovimientoCuentaRepositorio {
  /// Idempotente por `clientId` (regla #2): si ya existe, regresa el guardado.
  Future<MovimientoCuenta> guardar(MovimientoCuenta movimiento);

  Future<List<MovimientoCuenta>> listarTodos();

  Future<void> anular(String clientId);
}
