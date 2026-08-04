import '../../core/money.dart';

/// Agregado precalculado por categoría y ciclo — lo que el dashboard lee en
/// vez de sumar movimientos crudos cada vez (spec-app-finanzas-v2.md §3.1).
/// Espejo de `rollups/{cuentaId}_{cicloId}_{categoriaId}`.
final class Rollup {
  final String categoriaId;
  final String cicloId;
  final Dinero totalCentavos;
  final int conteoMovimientos;

  /// `null` para categorías sin presupuesto variable (las fijas llevan su
  /// monto fijo aquí como referencia, pero la interfaz no les dibuja barra
  /// — spec-app-finanzas-v2.md §1.5, tabla: "Barra de ritmo: No aplica").
  final Dinero? presupuestoCentavos;

  final DateTime ultimaActualizacion;

  const Rollup({
    required this.categoriaId,
    required this.cicloId,
    required this.totalCentavos,
    required this.conteoMovimientos,
    required this.presupuestoCentavos,
    required this.ultimaActualizacion,
  });

  /// Fracción de presupuesto usado (0.5 = 50%). `null` si no hay
  /// presupuesto contra qué medir.
  double? get porcentajeUsado {
    final presupuesto = presupuestoCentavos;
    if (presupuesto == null || presupuesto.esCero) return null;
    return totalCentavos.centavos / presupuesto.centavos;
  }

  @override
  bool operator ==(Object other) =>
      other is Rollup &&
      other.categoriaId == categoriaId &&
      other.cicloId == cicloId &&
      other.totalCentavos == totalCentavos &&
      other.conteoMovimientos == conteoMovimientos &&
      other.presupuestoCentavos == presupuestoCentavos;

  @override
  int get hashCode => Object.hash(
        categoriaId,
        cicloId,
        totalCentavos,
        conteoMovimientos,
        presupuestoCentavos,
      );

  @override
  String toString() =>
      'Rollup($categoriaId/$cicloId: $totalCentavos, $conteoMovimientos mov.)';
}
