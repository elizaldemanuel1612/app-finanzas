import '../../domain/modelos/categoria_ingreso.dart';

/// Categorías de ingreso (spec-app-finanzas-v2.md §7.3.4). Sin `eliminar`:
/// se archivan.
abstract interface class CategoriaIngresoRepositorio {
  /// Todas, archivadas incluidas, en el orden en que se crearon. La primera
  /// vez (nada guardado) crea y regresa las sugeridas.
  Future<List<CategoriaIngreso>> listarTodas();

  /// Reemplaza la del mismo id, o la agrega al final.
  Future<void> guardar(CategoriaIngreso categoria);
}
