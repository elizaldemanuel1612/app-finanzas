/// Estado de la "marca de ritmo" (addendum-v3 §3.2): el único elemento de
/// interfaz que hay que aprender. Es un juicio **absoluto** — compara qué
/// tanto llevas gastado contra tu presupuesto, nunca contra el avance del
/// ciclo.
///
/// Antes comparaba `porcentajeUsado` contra `avanceCiclo`, así que
/// "Excedido" en realidad significaba "vas más rápido que el calendario",
/// no "ya te excediste". Eso rompía en los primeros días de cada ciclo:
/// con `avanceCiclo` cercano a cero, cualquier gasto normal (ni siquiera
/// grande) ya "superaba" ese avance minúsculo y todo se pintaba de rojo.
/// La proyección de ritmo ("a este paso no te va a alcanzar") sigue
/// existiendo, pero aparte, en [vaMuyRapido] — con su propio piso mínimo
/// de días transcurridos para que la proyección tenga sentido.
///
/// Solo aplica a [CategoriaVariable] — una [CategoriaFija] no tiene
/// "presupuesto" que se pueda exceder, tiene un monto conocido que se paga
/// o no (spec-app-finanzas-v2.md §1.5: "Barra de ritmo: No aplica" /
/// "Estado: Pagado / pendiente" para fijas). Quien llama con el
/// `porcentajeUsado` de una fija está fuera del contrato de esta función.
enum EstadoRitmo { vaBien, justo, excedido }

/// [porcentajeUsado] es la fracción de presupuesto gastada (0.5 = 50%);
/// `null` si la categoría no tiene presupuesto (no aplica juicio de ritmo).
/// "Excedido" solo cuando de verdad se superó el 100% del presupuesto.
EstadoRitmo calcularEstadoRitmo({required double? porcentajeUsado}) {
  if (porcentajeUsado == null) return EstadoRitmo.vaBien;
  if (porcentajeUsado > 1.0) return EstadoRitmo.excedido;
  if (porcentajeUsado > 0.85) return EstadoRitmo.justo;
  return EstadoRitmo.vaBien;
}

/// Antes de que el ciclo lleve al menos esta fracción transcurrida, no hay
/// suficiente información para proyectar ritmo: gastar el 20% del
/// presupuesto el día 1 de un ciclo de 30 días no dice nada por sí solo.
const avanceMinimoParaProyectarRitmo = 0.15;

/// ¿A este paso no te va a alcanzar el presupuesto? Proyección explícita
/// y separada de [calcularEstadoRitmo]: compara qué tan rápido gastas
/// contra qué tan avanzado va el ciclo, pero solo aplica una vez que hay
/// [avanceMinimoParaProyectarRitmo] de por medio — antes de eso cualquier
/// gasto, por chico que sea, "va más rápido" que un ciclo que apenas
/// empieza.
bool vaMuyRapido({
  required double? porcentajeUsado,
  required double avanceCiclo,
}) {
  if (porcentajeUsado == null) return false;
  if (avanceCiclo < avanceMinimoParaProyectarRitmo) return false;
  return porcentajeUsado > avanceCiclo * 1.15;
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
