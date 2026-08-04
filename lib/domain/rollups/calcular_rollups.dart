import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'rollup.dart';

/// Calcula un [Rollup] por cada categoría activa para un ciclo dado.
///
/// Los movimientos `anulados` no cuentan (regla no negociable #3), y los
/// `propuestos` tampoco (regla #18: lo generado por el sistema no cuenta
/// hasta que el usuario lo confirma).
///
/// Hoy esto se recalcula al vuelo desde `MovimientoRepositorio` porque los
/// datos son locales y la lectura es barata. El día que haya Firestore de
/// por medio, esta misma función es la que corre en la Cloud Function que
/// mantiene `rollups/` — no cambia, solo cambia quién la llama y cuándo.
List<Rollup> calcularRollups({
  required List<Movimiento> movimientos,
  required List<Categoria> categorias,
  required String cicloId,
  DateTime? ahora,
}) {
  final momento = ahora ?? DateTime.now();

  final porCategoria = <String, List<Movimiento>>{};
  for (final m in movimientos) {
    if (m.cicloId != cicloId) continue;
    if (m.estado != EstadoMovimiento.activo) continue;
    porCategoria.putIfAbsent(m.categoriaId, () => []).add(m);
  }

  return [
    for (final categoria in categorias)
      Rollup(
        categoriaId: categoria.id,
        cicloId: cicloId,
        totalCentavos: Dinero.suma(
          (porCategoria[categoria.id] ?? const []).map((m) => m.monto),
        ),
        conteoMovimientos: (porCategoria[categoria.id] ?? const []).length,
        presupuestoCentavos: switch (categoria) {
          CategoriaFija f => f.montoFijoCentavos,
          CategoriaVariable v => v.presupuestoMensualCentavos,
        },
        ultimaActualizacion: momento,
      ),
  ];
}
