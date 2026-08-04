import 'punto_monto.dart';

/// `w_c(dow)` — peso relativo de gasto por día de la semana, suavizado por
/// credibilidad (modelo-pronostico-ciclo.md §3.1). Llave = `DateTime
/// .weekday` (1 = lunes … 7 = domingo). Un día sin historial regresa peso
/// neutro 1.0 — el modelo no inventa un patrón que no vio.
///
/// No implementa `v_c(t)` (§3.2, perfil de posición dentro del ciclo) —
/// simplificación consciente de v1: se trata como 1.0 en todo el ciclo.
/// El peso combinado (§3.3) queda entonces determinado solo por el día de
/// la semana, documentado en [avanceEfectivoCiclo].
Map<int, double> calcularPerfilDiaSemana(List<PuntoMonto> historial) {
  const neutro = <int, double>{1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1};
  if (historial.isEmpty) return neutro;

  // Se agrega primero por día calendario exacto: "gasto promedio en día d"
  // es un promedio de totales-por-día, no de movimientos individuales (si
  // un sábado tuvo 3 compras, cuenta como un dato de sábado, no como 3).
  final totalPorDia = <DateTime, double>{};
  for (final p in historial) {
    final dia = DateTime(p.fecha.year, p.fecha.month, p.fecha.day);
    totalPorDia.update(dia, (v) => v + p.monto, ifAbsent: () => p.monto);
  }

  final promedioGeneral =
      totalPorDia.values.reduce((a, b) => a + b) / totalPorDia.length;
  if (promedioGeneral == 0) return neutro;

  final totalesPorDiaSemana = <int, List<double>>{};
  for (final entrada in totalPorDia.entries) {
    totalesPorDiaSemana.update(
      entrada.key.weekday,
      (lista) => [...lista, entrada.value],
      ifAbsent: () => [entrada.value],
    );
  }

  final perfil = <int, double>{};
  for (var d = 1; d <= 7; d++) {
    final valores = totalesPorDiaSemana[d];
    if (valores == null || valores.isEmpty) {
      perfil[d] = 1.0;
      continue;
    }
    final n = valores.length;
    final promedioDia = valores.reduce((a, b) => a + b) / n;
    final wObservado = promedioDia / promedioGeneral;
    final lambda = n / (n + 8);
    perfil[d] = lambda * wObservado + (1 - lambda) * 1.0;
  }
  return perfil;
}
