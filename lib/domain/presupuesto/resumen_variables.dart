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

  /// Lo pagado en categorías fijas. Solo entra en [gastado] cuando no hay
  /// presupuestos: entonces se muestra todo lo gastado del ciclo.
  final Dinero gastadoFijas;

  const ResumenVariables({
    required this.gastadoConPresupuesto,
    required this.gastadoSinPresupuesto,
    required this.presupuesto,
    this.gastadoFijas = const Dinero.cero(),
  });

  /// Ninguna variable tiene presupuesto: solo se registra.
  bool get soloRegistro => !presupuesto.esPositivo;

  /// Lo que se muestra como "Llevas gastado": contra el presupuesto, lo de
  /// las variables con él; sin ningún presupuesto (2026-11-16), todo lo
  /// gastado del ciclo, fijas incluidas.
  Dinero get gastado => soloRegistro ? gastadoSinPresupuesto + gastadoFijas : gastadoConPresupuesto;

  Dinero get quedan => presupuesto - gastadoConPresupuesto;
}

/// [variables] son las categorías base (activas); [rollupPorCategoria], los
/// del ciclo con los ajustes aplicados (`calcularRollups` sobre
/// `presupuestosEfectivosParaCiclo`); [fijas], las fijas activas.
ResumenVariables resumirVariables(
  Iterable<CategoriaVariable> variables,
  Map<String, Rollup> rollupPorCategoria, {
  Iterable<CategoriaFija> fijas = const [],
}) {
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
    gastadoFijas: Dinero.suma([
      for (final c in fijas) rollupPorCategoria[c.id]?.totalCentavos ?? const Dinero.cero(),
    ]),
  );
}
