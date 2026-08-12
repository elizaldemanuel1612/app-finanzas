import '../../core/result.dart';
import '../modelos/categoria.dart';
import '../modelos/movimiento.dart';

/// Mueve [movimiento] a [destino] — paso previo para poder eliminar de
/// verdad una categoría con historial (ver `eliminacion_categoria.dart`).
/// Falla si el destino es la misma categoría de origen (no sería una
/// reasignación) o si está desactivada (trasladaría el problema a una
/// categoría archivada en vez de resolverlo).
Resultado<Movimiento> reasignarMovimiento({
  required Movimiento movimiento,
  required Categoria destino,
}) {
  if (destino.id == movimiento.categoriaId) {
    return const Falla('El movimiento ya pertenece a esa categoría.');
  }
  if (!destino.activa) {
    return Falla('${destino.nombre} está desactivada; elige otra categoría.');
  }
  return Exito(movimiento.copyWith(categoriaId: destino.id));
}
