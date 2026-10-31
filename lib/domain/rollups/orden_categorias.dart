import '../modelos/categoria.dart';
import 'rollup.dart';

/// Cómo ordenar las categorías en Inicio, siempre de mayor a menor
/// (spec-app-finanzas-v2.md §5.6).
enum OrdenCategorias {
  /// Qué tanto del presupuesto ya se consumió.
  porcentajeUsado,

  /// Cuánto dinero se ha gastado.
  dineroGastado,
}

/// Copia ordenada de [categorias] según [orden]. Lo gastado sin presupuesto
/// contra qué medir va primero en [OrdenCategorias.porcentajeUsado]: es lo
/// más pasado de todo. Los empates se resuelven por el otro criterio y luego
/// por nombre, para que la lista no cambie de lugar entre recargas.
List<T> ordenarCategorias<T extends Categoria>(
  List<T> categorias,
  Map<String, Rollup> rollups,
  OrdenCategorias orden,
) {
  int gastado(T c) => rollups[c.id]?.totalCentavos.centavos ?? 0;
  double usado(T c) {
    final porcentaje = rollups[c.id]?.porcentajeUsado;
    if (porcentaje != null) return porcentaje;
    return gastado(c) > 0 ? double.infinity : 0;
  }

  int porUsado(T a, T b) => usado(b).compareTo(usado(a));
  int porGastado(T a, T b) => gastado(b).compareTo(gastado(a));
  final primero = orden == OrdenCategorias.porcentajeUsado ? porUsado : porGastado;
  final segundo = orden == OrdenCategorias.porcentajeUsado ? porGastado : porUsado;

  return [...categorias]
    ..sort((a, b) {
      final uno = primero(a, b);
      if (uno != 0) return uno;
      final dos = segundo(a, b);
      return dos != 0 ? dos : a.nombre.compareTo(b.nombre);
    });
}
