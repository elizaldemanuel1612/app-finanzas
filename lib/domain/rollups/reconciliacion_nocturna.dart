import '../../core/money.dart';
import 'rollup.dart';

/// Desfase encontrado entre un rollup guardado y lo que da recalcularlo
/// desde los movimientos crudos (spec-app-finanzas-v2.md §3.3).
final class DiferenciaRollup {
  final String categoriaId;
  final Dinero totalGuardado;
  final Dinero totalRecalculado;

  const DiferenciaRollup({
    required this.categoriaId,
    required this.totalGuardado,
    required this.totalRecalculado,
  });

  Dinero get diferencia => totalRecalculado - totalGuardado;

  @override
  String toString() => '$categoriaId: guardado=${totalGuardado.formateado()} '
      'recalculado=${totalRecalculado.formateado()} '
      '(diferencia ${diferencia.formateado()})';
}

/// Compara los rollups guardados contra una recalculación fresca desde los
/// movimientos crudos. Vacío significa que todo cuadra — que es lo que le
/// da a la app la certeza de que las cifras del dashboard son las reales
/// (spec-app-finanzas-v2.md §3.3).
///
/// Una categoría presente en [recalculados] pero no en [guardados] (rollup
/// nunca creado) también se reporta — es la señal de que algo no está
/// manteniendo el rollup al día.
List<DiferenciaRollup> encontrarDesfaseRollups({
  required List<Rollup> guardados,
  required List<Rollup> recalculados,
}) {
  final guardadosPorCategoria = {for (final r in guardados) r.categoriaId: r};
  final recalculadosPorCategoria = {
    for (final r in recalculados) r.categoriaId: r,
  };

  final todasLasCategorias = {
    ...guardadosPorCategoria.keys,
    ...recalculadosPorCategoria.keys,
  };

  final diferencias = <DiferenciaRollup>[];
  for (final categoriaId in todasLasCategorias) {
    final totalGuardado =
        guardadosPorCategoria[categoriaId]?.totalCentavos ?? const Dinero.cero();
    final totalRecalculado =
        recalculadosPorCategoria[categoriaId]?.totalCentavos ?? const Dinero.cero();
    if (totalGuardado != totalRecalculado) {
      diferencias.add(DiferenciaRollup(
        categoriaId: categoriaId,
        totalGuardado: totalGuardado,
        totalRecalculado: totalRecalculado,
      ));
    }
  }
  return diferencias;
}
