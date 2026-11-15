import '../../core/money.dart';
import '../modelos/categoria.dart';

/// Cómo va una categoría variable en el ciclo: lo gastado y su pronóstico
/// de cierre. **El pronóstico es siempre el P50 del MPC**
/// (`docs/modelo-pronostico-ciclo.md`; lo arma `estadosDeVariables`, en
/// `domain/pronostico/pronostico_del_ciclo.dart`): Inicio, Análisis y el
/// detalle de categoría leen la misma cifra (`docs/rediseno/plan-rediseno.md`,
/// Etapa 0: "una sola verdad").
final class EstadoVariable {
  final CategoriaVariable categoria;
  final Dinero gastado;

  /// Cierre estimado (P50 del MPC); nunca menor que [gastado].
  final Dinero proyeccion;

  const EstadoVariable({required this.categoria, required this.gastado, required this.proyeccion});

  Dinero get presupuesto => categoria.presupuestoMensualCentavos;

  /// Lo que ya se pasó del presupuesto; cero si no se ha pasado o si no
  /// tiene presupuesto (spec §7.3.6: no se juzga).
  Dinero get exceso =>
      !categoria.sinPresupuesto && gastado > presupuesto ? gastado - presupuesto : const Dinero.cero();

  /// Lo que se estima que le sobrará al cierre; cero si no le sobrará.
  Dinero get sobrante => proyeccion < presupuesto ? presupuesto - proyeccion : const Dinero.cero();

  /// Lo que todavía no se gasta: el único límite real para prestar
  /// presupuesto (addendum-v3-ajuste-y-ux.md §2.5, 2026-11-06).
  Dinero get disponible => presupuesto - gastado;
}

/// La salida de una categoría que se pasó (regla #22): de dónde cubrir su
/// exceso.
final class Cobertura {
  final CategoriaVariable categoria;

  /// Lo que ya se pasó (gastado − presupuesto).
  final Dinero exceso;

  /// La categoría con más sobrante estimado que queda; `null` si ninguna
  /// tiene de dónde: entonces todo sale de lo que se aparta.
  final CategoriaVariable? origen;

  /// Cuánto se sugiere mover desde [origen] (cero sin origen).
  final Dinero cubre;

  /// Lo que se estimaba que le sobraría a [origen] antes de esta cobertura.
  final Dinero sobranteOrigen;

  const Cobertura({
    required this.categoria,
    required this.exceso,
    required this.origen,
    required this.cubre,
    required this.sobranteOrigen,
  });

  /// Lo que no alcanza a cubrirse: sale de lo que se aparta.
  Dinero get falta => exceso - cubre;

  /// Lo que le quedará de sobra a [origen] después de mover [cubre].
  Dinero get sobranteDespues => sobranteOrigen - cubre;

  /// La salida en una frase (regla 1 · 6 · 12 de
  /// `docs/rediseno/design-system/README.md`). La misma en Inicio, Análisis
  /// y el detalle de categoría.
  String get frase {
    final o = origen;
    if (o == null) return 'Ninguna categoría tiene de dónde: sale de lo que apartas.';
    if (falta.esPositivo) {
      return '${o.nombre} cubre ${cubre.formateado()}; los ${falta.formateado()} restantes salen de lo que apartas.';
    }
    return 'Mueve ${cubre.formateado()} desde ${o.nombre}: le sobrarán ${sobranteDespues.formateado()}.';
  }
}

/// **El único motor de "de dónde cubro lo que me pasé"**
/// (`docs/rediseno/plan-rediseno.md`, Etapa 0; addendum-v3 §2.5): Inicio
/// (banner), Análisis (Qué hacer) y el detalle de categoría muestran lo
/// mismo porque todos llaman aquí.
///
/// Las categorías que se pasaron van de mayor a menor exceso; a cada una
/// se le asigna la categoría con más sobrante estimado (MPC) que quede, y
/// ese sobrante se consume: el mismo dinero no se ofrece dos veces. Si el
/// sobrante no alcanza, cubre una parte y el resto queda en [Cobertura.falta].
List<Cobertura> calcularCoberturas(List<EstadoVariable> estados) {
  final sobrante = {
    for (final e in estados)
      if (e.sobrante.esPositivo) e.categoria.id: e.sobrante,
  };
  final porId = {for (final e in estados) e.categoria.id: e.categoria};
  final excedidas = [
    for (final e in estados)
      if (e.exceso.esPositivo) e,
  ]..sort((a, b) => b.exceso.compareTo(a.exceso));

  return [
    for (final e in excedidas) _cubrir(e, sobrante, porId),
  ];
}

Cobertura _cubrir(EstadoVariable e, Map<String, Dinero> sobrante, Map<String, CategoriaVariable> porId) {
  String? mejor;
  for (final s in sobrante.entries) {
    if (!s.value.esPositivo) continue;
    if (mejor == null || s.value > sobrante[mejor]!) mejor = s.key;
  }
  if (mejor == null) {
    return Cobertura(
      categoria: e.categoria,
      exceso: e.exceso,
      origen: null,
      cubre: const Dinero.cero(),
      sobranteOrigen: const Dinero.cero(),
    );
  }
  final disponible = sobrante[mejor]!;
  final cubre = e.exceso < disponible ? e.exceso : disponible;
  sobrante[mejor] = disponible - cubre;
  return Cobertura(
    categoria: e.categoria,
    exceso: e.exceso,
    origen: porId[mejor],
    cubre: cubre,
    sobranteOrigen: disponible,
  );
}
