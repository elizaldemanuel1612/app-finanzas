import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../pronostico/pronostico_categoria.dart';

/// Plan de Ajuste (addendum-v3-ajuste-y-ux.md §2): cuando el MPC proyecta
/// cierre por encima del presupuesto y todavía queda ciclo para corregir,
/// sugiere un ritmo diario — repartido con el mismo perfil de día de
/// semana del MPC, nunca plano.
final class PlanDeAjuste {
  final String categoriaId;
  final Dinero disponible;
  final int diasRestantes;
  final Dinero gastoHabitualPorDia;
  final Dinero sugeridoPromedioPorDia;

  /// `Sugerido_día(t)` por cada día restante del ciclo (§2.2) — el
  /// reparto real, no plano. La clave es la fecha (medianoche).
  final Map<DateTime, Dinero> repartoPorDia;

  /// Las tres piezas del mensaje, en el orden fijo de §2.3. Nunca se
  /// muestra el porcentaje de recorte solo.
  final String piezaCuantoQueda;
  final String piezaContraCostumbre;
  final String piezaNumeroASeguir;

  const PlanDeAjuste({
    required this.categoriaId,
    required this.disponible,
    required this.diasRestantes,
    required this.gastoHabitualPorDia,
    required this.sugeridoPromedioPorDia,
    required this.repartoPorDia,
    required this.piezaCuantoQueda,
    required this.piezaContraCostumbre,
    required this.piezaNumeroASeguir,
  });
}

/// `null` cuando el plan no se dispara o no aplica (§2.1, §2.6):
/// - la categoría es fija (§1.5: "Excluida — no se puede recortar la renta");
/// - quedan menos de 3 días de ciclo ("un consejo que ya no se puede
///   seguir solo genera frustración");
/// - el pronóstico no proyecta pasarse del presupuesto;
/// - el disponible ya es negativo (eso es terreno de rebalanceo, no de
///   un ritmo diario — "no se inventa un ritmo").
PlanDeAjuste? calcularPlanDeAjuste({
  required Categoria categoria,
  required PronosticoCategoria pronostico,
  required List<CicloCerradoHistorico> ciclosCerradosRecienteAAntiguo,
  required DateTime fechaInicioCiclo,
  required DateTime fechaFinCiclo,
  required DateTime hoy,
}) {
  if (categoria is! CategoriaVariable) return null;

  final diasRestantes = _diasRestantes(hoy, fechaFinCiclo);
  if (diasRestantes < 3) return null;

  final presupuesto = categoria.presupuestoMensualCentavos.centavos;
  if (pronostico.pronosticoP50.centavos <= presupuesto) return null;

  // Disponible = Presupuesto − Gastado − Comprometido_restante (§2.2).
  final disponibleCentavos =
      presupuesto - pronostico.observado.centavos - pronostico.comprometido.centavos;
  if (disponibleCentavos < 0) return null;

  final perfil = perfilEfectivoParaNivel(pronostico.nivelMadurez, ciclosCerradosRecienteAAntiguo);
  final dias = _diasDesde(hoy, fechaFinCiclo);
  final pesoTotal = dias.map((d) => perfil[d.weekday] ?? 1.0).fold(0.0, (a, b) => a + b);

  final repartoPorDia = <DateTime, Dinero>{};
  for (final d in dias) {
    final peso = perfil[d.weekday] ?? 1.0;
    final monto = pesoTotal == 0 ? disponibleCentavos / dias.length : disponibleCentavos * peso / pesoTotal;
    repartoPorDia[d] = Dinero(monto.round());
  }

  final sugeridoPromedioPorDiaCentavos = disponibleCentavos / diasRestantes;
  final sugeridoPromedioPorDia = Dinero(sugeridoPromedioPorDiaCentavos.round());

  // "Contra tu costumbre" (§2.3): mismo Histórico_c que usa el MPC,
  // normalizado a gasto-por-día y presentado en semana (§2.4) — nunca
  // dos fuentes de verdad distintas para "lo que gastas normalmente".
  final diasEnCiclo = fechaFinCiclo.difference(fechaInicioCiclo).inDays + 1;
  final gastoHabitualPorDiaCentavos = diasEnCiclo <= 0
      ? 0.0
      : historicoCentavosWinsorizado(ciclosCerradosRecienteAAntiguo) / diasEnCiclo;
  final gastoHabitualPorDia = Dinero(gastoHabitualPorDiaCentavos.round());
  final gastoHabitualSemanal = Dinero((gastoHabitualPorDiaCentavos * 7).round());

  final disponible = Dinero(disponibleCentavos.round());
  final piezaCuantoQueda =
      'Te quedan ${disponible.formateado()} para $diasRestantes ${_dias(diasRestantes)}';
  final piezaContraCostumbre = 'Normalmente gastas ${gastoHabitualSemanal.formateado()} por semana';

  // §2.4: comparación honesta — solo se presenta en semanas cuando el
  // tramo restante SÍ es una semana completa; si no, se etiqueta con su
  // duración real en días, para no comparar un tramo parcial contra una
  // semana de 7 días (el error de 43% vs 14% que ya se detectó).
  final String piezaNumeroASeguir;
  if (diasRestantes >= 7) {
    final sugeridoSemanal = Dinero((sugeridoPromedioPorDiaCentavos * 7).round());
    piezaNumeroASeguir =
        'Apunta a ${sugeridoSemanal.formateado()} por semana · ${sugeridoPromedioPorDia.formateado()} al día';
  } else {
    piezaNumeroASeguir =
        'Apunta a ${sugeridoPromedioPorDia.formateado()} al día durante $diasRestantes ${_dias(diasRestantes)}';
  }

  return PlanDeAjuste(
    categoriaId: categoria.id,
    disponible: disponible,
    diasRestantes: diasRestantes,
    gastoHabitualPorDia: gastoHabitualPorDia,
    sugeridoPromedioPorDia: sugeridoPromedioPorDia,
    repartoPorDia: repartoPorDia,
    piezaCuantoQueda: piezaCuantoQueda,
    piezaContraCostumbre: piezaContraCostumbre,
    piezaNumeroASeguir: piezaNumeroASeguir,
  );
}

String _dias(int n) => n == 1 ? 'día' : 'días';

int _diasRestantes(DateTime hoy, DateTime fechaFin) {
  final h = DateTime(hoy.year, hoy.month, hoy.day);
  final f = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
  final dias = f.difference(h).inDays + 1;
  return dias < 0 ? 0 : dias;
}

List<DateTime> _diasDesde(DateTime hoy, DateTime fechaFin) {
  final h = DateTime(hoy.year, hoy.month, hoy.day);
  final f = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
  final dias = <DateTime>[];
  for (var d = h; !d.isAfter(f); d = d.add(const Duration(days: 1))) {
    dias.add(d);
  }
  return dias;
}
