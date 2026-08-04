/// Escalera de arranque en frío (modelo-pronostico-ciclo.md §7): el
/// modelo no puede fingir tener datos que no tiene, así que degrada de
/// forma explícita según cuántos ciclos cerrados hay. Cada nivel activa
/// una capa más del modelo — ver `calcularPronosticoCategoria` en
/// `pronostico_categoria.dart` para dónde se usa cada corte.
enum NivelMadurezMpc {
  /// 0 ciclos cerrados — el presupuesto hace de pronóstico.
  sinHistorial,

  /// 1 ciclo — histórico simple, sin estacionalidad.
  historicoSimple,

  /// 2–3 ciclos — + detección de atípicos + factor de credibilidad.
  atipicosYCredibilidad,

  /// 4–6 ciclos — + perfil de día de semana (suavizado).
  conEstacionalidad,

  /// 7+ ciclos — modelo completo, intervalos calibrados.
  completo,
}

NivelMadurezMpc nivelMadurezMpc(int ciclosCerrados) {
  if (ciclosCerrados <= 0) return NivelMadurezMpc.sinHistorial;
  if (ciclosCerrados == 1) return NivelMadurezMpc.historicoSimple;
  if (ciclosCerrados <= 3) return NivelMadurezMpc.atipicosYCredibilidad;
  if (ciclosCerrados <= 6) return NivelMadurezMpc.conEstacionalidad;
  return NivelMadurezMpc.completo;
}

/// Texto exacto de §7 — vacío en el nivel completo porque ahí ya no hace
/// falta ninguna advertencia.
String mensajeNivelMadurez(NivelMadurezMpc nivel) => switch (nivel) {
      NivelMadurezMpc.sinHistorial => 'Sin historial. Mostrando tu presupuesto.',
      NivelMadurezMpc.historicoSimple => 'Pronóstico preliminar, 1 ciclo de historial.',
      NivelMadurezMpc.atipicosYCredibilidad => 'Precisión limitada, mejora cada ciclo.',
      NivelMadurezMpc.conEstacionalidad => 'Pronóstico con estacionalidad.',
      NivelMadurezMpc.completo => '',
    };
