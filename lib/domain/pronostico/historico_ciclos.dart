import 'estadistica_robusta.dart';

/// `Histórico_c` suavizado entre ciclos cerrados (modelo-pronostico-
/// ciclo.md §5).
///
/// [totalesPorCicloRecienteAAntiguo] debe venir **del ciclo cerrado más
/// reciente al más antiguo** — el orden importa, el EWMA pesa más al
/// primero de la lista.
///
/// - 0 ciclos: 0 (arranque en frío, ver `nivel_madurez.dart`).
/// - 1 ciclo: ese mismo total.
/// - 2–4 ciclos: mediana de los totales (resiste que uno haya sido raro).
/// - 5+ ciclos: promedio móvil exponencial (EWMA) con α = 0.4.
///
/// **Detección de cambio de nivel:** si los dos ciclos más recientes
/// difieren de la mediana de los ciclos previos en más de 2 MAD, **en la
/// misma dirección**, se asume cambio estructural (aumento de renta,
/// nuevo gasto fijo) y el histórico se reinicia a esos 2 ciclos — evita
/// que el modelo tarde medio año en aceptar una nueva realidad.
double historicoSuavizado(List<double> totalesPorCicloRecienteAAntiguo) {
  var totales = totalesPorCicloRecienteAAntiguo;
  if (totales.isEmpty) return 0;
  if (totales.length == 1) return totales.single;

  if (totales.length >= 4) {
    final ultimosDos = totales.sublist(0, 2);
    final baseAnterior = totales.sublist(2);
    final medBase = mediana(baseAnterior);
    final madBase = mad(baseAnterior);
    if (madBase > 0) {
      final diferencias = ultimosDos.map((v) => v - medBase).toList();
      final cambioEstructural = diferencias.every((d) => d > 2 * madBase) ||
          diferencias.every((d) => d < -2 * madBase);
      if (cambioEstructural) totales = ultimosDos;
    }
  }

  if (totales.length <= 4) {
    return mediana(totales);
  }

  const alpha = 0.4;
  var sumaPonderada = 0.0;
  var pesoTotal = 0.0;
  for (var i = 0; i < totales.length; i++) {
    final peso = alpha * _potencia(1 - alpha, i);
    sumaPonderada += peso * totales[i];
    pesoTotal += peso;
  }
  return sumaPonderada / pesoTotal;
}

double _potencia(double base, int exponente) {
  var resultado = 1.0;
  for (var i = 0; i < exponente; i++) {
    resultado *= base;
  }
  return resultado;
}
