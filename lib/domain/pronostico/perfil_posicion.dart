import 'estadistica_robusta.dart';
import 'punto_monto.dart';

/// Posición dentro del ciclo (modelo-pronostico-ciclo.md §3.2 y Tipo C,
/// 2026-11-21): qué parte del gasto de una categoría ya había ocurrido a
/// esta altura en los ciclos cerrados. Es lo que evita proyectar al triple
/// lo que se paga una sola vez al inicio del ciclo.
///
/// Los ciclos y sus inicios vienen en el mismo orden. El día de un gasto es
/// su distancia en días de calendario al inicio de su ciclo; uno anterior al
/// inicio (ciclos desfasados tras un cambio de corte) cuenta como día 0.

/// Días de calendario de [inicio] a [fecha], nunca negativo. En UTC para
/// que un cambio de horario no mueva la cuenta.
int diaEnCiclo(DateTime fecha, DateTime inicio) {
  final dias = DateTime.utc(fecha.year, fecha.month, fecha.day)
      .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
      .inDays;
  return dias < 0 ? 0 : dias;
}

/// Con cuánta fuerza se cree la curva: `λ = n ÷ (n + 0.5)`, con `n` ciclos
/// cerrados con gasto. Medido en `tool/simular_pronostico` (§9.1).
const suavizadoPosicion = 0.5;

/// `p_c` con posición: la curva acumulada `F_c(d)` mezclada con
/// [avanceCalendario] según cuántos ciclos la respaldan. [diaDeHoy] es el
/// día de hoy dentro del ciclo en curso (0 = el primero). Sin ningún ciclo
/// con gasto regresa [avanceCalendario].
double avanceConPosicion({
  required List<List<PuntoMonto>> ciclosCerrados,
  required List<DateTime> iniciosCiclosCerrados,
  required int diaDeHoy,
  required double avanceCalendario,
}) {
  var suma = 0.0;
  var n = 0;
  for (var j = 0; j < ciclosCerrados.length; j++) {
    var antes = 0.0;
    var total = 0.0;
    for (final p in ciclosCerrados[j]) {
      total += p.monto;
      if (diaEnCiclo(p.fecha, iniciosCiclosCerrados[j]) <= diaDeHoy) antes += p.monto;
    }
    if (total > 0) {
      suma += antes / total;
      n++;
    }
  }
  if (n == 0) return avanceCalendario;
  final lambda = n / (n + suavizadoPosicion);
  return lambda * (suma / n) + (1 - lambda) * avanceCalendario;
}

/// Desde cuántos ciclos cerrados se aplica el tope por conteo: con menos,
/// "lo más que ha habido en un ciclo" todavía no dice nada.
const ciclosParaTopePorConteo = 3;

/// El tope solo vale para lo que de verdad pasa una o dos veces por ciclo
/// (colegiatura, corte de cabello, un pago quincenal). En categorías de más
/// gastos, llegar pronto al máximo dice que este ciclo viene distinto, no
/// que ya se acabó.
const maximoParaTopePorConteo = 2;

/// Lo que suele faltar por gastar después de [diaDeHoy] en una categoría
/// esporádica: mitad promedio y mitad mediana de lo gastado después de ese
/// día en cada ciclo cerrado. Con el tope por conteo desde
/// [ciclosParaTopePorConteo] ciclos, en categorías de hasta
/// [maximoParaTopePorConteo] gastos por ciclo: nunca más gastos que los más
/// que ha habido en un ciclo, menos los [movimientosDeEsteCiclo] ya hechos.
double faltaPorPosicion({
  required List<List<PuntoMonto>> ciclosCerrados,
  required List<DateTime> iniciosCiclosCerrados,
  required int diaDeHoy,
  required int movimientosDeEsteCiclo,
}) {
  if (ciclosCerrados.isEmpty) return 0;
  final despues = <double>[];
  var maximo = 0;
  for (var j = 0; j < ciclosCerrados.length; j++) {
    var d = 0.0;
    for (final p in ciclosCerrados[j]) {
      if (diaEnCiclo(p.fecha, iniciosCiclosCerrados[j]) > diaDeHoy) d += p.monto;
    }
    despues.add(d);
    if (ciclosCerrados[j].length > maximo) maximo = ciclosCerrados[j].length;
  }
  final promedio = despues.reduce((a, b) => a + b) / despues.length;
  var falta = (promedio + mediana(despues)) / 2;
  if (ciclosCerrados.length >= ciclosParaTopePorConteo && maximo <= maximoParaTopePorConteo) {
    final porHacer = maximo - movimientosDeEsteCiclo;
    // Con algo por hacer hubo al menos un gasto: la mediana existe.
    final tope = porHacer <= 0
        ? 0.0
        : porHacer * mediana([for (final c in ciclosCerrados) for (final p in c) p.monto]);
    if (falta > tope) falta = tope;
  }
  return falta;
}
