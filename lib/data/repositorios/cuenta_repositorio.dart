import '../../domain/modelos/cuenta.dart';

/// Cuentas del usuario (spec-app-finanzas-v2.md §7.3.1). Una cuenta con
/// historial se archiva; [eliminar] es solo para las que nunca se usaron
/// (`comoQuitarCuenta`).
abstract interface class CuentaRepositorio {
  /// Todas, archivadas incluidas. Si faltan las cuentas base (Tarjeta y
  /// Efectivo), las crea primero.
  Future<List<Cuenta>> listarTodas();

  /// Reemplaza la del mismo id, o la agrega.
  Future<void> guardar(Cuenta cuenta);

  /// La quita por completo; no hace nada si no existe.
  Future<void> eliminar(String id);
}
