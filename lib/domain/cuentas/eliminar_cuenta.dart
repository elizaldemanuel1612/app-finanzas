import '../modelos/cuenta.dart';
import '../modelos/movimiento.dart';
import '../modelos/movimiento_cuenta.dart';
import 'apartados.dart';

/// Qué pasa al pedir "Eliminar cuenta" (spec-app-finanzas-v2.md §7.3.1).
enum QuitarCuenta {
  /// Nunca se usó: se borra por completo.
  eliminar,

  /// Tiene movimientos (o es la base Tarjeta, que se vuelve a crear sola):
  /// se archiva y su historial se conserva (regla #3).
  archivar,

  /// Tiene apartados activos: primero hay que eliminarlos (§7.3.5).
  tieneApartados,

  /// Efectivo no se quita.
  noSePuede,
}

/// Decide cómo se quita [cuenta]. Cuenta todo lo que la toca, anulado
/// incluido: un gasto anulado sigue en el historial y diría "de qué cuenta".
/// Los apartados se eliminan con `eliminarApartado`, no con esto.
QuitarCuenta comoQuitarCuenta(
  Cuenta cuenta,
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta,
) {
  if (cuenta.id == idCuentaEfectivo) return QuitarCuenta.noSePuede;
  if (apartadosDe(cuenta, cuentas).isNotEmpty) return QuitarCuenta.tieneApartados;
  if (cuenta.id == idCuentaTarjeta) return QuitarCuenta.archivar;
  final usada = gastos.any((g) => cuentaDe(g) == cuenta.id) ||
      movimientosCuenta.any((m) => m.toca(cuenta.id)) ||
      cuentas.any((c) => c.cuentaPadreId == cuenta.id);
  return usada ? QuitarCuenta.archivar : QuitarCuenta.eliminar;
}
