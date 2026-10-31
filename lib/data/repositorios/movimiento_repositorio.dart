import '../../domain/modelos/movimiento.dart';

/// Contrato para persistir y consultar movimientos. La implementación de
/// hoy escribe a un archivo local (data/repositorios/local/); cuando el
/// proyecto Firebase esté listo, una implementación respaldada por
/// Firestore cumple el mismo contrato sin que domain/ ni ui/ se enteren.
abstract interface class MovimientoRepositorio {
  /// Guarda un movimiento nuevo. Si ya existe uno con el mismo `clientId`,
  /// lo ignora (regla no negociable #2: idempotencia) y regresa el que ya
  /// estaba guardado.
  Future<Movimiento> guardar(Movimiento movimiento);

  /// Reemplaza un movimiento existente (por `id`). Falla si no existe.
  Future<void> actualizar(Movimiento movimiento);

  /// Marca un movimiento como [EstadoMovimiento.anulado] (por `id`). Falla
  /// si no existe. Es el único "borrado" que existe (regla no negociable
  /// #3) — nunca elimina el registro.
  Future<void> anular(String id);

  /// Deja exactamente [movimientos]. Única excepción a la regla #3: solo
  /// para importar un archivo, ya confirmado por el usuario
  /// (spec-app-finanzas-v2.md §7.4).
  Future<void> reemplazarTodos(List<Movimiento> movimientos);

  Future<List<Movimiento>> listarPorCiclo(String cicloId);

  /// Todos los movimientos de una categoría, sin filtrar por estado — los
  /// anulados cuentan también (ver eliminacion_categoria.dart).
  Future<List<Movimiento>> listarPorCategoria(String categoriaId);

  Future<List<Movimiento>> listarTodos();

  Future<bool> existeClientId(String clientId);
}
