/// `p_c` — avance efectivo del ciclo para una categoría (modelo-pronostico-
/// ciclo.md §3.3): no es el avance de calendario, es cuánto **peso de
/// gasto esperado** ya pasó, usando el perfil de día de semana
/// (`perfil_dia_semana.dart`). Si los días fuertes de la categoría ya
/// ocurrieron, `p_c` puede ir muy por delante del avance de calendario —
/// y viceversa.
///
/// `v_c(t)` (perfil de posición dentro del ciclo, §3.2) no está
/// implementado en v1 — ver la nota en `perfil_dia_semana.dart`.
double avanceEfectivoCiclo({
  required Map<int, double> perfilDiaSemana,
  required DateTime fechaInicio,
  required DateTime fechaFin,
  required DateTime hoy,
}) {
  final inicio = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
  final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
  final corte = DateTime(hoy.year, hoy.month, hoy.day);

  var pesoTranscurrido = 0.0;
  var pesoTotal = 0.0;
  for (var dia = inicio; !dia.isAfter(fin); dia = dia.add(const Duration(days: 1))) {
    final peso = perfilDiaSemana[dia.weekday] ?? 1.0;
    pesoTotal += peso;
    if (!dia.isAfter(corte)) pesoTranscurrido += peso;
  }

  if (pesoTotal == 0) return 0;
  final avance = pesoTranscurrido / pesoTotal;
  if (avance < 0) return 0;
  if (avance > 1) return 1;
  return avance;
}
