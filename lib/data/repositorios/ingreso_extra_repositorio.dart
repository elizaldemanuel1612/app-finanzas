import '../../domain/modelos/ingreso_extra.dart';

/// Contrato para persistir ingresos extra. Sin `eliminar`: la regla no
/// negociable #3 exige anular, nunca borrar físicamente.
abstract interface class IngresoExtraRepositorio {
  /// Reemplaza el ingreso con el mismo id, o lo agrega si es nuevo.
  Future<IngresoExtra> guardar(IngresoExtra ingreso);

  Future<List<IngresoExtra>> listarPorCiclo(String cicloId);

  Future<List<IngresoExtra>> listarTodos();

  Future<void> anular(String id);
}
