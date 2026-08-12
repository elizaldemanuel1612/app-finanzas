import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';
import '../pronostico/pronostico_categoria.dart';
import 'ajuste_presupuesto_ciclo.dart';

/// Una categoría con holgura proyectada (addendum-v3-ajuste-y-ux.md §2.5):
/// `Holgura_c = Presupuesto_c − Pronóstico_c`, solo cuando es positiva.
final class CandidataRebalanceo {
  final CategoriaVariable categoria;
  final Dinero holgura;

  const CandidataRebalanceo({required this.categoria, required this.holgura});
}

/// Sugerencia de rebalanceo para una categoría que ya se pasó del
/// presupuesto y no tiene forma de recuperar dentro de ella misma — el
/// Plan de Ajuste (`plan_de_ajuste.dart`) ya no alcanza.
final class Rebalanceo {
  final String categoriaObjetivoId;

  /// Cuánto le falta a la categoría objetivo para cubrir lo que el MPC
  /// proyecta que va a costar el resto del ciclo.
  final Dinero faltante;

  /// Las 3 categorías con más holgura, de mayor a menor (§2.5: "se
  /// ofrecen las 3 mayores").
  final List<CandidataRebalanceo> candidatas;

  const Rebalanceo({
    required this.categoriaObjetivoId,
    required this.faltante,
    required this.candidatas,
  });
}

/// `null` si no aplica: la categoría objetivo todavía no se pasó de su
/// presupuesto ("no hay forma de recuperar dentro de ella" implica que
/// ya se pasó — spec §2.5), o el pronóstico no proyecta faltante alguno.
///
/// No excluye categorías `esNecesaria` de la lista de candidatas: el
/// guardarraíl de "piso digno" (§2.6) protege el *plan de ajuste* (no
/// pedirle a alguien que gaste menos en Súper), no impide que una
/// categoría necesaria que de verdad va a subejercer su presupuesto
/// preste esa holgura — el número ya viene de una proyección real, no
/// de un recorte forzado.
Rebalanceo? calcularRebalanceo({
  required CategoriaVariable categoriaObjetivo,
  required PronosticoCategoria pronosticoObjetivo,
  required List<CategoriaVariable> otrasCategorias,
  required List<PronosticoCategoria> otrosPronosticos,
}) {
  final presupuestoObjetivo = categoriaObjetivo.presupuestoMensualCentavos.centavos;
  if (pronosticoObjetivo.observado.centavos <= presupuestoObjetivo) return null;

  final faltanteCentavos = pronosticoObjetivo.pronosticoP50.centavos - presupuestoObjetivo;
  if (faltanteCentavos <= 0) return null;

  final pronosticoPorId = {for (final p in otrosPronosticos) p.categoriaId: p};
  final candidatas = <CandidataRebalanceo>[];
  for (final c in otrasCategorias) {
    if (c.id == categoriaObjetivo.id) continue;
    final pronostico = pronosticoPorId[c.id];
    if (pronostico == null) continue;
    final holguraCentavos = c.presupuestoMensualCentavos.centavos - pronostico.pronosticoP50.centavos;
    if (holguraCentavos > 0) {
      candidatas.add(CandidataRebalanceo(categoria: c, holgura: Dinero(holguraCentavos)));
    }
  }
  candidatas.sort((a, b) => b.holgura.centavos.compareTo(a.holgura.centavos));

  return Rebalanceo(
    categoriaObjetivoId: categoriaObjetivo.id,
    faltante: Dinero(faltanteCentavos),
    candidatas: candidatas.take(3).toList(),
  );
}

/// Cuánto presupuesto mover desde una categoría origen — el usuario
/// decide el monto, nunca se rebalancea solo (§2.5).
final class MovimientoRebalanceo {
  final String categoriaOrigenId;
  final Dinero monto;

  const MovimientoRebalanceo({required this.categoriaOrigenId, required this.monto});
}

/// Construye los [AjustePresupuestoCiclo] de un rebalanceo temporal:
/// nunca produce una [CategoriaVariable] nueva, solo deltas — quien llama
/// nunca tiene la tentación de persistir con `CategoriaRepositorio`.
///
/// Cada monto debe ser positivo y no exceder la holgura de su candidata.
/// El límite es por candidata, no por suma — permite sobre-cubrir el
/// total si el usuario así lo decide.
Resultado<List<AjustePresupuestoCiclo>> construirAjustesDeRebalanceo({
  required Rebalanceo rebalanceo,
  required List<MovimientoRebalanceo> movimientos,
  required String cicloId,
  required DateTime cuando,
  required String dispositivo,
}) {
  if (movimientos.isEmpty) {
    return const Falla('Ingresa al menos un monto a mover.');
  }

  final candidatasPorId = {
    for (final c in rebalanceo.candidatas) c.categoria.id: c,
  };
  var totalCentavos = 0;
  final ajustes = <AjustePresupuestoCiclo>[];

  for (final mov in movimientos) {
    if (!mov.monto.esPositivo) {
      return Falla('El monto a mover desde ${mov.categoriaOrigenId} debe ser mayor a cero.');
    }
    final candidata = candidatasPorId[mov.categoriaOrigenId];
    if (candidata == null) {
      return Falla('No se encontró la categoría candidata ${mov.categoriaOrigenId}.');
    }
    if (mov.monto > candidata.holgura) {
      return Falla(
        '${candidata.categoria.nombre} no tiene suficiente holgura para mover ${mov.monto.formateado()}.',
      );
    }

    ajustes.add(AjustePresupuestoCiclo(
      cicloId: cicloId,
      categoriaId: mov.categoriaOrigenId,
      deltaCentavos: -mov.monto,
      cuando: cuando,
      dispositivo: dispositivo,
    ));
    totalCentavos += mov.monto.centavos;
  }

  ajustes.add(AjustePresupuestoCiclo(
    cicloId: cicloId,
    categoriaId: rebalanceo.categoriaObjetivoId,
    deltaCentavos: Dinero(totalCentavos),
    cuando: cuando,
    dispositivo: dispositivo,
  ));

  return Exito(ajustes);
}
