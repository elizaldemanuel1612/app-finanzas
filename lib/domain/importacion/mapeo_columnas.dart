import '../clasificacion/normalizacion_texto.dart';

/// Campo del dominio al que puede corresponder una columna del CSV
/// importado.
///
/// El orden importa: una columna ya tomada no se reusa, así que "Emoji de
/// categoría" o "Tipo de categoría" no se confunden con la categoría.
enum CampoImportado {
  fecha,
  monto,
  emoji,
  presupuesto,
  tipo,
  diaDeCobro,
  necesaria,
  activa,
  categoria,
  descripcion,
  medio,
  estado,
  origen,
  id,
}

/// Se reconoce la columna si su encabezado *contiene* el alias.
const _aliasPorCampo = {
  CampoImportado.fecha: ['fecha', 'date', 'fec'],
  CampoImportado.monto: ['monto', 'importe', 'cantidad', 'total'],
  CampoImportado.emoji: ['emoji', 'icono'],
  CampoImportado.presupuesto: ['presupuesto'],
  CampoImportado.tipo: ['tipo'],
  CampoImportado.diaDeCobro: ['dia de cobro', 'dia del ciclo'],
  CampoImportado.necesaria: ['necesaria'],
  CampoImportado.categoria: ['categoria', 'rubro'],
  CampoImportado.descripcion: ['descripcion', 'concepto', 'comercio'],
  CampoImportado.medio: ['medio', 'forma de pago'],
  CampoImportado.estado: ['estado', 'estatus', 'status'],
  CampoImportado.origen: ['como se registro', 'origen'],
};

/// Alias cortos que solo cuentan si son el encabezado completo: "id"
/// aparece dentro de muchas palabras.
const _aliasExactosPorCampo = {
  CampoImportado.id: ['id', 'clientid'],
  CampoImportado.activa: ['activa'],
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
/// si dos columnas calzan con el mismo campo, se usa la primera. Una
/// columna ya tomada no se reusa para otro campo (así "Emoji de categoría"
/// es el emoji y no la categoría).
MapeoColumnas detectarColumnas(List<String> encabezados) {
  final normalizados = encabezados.map((e) => normalizarTexto(e).trim()).toList();
  final indicePorCampo = <CampoImportado, int>{};
  final tomadas = <int>{};

  for (final campo in CampoImportado.values) {
    final contiene = _aliasPorCampo[campo] ?? const [];
    final exactos = _aliasExactosPorCampo[campo] ?? const [];
    for (var i = 0; i < normalizados.length; i++) {
      if (tomadas.contains(i)) continue;
      if (contiene.any(normalizados[i].contains) || exactos.contains(normalizados[i])) {
        indicePorCampo[campo] = i;
        tomadas.add(i);
        break;
      }
    }
  }

  return MapeoColumnas(indicePorCampo);
}
