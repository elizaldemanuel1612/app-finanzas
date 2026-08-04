import '../../domain/clasificacion/regla_aprendida.dart';

/// Persiste el Nivel 1 de la cascada de clasificación (spec-app-finanzas-
/// v2.md §6.2) — las reglas que el usuario ha ido confirmando con sus
/// correcciones.
abstract interface class ReglasAprendidasRepositorio {
  Future<List<ReglaAprendida>> listarTodas();

  /// Reemplaza el archivo completo — quien llama ya calculó la lista
  /// actualizada con [registrarCorreccion].
  Future<void> guardarTodas(List<ReglaAprendida> reglas);
}
