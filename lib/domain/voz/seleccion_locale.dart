/// Elige, de la lista de `localeId` que reporta el motor de reconocimiento
/// de voz del sistema, cuál usar para el dictado (Fase 6, Bloque 4.5).
///
/// `hoja_dictado.dart` tomaba el **primer** locale que empezara con "es"
/// — en un dispositivo cuyo sistema reporte `es-ES` antes que `es-MX`, el
/// dictado usaba el motor de español de España mientras
/// `domain/voz/parser_dictado.dart` está afinado para es-MX. Preferencia,
/// de más a menos específica:
/// 1. `es_MX` / `es-MX` (exacto, sin importar mayúsculas ni separador).
/// 2. `es_419` (español latinoamericano genérico).
/// 3. Cualquier locale que empiece con "es".
/// 4. `null` si no hay ninguno en español — quien llama decide qué hacer
///    (hoy: dictar sin `localeId`, dejando que el sistema use su default).
String? seleccionarLocaleDictado(List<String> localesDisponibles) {
  String normalizado(String id) => id.toLowerCase().replaceAll('-', '_');

  for (final id in localesDisponibles) {
    if (normalizado(id) == 'es_mx') return id;
  }
  for (final id in localesDisponibles) {
    if (normalizado(id) == 'es_419') return id;
  }
  for (final id in localesDisponibles) {
    if (normalizado(id).startsWith('es')) return id;
  }
  return null;
}
