import 'normalizacion_texto.dart';

/// Un movimiento pasado, reducido a lo que el Nivel 2 de la cascada
/// necesita: qué se escribió y en qué categoría quedó.
final class ObservacionComercio {
  final String descripcion;
  final String categoriaId;

  const ObservacionComercio(this.descripcion, this.categoriaId);
}

/// Nivel 2 de la cascada (spec-app-finanzas-v2.md §6.1): "¿ya
/// clasificaste este comercio antes? Si sí, se aplica la misma categoría
/// automáticamente". Construye comercio-normalizado → categoría más
/// frecuente entre las observaciones — la más frecuente, no la más
/// reciente, para que una corrección aislada no tumbe un patrón ya
/// establecido con muchas confirmaciones.
Map<String, String> construirHistorialComercios(List<ObservacionComercio> observaciones) {
  final conteos = <String, Map<String, int>>{};
  for (final obs in observaciones) {
    final comercio = normalizarTexto(obs.descripcion);
    if (comercio.isEmpty) continue;
    final porCategoria = conteos.putIfAbsent(comercio, () => {});
    porCategoria[obs.categoriaId] = (porCategoria[obs.categoriaId] ?? 0) + 1;
  }

  final resultado = <String, String>{};
  for (final entrada in conteos.entries) {
    String? mejorCategoria;
    var mejorConteo = 0;
    for (final par in entrada.value.entries) {
      if (par.value > mejorConteo) {
        mejorConteo = par.value;
        mejorCategoria = par.key;
      }
    }
    if (mejorCategoria != null) resultado[entrada.key] = mejorCategoria;
  }
  return resultado;
}
