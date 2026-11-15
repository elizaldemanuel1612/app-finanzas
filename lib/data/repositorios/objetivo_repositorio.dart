import '../../domain/modelos/objetivo.dart';

/// Objetivos de ahorro (spec-app-finanzas-v2.md §7.3.3). Se archivan o se
/// eliminan: no tienen historial propio (su avance es el saldo de la
/// cuenta), así que eliminar uno no toca dinero ni movimientos.
abstract interface class ObjetivoRepositorio {
  /// Todos, archivados incluidos, en el orden en que se crearon.
  Future<List<Objetivo>> listarTodos();

  /// Reemplaza el del mismo id, o lo agrega al final.
  Future<void> guardar(Objetivo objetivo);

  /// Lo quita por completo; no hace nada si no existe.
  Future<void> eliminar(String id);
}
