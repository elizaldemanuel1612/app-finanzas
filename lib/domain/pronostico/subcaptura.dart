/// Control de subcaptura (modelo-pronostico-ciclo.md §8): un pronóstico
/// bajo puede significar que gastaste poco... o que dejaste de capturar.
/// Sin esto, el modelo premia con optimismo justo cuando dejaste de
/// registrar — el peor incentivo posible.
enum SenalSubcaptura {
  /// densidad ≥ 0.75 — todo normal.
  normal,

  /// 0.40 ≤ densidad < 0.75 — "Llevas menos movimientos de lo habitual.
  /// ¿Falta capturar algo?"
  bandera,

  /// densidad < 0.40 — el pronóstico se marca no confiable y debe
  /// apoyarse en histórico, no en lo observado del ciclo actual.
  noConfiable,
}

/// `densidad = movimientos_observados ÷ movimientos_esperados`.
/// [movimientosEsperados] ya viene ajustado por `p_c` (avance efectivo)
/// por quien llama — sin suficiente base de comparación (0 esperados,
/// típico en categorías Tipo C con poco historial) se asume normal: no
/// hay con qué comparar, no hay señal que dar.
SenalSubcaptura calcularSenalSubcaptura({
  required int movimientosObservados,
  required double movimientosEsperados,
}) {
  if (movimientosEsperados <= 0) return SenalSubcaptura.normal;
  final densidad = movimientosObservados / movimientosEsperados;
  if (densidad >= 0.75) return SenalSubcaptura.normal;
  if (densidad >= 0.40) return SenalSubcaptura.bandera;
  return SenalSubcaptura.noConfiable;
}
