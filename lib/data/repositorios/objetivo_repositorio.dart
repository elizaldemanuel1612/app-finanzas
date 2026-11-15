import '../../domain/modelos/objetivo.dart';

/// Objetivos de ahorro (spec-app-finanzas-v2.md §7.3.3). Sin `eliminar`:
/// se archivan.
abstract interface class ObjetivoRepositorio {
  /// Todos, archivados incluidos, en el orden en que se crearon.
  Future<List<Objetivo>> listarTodos();

  /// Reemplaza el del mismo id, o lo agrega al final.
  Future<void> guardar(Objetivo objetivo);
}
