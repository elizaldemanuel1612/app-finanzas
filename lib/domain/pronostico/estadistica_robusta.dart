/// Estadística robusta (mediana, MAD, z-modificado) — modelo-pronostico-
/// ciclo.md §2. Media y desviación estándar son circulares para detectar
/// atípicos: el atípico contamina las mismas estadísticas que deberían
/// detectarlo. Mediana y MAD (Desviación Absoluta Mediana) no.
///
/// Trabaja en `double` a propósito (son estadísticas adimensionales — z,
/// razones, pesos — no montos guardados ni mostrados). El resultado final
/// de un pronóstico se redondea de vuelta a [Dinero] (centavos enteros)
/// solo al salir de domain/pronostico/, igual que `avanceDelCiclo` ya hace
/// con las fracciones de ciclo.
library;

/// Mediana de una lista de valores. Regresa 0 para lista vacía.
double mediana(List<double> valores) {
  if (valores.isEmpty) return 0;
  final ordenados = [...valores]..sort();
  final mitad = ordenados.length ~/ 2;
  if (ordenados.length.isOdd) return ordenados[mitad];
  return (ordenados[mitad - 1] + ordenados[mitad]) / 2;
}

/// Desviación Absoluta Mediana: mediana(|valor − mediana|).
///
/// **Salvaguarda contra MAD ≈ 0** (§2): si una categoría tiene montos casi
/// idénticos (ej. Spotify todos los meses), el MAD real tiende a cero y
/// cualquier variación mínima se vería como atípico extremo. Se aplica un
/// piso: si `MAD < 0.05 × mediana`, se usa `0.05 × mediana`.
double mad(List<double> valores) {
  final med = mediana(valores);
  final desviaciones = valores.map((v) => (v - med).abs()).toList();
  final madCrudo = mediana(desviaciones);
  final piso = 0.05 * med.abs();
  return madCrudo < piso ? piso : madCrudo;
}

/// z-modificado de un valor contra una mediana y un MAD ya calculados
/// (0.6745 es la constante estándar que hace que el MAD sea comparable a
/// una desviación estándar bajo normalidad).
double zModificado(double valor, {required double mediana, required double mad}) {
  if (mad == 0) return 0;
  return 0.6745 * (valor - mediana) / mad;
}

/// Percentil por interpolación lineal (método de posición P = p×(n−1)).
/// Se usa para la winsorización al percentil 95 (§2).
double percentil(List<double> valores, double p) {
  if (valores.isEmpty) return 0;
  final ordenados = [...valores]..sort();
  if (ordenados.length == 1) return ordenados.first;
  final posicion = p * (ordenados.length - 1);
  final indiceBajo = posicion.floor();
  final indiceAlto = posicion.ceil();
  if (indiceBajo == indiceAlto) return ordenados[indiceBajo];
  final fraccion = posicion - indiceBajo;
  return ordenados[indiceBajo] + (ordenados[indiceAlto] - ordenados[indiceBajo]) * fraccion;
}
