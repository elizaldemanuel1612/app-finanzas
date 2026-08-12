import '../../domain/modelos/ciclo_guardado.dart';

/// Contrato para persistir ciclos ya cerrados o reabiertos. Un ciclo que
/// nunca se cerró no vive aquí — se sigue derivando al vuelo con
/// `CalculadoraCiclo` (ver `CicloGuardado`).
abstract interface class CicloRepositorio {
  Future<CicloGuardado?> buscarPorId(String id);

  Future<List<CicloGuardado>> listarTodos();

  /// Reemplaza el ciclo guardado con el mismo id, o lo agrega si es nuevo.
  Future<void> guardar(CicloGuardado guardado);
}
