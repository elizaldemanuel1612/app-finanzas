import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';
import 'ajuste_presupuesto_ciclo.dart';
import 'cobertura_excesos.dart';

/// Una categoría con holgura proyectada (addendum-v3-ajuste-y-ux.md §2.5):
/// `Holgura_c = Presupuesto_c − Pronóstico_c`, solo cuando es positiva.
final class CandidataRebalanceo {
  final CategoriaVariable categoria;

  /// Lo que se estima que le sobrará al cierre: la **sugerencia** de cuánto
  /// mover, no un límite (2026-11-06).
  final Dinero holgura;

  /// Lo que todavía no se ha gastado (`Presupuesto_c − Gastado_c`): el
  /// único límite real. Mover más que la holgura se permite; mover más de
  /// lo disponible dejaría la categoría en negativo.
  final Dinero disponible;

  const CandidataRebalanceo({required this.categoria, required this.holgura, required this.disponible});

  /// Se pidió mover más de lo sugerido (pero dentro de lo disponible).
  bool excedeSugerencia(Dinero monto) => monto > holgura;
}

/// Sugerencia de rebalanceo para una categoría que ya se pasó del
/// presupuesto y no tiene forma de recuperar dentro de ella misma — el
/// Plan de Ajuste (`plan_de_ajuste.dart`) ya no alcanza.
final class Rebalanceo {
  final String categoriaObjetivoId;

  /// Lo que ya se pasó la categoría objetivo (gastado − presupuesto): la
  /// misma cifra que "Te pasaste por $X" y que el exceso de
  /// `calcularCoberturas` (`docs/rediseno/plan-rediseno.md`, Etapa 0: una
  /// sola recomendación por problema). Antes era el faltante proyectado
  /// por el MPC, y el detalle y Análisis sugerían montos distintos.
  final Dinero faltante;

  /// Las 3 categorías con más holgura, de mayor a menor (§2.5: "se
  /// ofrecen las 3 mayores"). La holgura es el mismo sobrante (presupuesto
  /// − P50 del MPC) que usa `calcularCoberturas`, con el mismo orden.
  final List<CandidataRebalanceo> candidatas;

  const Rebalanceo({
    required this.categoriaObjetivoId,
    required this.faltante,
    required this.candidatas,
  });
}

/// `null` si no aplica: la categoría objetivo todavía no se pasó de su
/// presupuesto ("no hay forma de recuperar dentro de ella" implica que
/// ya se pasó — spec §2.5).
///
/// No excluye categorías `esNecesaria` de la lista de candidatas: el
/// guardarraíl de "piso digno" (§2.6) protege el *plan de ajuste* (no
/// pedirle a alguien que gaste menos en Súper), no impide que una
/// categoría necesaria que de verdad va a subejercer su presupuesto
/// preste esa holgura — el número ya viene de una proyección real, no
/// de un recorte forzado.
Rebalanceo? calcularRebalanceo({
  required EstadoVariable objetivo,
  required List<EstadoVariable> otras,
}) {
  if (!objetivo.exceso.esPositivo) return null;
  final candidatas = [
    for (final e in otras)
      if (e.categoria.id != objetivo.categoria.id && e.sobrante.esPositivo)
        CandidataRebalanceo(
          categoria: e.categoria,
          holgura: e.sobrante,
          // El cierre estimado nunca queda por debajo de lo gastado, así que
          // disponible ≥ holgura > 0.
          disponible: e.disponible,
        ),
  ]..sort((a, b) => b.holgura.compareTo(a.holgura));

  return Rebalanceo(
    categoriaObjetivoId: objetivo.categoria.id,
    faltante: objetivo.exceso,
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
/// Cada monto debe ser positivo y no exceder lo **disponible** de su
/// candidata (lo que aún no gasta). La holgura proyectada es solo una
/// sugerencia: el usuario puede mover más si así lo decide (2026-11-06).
/// El límite es por candidata, no por suma — permite sobre-cubrir el
/// total.
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
    if (mov.monto > candidata.disponible) {
      return Falla(
        '${candidata.categoria.nombre} solo tiene ${candidata.disponible.formateado()} sin gastar; '
        'no se pueden mover ${mov.monto.formateado()}.',
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
