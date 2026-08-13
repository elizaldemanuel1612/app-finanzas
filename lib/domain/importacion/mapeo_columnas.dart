import '../clasificacion/normalizacion_texto.dart';

/// Campo del dominio al que puede corresponder una columna del CSV
/// importado.
enum CampoImportado { fecha, monto, categoria, descripcion, medio }

const _aliasPorCampo = {
  CampoImportado.fecha: ['fecha', 'date', 'fec'],
  CampoImportado.monto: ['monto', 'importe', 'cantidad', 'total'],
  CampoImportado.categoria: ['categoria', 'rubro'],
  CampoImportado.descripcion: ['descripcion', 'concepto', 'comercio'],
  CampoImportado.medio: ['medio', 'forma de pago'],
};

/// A qué índice de columna corresponde cada [CampoImportado] detectado —
/// un campo ausente del CSV simplemente no aparece en el mapa.
final class MapeoColumnas {
  final Map<CampoImportado, int> indicePorCampo;

  const MapeoColumnas(this.indicePorCampo);

  int? operator [](CampoImportado campo) => indicePorCampo[campo];

  /// Mínimo para poder importar algo: fecha y monto (`app-finanzas-
  /// onboarding-INTERACTIVO.html`, `L.importable`).
  bool get esImportable =>
      indicePorCampo.containsKey(CampoImportado.fecha) &&
      indicePorCampo.containsKey(CampoImportado.monto);
}

/// Detecta a qué campo corresponde cada encabezado por coincidencia de
/// alias, normalizando acentos/mayúsculas primero (mismos alias que el
/// prototipo interactivo). La primera columna que matchea un alias gana —
/// si dos columnas calzan con el mismo campo, se usa la primera.
MapeoColumnas detectarColumnas(List<String> encabezados) {
  final normalizados = encabezados.map(normalizarTexto).toList();
  final indicePorCampo = <CampoImportado, int>{};

  for (final campo in CampoImportado.values) {
    final alias = _aliasPorCampo[campo]!;
    for (var i = 0; i < normalizados.length; i++) {
      if (alias.any((a) => normalizados[i].contains(a))) {
        indicePorCampo[campo] = i;
        break;
      }
    }
  }

  return MapeoColumnas(indicePorCampo);
}
