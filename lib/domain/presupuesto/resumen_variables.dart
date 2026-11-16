import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../rollups/rollup.dart';

/// Lo gastado en variables de un ciclo, como lo cuenta el héroe de Inicio,
/// el widget y Siri (spec §5.6 y §7.3.6): solo lo de las categorías con
/// presupuesto se compara contra él; lo de las demás va aparte.
final class ResumenVariables {
  final Dinero gastadoConPresupuesto;
  final Dinero gastadoSinPresupuesto;
  final Dinero presupuesto;

  const ResumenVariables({
    required this.gastadoConPresupuesto,
    required this.gastadoSinPresupuesto,
    required this.presupuesto,
  });

  /// Ninguna variable tiene presupuesto: solo se registra.
  bool get soloRegistro => !presupuesto.esPositivo;

  /// Lo que se muestra como "Llevas gastado".
  Dinero get gastado => soloRegistro ? gastadoSinPresupuesto : gastadoConPresupuesto;

  Dinero get quedan => presupuesto - gastadoConPresupuesto;
}

/// [variables] son las categorías base (activas); [rollupPorCategoria], los
/// del ciclo con los ajustes aplicados (`calcularRollups` sobre
/// `presupuestosEfectivosParaCiclo`).
ResumenVariables resumirVariables(
  Iterable<CategoriaVariable> variables,
  Map<String, Rollup> rollupPorCategoria,
) {
  var con = 0;
  var sin = 0;
  var presupuesto = 0;
  for (final c in variables) {
    final r = rollupPorCategoria[c.id];
    final suyo = (r?.presupuestoCentavos ?? c.presupuestoMensualCentavos).centavos;
    final gastado = r?.totalCentavos.centavos ?? 0;
    presupuesto += suyo;
    if (suyo > 0) {
      con += gastado;
    } else {
      sin += gastado;
    }
  }
  return ResumenVariables(
    gastadoConPresupuesto: Dinero(con),
    gastadoSinPresupuesto: Dinero(sin),
    presupuesto: Dinero(presupuesto),
  );
}
