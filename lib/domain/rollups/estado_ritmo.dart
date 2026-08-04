/// Estado de la "marca de ritmo" (addendum-v3 §3.2): el único elemento de
/// interfaz que hay que aprender. Compara qué tanto llevas gastado contra
/// qué tanto ha avanzado el ciclo.
///
/// Esta es la versión simple (avance = días transcurridos ÷ días totales
/// del ciclo). El motor de pronóstico completo — que pesa por día de la
/// semana y por historial — vive en domain/pronostico/ y llega en la
/// Fase 4; ahí esta función se puede reemplazar sin que la interfaz cambie.
enum EstadoRitmo { vaBien, justo, pasado }

/// [porcentajeUsado] es la fracción de presupuesto gastada (0.5 = 50%);
/// `null` si la categoría no tiene presupuesto (no aplica juicio de ritmo).
/// [avanceCiclo] es la fracción del ciclo transcurrida (0..1).
EstadoRitmo calcularEstadoRitmo({
  required double? porcentajeUsado,
  required double avanceCiclo,
}) {
  if (porcentajeUsado == null) return EstadoRitmo.vaBien;
  if (porcentajeUsado > avanceCiclo * 1.15) return EstadoRitmo.pasado;
  if (porcentajeUsado > avanceCiclo * 0.85) return EstadoRitmo.justo;
  return EstadoRitmo.vaBien;
}

/// Fracción del ciclo transcurrida a la fecha [ahora], acotada a [0, 1].
double avanceDelCiclo({
  required DateTime fechaInicio,
  required DateTime fechaFin,
  required DateTime ahora,
}) {
  final diasTotales = fechaFin.difference(fechaInicio).inDays + 1;
  if (diasTotales <= 0) return 1;
  final diasTranscurridos = ahora.difference(fechaInicio).inDays + 1;
  final avance = diasTranscurridos / diasTotales;
  if (avance < 0) return 0;
  if (avance > 1) return 1;
  return avance;
}
