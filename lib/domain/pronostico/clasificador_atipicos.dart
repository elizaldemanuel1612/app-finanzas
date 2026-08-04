import 'estadistica_robusta.dart';

/// Cómo quedó clasificado un monto individual (modelo-pronostico-ciclo.md
/// §2). Nunca se descarta silenciosamente — todo monto reclasificado debe
/// poder explicarse ("Auto operación incluye $4,000 tratado como evento
/// único…").
enum ClaseMonto {
  /// z ≤ 3.5 — entra completo a Base, se proyecta.
  normal,

  /// 3.5 < z ≤ 6.0 — winsorizado al percentil 95; el exceso pasa a Atípico.
  pico,

  /// z > 6.0 — sale completo de Base, se suma una sola vez como Atípico.
  atipicoFranco,
}

/// Un monto histórico ya clasificado, con cuánto de él quedó en cada
/// balde (para que `Base_c` y `Atípico_c` se puedan sumar directo).
final class MontoClasificado {
  final double montoOriginal;
  final ClaseMonto clase;
  final double aBase;
  final double aAtipico;

  const MontoClasificado({
    required this.montoOriginal,
    required this.clase,
    required this.aBase,
    required this.aAtipico,
  });
}

final class ResultadoClasificacion {
  final double base;
  final double atipico;
  final List<MontoClasificado> detalle;

  const ResultadoClasificacion({
    required this.base,
    required this.atipico,
    required this.detalle,
  });
}

/// Separa una lista de montos históricos (de una sola categoría) en Base
/// y Atípico usando mediana + MAD (§2). Solo winsoriza/excluye montos
/// **por encima** de la mediana — un monto inusualmente bajo no es el
/// problema que este modelo ataca (los eventos únicos caros sí).
ResultadoClasificacion clasificarMontos(List<double> montosHistoricos) {
  if (montosHistoricos.isEmpty) {
    return const ResultadoClasificacion(base: 0, atipico: 0, detalle: []);
  }

  final med = mediana(montosHistoricos);
  final desviacion = mad(montosHistoricos);
  final p95 = percentil(montosHistoricos, 0.95);

  final detalle = <MontoClasificado>[];
  var base = 0.0;
  var atipico = 0.0;

  for (final monto in montosHistoricos) {
    final z = zModificado(monto, mediana: med, mad: desviacion);

    if (z <= 3.5) {
      detalle.add(MontoClasificado(
        montoOriginal: monto,
        clase: ClaseMonto.normal,
        aBase: monto,
        aAtipico: 0,
      ));
      base += monto;
    } else if (z <= 6.0) {
      final winsorizado = monto < p95 ? monto : p95;
      final excedente = monto - winsorizado;
      detalle.add(MontoClasificado(
        montoOriginal: monto,
        clase: ClaseMonto.pico,
        aBase: winsorizado,
        aAtipico: excedente,
      ));
      base += winsorizado;
      atipico += excedente;
    } else {
      detalle.add(MontoClasificado(
        montoOriginal: monto,
        clase: ClaseMonto.atipicoFranco,
        aBase: 0,
        aAtipico: monto,
      ));
      atipico += monto;
    }
  }

  return ResultadoClasificacion(base: base, atipico: atipico, detalle: detalle);
}
