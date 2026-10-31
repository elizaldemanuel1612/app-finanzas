import '../../domain/modelos/categoria.dart';

abstract interface class CategoriaRepositorio {
  Future<void> guardar(Categoria categoria);

  Future<List<Categoria>> listarActivas();

  Future<List<Categoria>> listarTodas();

  Future<Categoria?> buscarPorId(String id);

  /// Borra la categoría por completo. Solo debe llamarse cuando ya se
  /// confirmó que ningún movimiento la referencia — a diferencia de un
  /// movimiento (que nunca se borra, solo se anula), una categoría sin
  /// historial no tiene nada que auditar.
  Future<void> eliminar(String id);

  /// Deja exactamente [categorias]: solo para importar un archivo
  /// (spec-app-finanzas-v2.md §7.4).
  Future<void> reemplazarTodas(List<Categoria> categorias);
}
