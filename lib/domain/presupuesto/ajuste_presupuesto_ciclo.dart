import '../../core/money.dart';
import '../modelos/categoria.dart';

/// Ajuste temporal de presupuesto, vigente solo para [cicloId]. Nunca toca
/// `CategoriaVariable.presupuestoMensualCentavos` (la base, permanente para
/// todos los ciclos) — addendum-v3-ajuste-y-ux.md §2.5. Sin `id`: no se
/// edita ni se busca individual, solo se acumula — el presupuesto efectivo
/// de una categoría en un ciclo es la suma de todos sus deltas para ese
/// [cicloId].
final class AjustePresupuestoCiclo {
  final String cicloId;
  final String categoriaId;

  /// Positivo si la categoría recibe presupuesto, negativo si lo presta.
  final Dinero deltaCentavos;
  final DateTime cuando;
  final String dispositivo;

  const AjustePresupuestoCiclo({
    required this.cicloId,
    required this.categoriaId,
    required this.deltaCentavos,
    required this.cuando,
    required this.dispositivo,
  });

  Map<String, dynamic> toJson() => {
        'cicloId': cicloId,
        'categoriaId': categoriaId,
        'deltaCentavos': deltaCentavos.centavos,
        'cuando': cuando.toIso8601String(),
        'dispositivo': dispositivo,
      };

  factory AjustePresupuestoCiclo.fromJson(Map<String, dynamic> json) =>
      AjustePresupuestoCiclo(
        cicloId: json['cicloId'] as String,
        categoriaId: json['categoriaId'] as String,
        deltaCentavos: Dinero(json['deltaCentavos'] as int),
        cuando: DateTime.parse(json['cuando'] as String),
        dispositivo: json['dispositivo'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is AjustePresupuestoCiclo &&
      other.cicloId == cicloId &&
      other.categoriaId == categoriaId &&
      other.deltaCentavos == deltaCentavos &&
      other.cuando == cuando &&
      other.dispositivo == dispositivo;

  @override
  int get hashCode =>
      Object.hash(cicloId, categoriaId, deltaCentavos, cuando, dispositivo);

  @override
  String toString() =>
      'AjustePresupuestoCiclo(ciclo=$cicloId, categoria=$categoriaId, delta=$deltaCentavos)';
}

/// Suma los deltas de un ciclo por categoría.
Map<String, Dinero> sumarDeltasPorCategoria(
  List<AjustePresupuestoCiclo> ajustes,
) {
  final resultado = <String, Dinero>{};
  for (final ajuste in ajustes) {
    resultado[ajuste.categoriaId] =
        (resultado[ajuste.categoriaId] ?? const Dinero.cero()) +
            ajuste.deltaCentavos;
  }
  return resultado;
}

/// Vista derivada (nunca se persiste): presupuesto base + deltas
/// acumulados del ciclo. [CategoriaFija] pasa sin cambios (el rebalanceo
/// nunca la toca). Clampea a 1 centavo en el caso límite defensivo de que
/// un delta deje el presupuesto en ≤ 0 (no debería ocurrir si la UI que
/// arma los ajustes valida bien, pero esta función de lectura nunca debe
/// fallar).
List<Categoria> presupuestosEfectivosParaCiclo({
  required List<Categoria> base,
  required List<AjustePresupuestoCiclo> ajustesDelCiclo,
}) {
  final deltaPorCategoria = sumarDeltasPorCategoria(ajustesDelCiclo);
  return base.map((categoria) {
    if (categoria is! CategoriaVariable) return categoria;
    final delta = deltaPorCategoria[categoria.id];
    if (delta == null || delta.esCero) return categoria;
    final nuevoPresupuesto = categoria.presupuestoMensualCentavos + delta;
    return CategoriaVariable(
      id: categoria.id,
      nombre: categoria.nombre,
      emoji: categoria.emoji,
      activa: categoria.activa,
      esNecesaria: categoria.esNecesaria,
      presupuestoMensualCentavos:
          nuevoPresupuesto.esPositivo ? nuevoPresupuesto : const Dinero(1),
    );
  }).toList();
}
