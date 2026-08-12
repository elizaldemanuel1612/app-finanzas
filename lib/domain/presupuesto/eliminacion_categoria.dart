import '../../core/money.dart';
import '../clasificacion/regla_aprendida.dart';
import '../modelos/categoria.dart';
import '../modelos/movimiento.dart';

/// Efecto de intentar eliminar una categoría — jerarquía sellada por la
/// misma razón que [Categoria]: el compilador obliga a la UI a tratar
/// ambas ramas en vez de confiar en que alguien recuerde revisar un `bool`.
sealed class EfectoEliminarCategoria {}

/// No hay historial: se puede borrar de verdad. Trae las cifras que el
/// diálogo debe mostrar antes de confirmar (regla no negociable #20).
final class PuedeEliminarse extends EfectoEliminarCategoria {
  final Dinero presupuestoLiberado;
  final int reglasAprendidasQueSePierden;

  PuedeEliminarse({
    required this.presupuestoLiberado,
    required this.reglasAprendidasQueSePierden,
  });
}

/// Ya tiene movimientos: borrarla los dejaría huérfanos. Solo desactivar.
final class SoloPuedeDesactivarse extends EfectoEliminarCategoria {
  final int movimientos;
  final Dinero totalHistorico;

  SoloPuedeDesactivarse({
    required this.movimientos,
    required this.totalHistorico,
  });
}

/// Decide si [categoria] se puede borrar de verdad o solo desactivar.
///
/// [movimientosDeLaCategoria] debe venir **sin filtrar por estado** —
/// los anulados cuentan también. Un movimiento anulado sigue en disco
/// hasta pasados 30 días (regla no negociable #3) y su historial se tiene
/// que poder leer; si se borra la categoría a la que apunta, queda
/// apuntando a la nada. Es el comportamiento que ya tenía el código
/// anterior a este archivo — se conserva aquí, no se "arregla".
EfectoEliminarCategoria evaluarEliminacionCategoria({
  required Categoria categoria,
  required List<Movimiento> movimientosDeLaCategoria,
  required List<ReglaAprendida> reglasAprendidas,
}) {
  if (movimientosDeLaCategoria.isNotEmpty) {
    return SoloPuedeDesactivarse(
      movimientos: movimientosDeLaCategoria.length,
      totalHistorico: Dinero.suma(movimientosDeLaCategoria.map((m) => m.monto)),
    );
  }

  final presupuestoLiberado = switch (categoria) {
    CategoriaFija f => f.montoFijoCentavos,
    CategoriaVariable v => v.presupuestoMensualCentavos,
  };
  final reglasQueSePierden =
      reglasAprendidas.where((r) => r.categoriaId == categoria.id).length;

  return PuedeEliminarse(
    presupuestoLiberado: presupuestoLiberado,
    reglasAprendidasQueSePierden: reglasQueSePierden,
  );
}
