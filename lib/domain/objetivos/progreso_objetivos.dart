import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../modelos/objetivo.dart';

enum EstadoObjetivo {
  /// Ya se juntó todo.
  logrado,

  /// Tiene fecha y aún hay ciclos para llegar.
  enCamino,

  /// La fecha ya pasó y no se juntó.
  vencido,

  /// Sin fecha: no hay contra qué medir el ritmo.
  sinFecha,
}

/// Lo que toca apartar en un ciclo para llegar a la fecha de un objetivo:
/// la parte de lo que falta proporcional a los [dias] de ese ciclo que
/// caen entre hoy y la fecha (spec-app-finanzas-v2.md §7.3.3).
final class TramoDeObjetivo {
  final Ciclo ciclo;

  /// Días de [ciclo] entre hoy y la fecha, los dos incluidos.
  final int dias;
  final Dinero monto;

  const TramoDeObjetivo({required this.ciclo, required this.dias, required this.monto});
}

/// Cómo va un [Objetivo] (spec-app-finanzas-v2.md §7.3.3).
final class ProgresoObjetivo {
  final Objetivo objetivo;

  /// Lo que ya hay para este objetivo (nunca más que su monto).
  final Dinero llevas;
  final Dinero falta;
  final EstadoObjetivo estado;

  /// Ciclos que quedan hasta la fecha, contando el que corre; `null` sin
  /// fecha, logrado o vencido.
  final int? ciclosRestantes;

  /// Cuánto apartar en cada ciclo para llegar a la fecha, repartido por
  /// días: el primero es el que corre. Vacío sin fecha, logrado o vencido.
  final List<TramoDeObjetivo> reparto;

  /// A lo que se aparta hoy por ciclo, en cuántos ciclos se llega; `null`
  /// si ya se logró o no se aparta nada.
  final int? ciclosAlRitmoActual;

  /// Con fecha: si lo que se aparta por ciclo, repartido por los días de su
  /// ciclo, cubre lo que pide cada día hasta la fecha. `null` si no aplica
  /// (sin fecha, logrado, vencido o sin apartado).
  final bool? alcanzaATiempo;

  const ProgresoObjetivo({
    required this.objetivo,
    required this.llevas,
    required this.falta,
    required this.estado,
    this.ciclosRestantes,
    this.reparto = const [],
    this.ciclosAlRitmoActual,
    this.alcanzaATiempo,
  });

  /// De 0 a 1.
  double get avance => objetivo.monto.esPositivo ? llevas.centavos / objetivo.monto.centavos : 0;
}

/// Ciclos desde el que contiene [hoy] hasta el que contiene [fecha], los
/// dos incluidos; 0 si [fecha] ya pasó.
int ciclosHasta({required DateTime hoy, required DateTime fecha, required CalculadoraCiclo calculadora}) {
  final dia = DateTime(hoy.year, hoy.month, hoy.day);
  final limite = DateTime(fecha.year, fecha.month, fecha.day);
  if (limite.isBefore(dia)) return 0;
  var ciclo = calculadora.calcularPara(dia);
  var cuantos = 1;
  while (ciclo.fechaFin.isBefore(limite)) {
    ciclo = calculadora.calcularPara(ciclo.fechaFin.add(const Duration(days: 1)));
    cuantos++;
  }
  return cuantos;
}

int _haciaArriba(int numerador, int divisor) => (numerador + divisor - 1) ~/ divisor;

DateTime _dia(DateTime f) => DateTime.utc(f.year, f.month, f.day);

/// Reparte [falta] (centavos) entre los ciclos de [hoy] a [fecha] en
/// proporción a los días de cada uno dentro de ese rango, los dos
/// incluidos. Cada parte va a pesos enteros hacia abajo y lo que sobra se
/// suma a la del ciclo que corre: la suma es exacta. Vacío si [fecha] ya
/// pasó.
List<TramoDeObjetivo> repartirPorDias({
  required int falta,
  required DateTime hoy,
  required DateTime fecha,
  required CalculadoraCiclo calculadora,
}) {
  final desde = _dia(hoy);
  final hasta = _dia(fecha);
  if (hasta.isBefore(desde)) return const [];
  final ciclos = <(Ciclo, int)>[];
  var ciclo = calculadora.calcularPara(hoy);
  while (true) {
    final inicio = _dia(ciclo.fechaInicio).isBefore(desde) ? desde : _dia(ciclo.fechaInicio);
    final fin = _dia(ciclo.fechaFin).isAfter(hasta) ? hasta : _dia(ciclo.fechaFin);
    ciclos.add((ciclo, fin.difference(inicio).inDays + 1));
    if (!_dia(ciclo.fechaFin).isBefore(hasta)) break;
    ciclo = calculadora.calcularPara(ciclo.fechaFin.add(const Duration(days: 1)));
  }
  final total = hasta.difference(desde).inDays + 1;
  final montos = [for (final (_, dias) in ciclos) falta * dias ~/ total ~/ 100 * 100];
  montos[0] += falta - montos.fold<int>(0, (a, b) => a + b);
  return [
    for (final (i, (c, dias)) in ciclos.indexed) TramoDeObjetivo(ciclo: c, dias: dias, monto: Dinero(montos[i])),
  ];
}

/// El avance de cada objetivo activo, en el orden de [objetivos].
///
/// - [saldoPorCuenta]: saldo de cada cuenta de ahorro. Si varios objetivos
///   comparten cuenta, el saldo los va llenando en orden: el primero se
///   completa antes de que el segundo reciba algo. Un saldo negativo cuenta
///   como cero; una cuenta que no está, también.
/// - [apartadoPorCiclo]: lo que se piensa apartar por ciclo (la meta del
///   ciclo), para estimar cuándo se llega; `null` o cero = sin estimación.
List<ProgresoObjetivo> calcularProgresoObjetivos({
  required List<Objetivo> objetivos,
  required Map<String, Dinero> saldoPorCuenta,
  required DateTime hoy,
  required CalculadoraCiclo calculadora,
  Dinero? apartadoPorCiclo,
}) {
  final disponible = {
    for (final e in saldoPorCuenta.entries) e.key: e.value.esPositivo ? e.value.centavos : 0,
  };
  final resultado = <ProgresoObjetivo>[];
  for (final o in objetivos) {
    if (!o.activo) continue;
    final hay = disponible[o.cuentaId] ?? 0;
    final llevas = hay < o.monto.centavos ? hay : o.monto.centavos;
    disponible[o.cuentaId] = hay - llevas;
    final falta = o.monto.centavos - llevas;

    if (falta <= 0) {
      resultado.add(ProgresoObjetivo(
        objetivo: o,
        llevas: Dinero(llevas),
        falta: const Dinero.cero(),
        estado: EstadoObjetivo.logrado,
      ));
      continue;
    }
    final apartado = apartadoPorCiclo?.centavos ?? 0;
    final alRitmo = apartado > 0 ? _haciaArriba(falta, apartado) : null;
    final fecha = o.fechaLimite;
    final reparto = fecha == null
        ? const <TramoDeObjetivo>[]
        : repartirPorDias(falta: falta, hoy: hoy, fecha: fecha, calculadora: calculadora);
    final enCamino = reparto.isNotEmpty;
    // Llega si lo apartado por día de cada ciclo cubre lo que pide cada día
    // hasta la fecha: apartado / días del ciclo ≥ falta / días hasta la fecha.
    bool? alcanza;
    if (enCamino && apartado > 0) {
      final dias = reparto.fold<int>(0, (t, r) => t + r.dias);
      final masLargo = reparto.map((r) => r.ciclo.diasDelCiclo).reduce((a, b) => a > b ? a : b);
      alcanza = apartado * dias >= falta * masLargo;
    }
    resultado.add(ProgresoObjetivo(
      objetivo: o,
      llevas: Dinero(llevas),
      falta: Dinero(falta),
      estado: fecha == null
          ? EstadoObjetivo.sinFecha
          : enCamino
              ? EstadoObjetivo.enCamino
              : EstadoObjetivo.vencido,
      ciclosRestantes: enCamino ? reparto.length : null,
      reparto: reparto,
      ciclosAlRitmoActual: alRitmo,
      alcanzaATiempo: alcanza,
    ));
  }
  return resultado;
}

/// Los objetivos activos separados en los que faltan y los logrados
/// (spec-app-finanzas-v2.md §7.3.3, 2026-11-17).
///
/// Los que faltan van primero lo que pide atención: los que ya pasaron su
/// fecha, luego los que van lentos, los demás con fecha (la más cercana
/// primero) y al final los que no tienen fecha. Los logrados conservan el
/// orden en que llegan.
({List<ProgresoObjetivo> porCumplir, List<ProgresoObjetivo> logrados}) agruparObjetivos(
  List<ProgresoObjetivo> progreso,
) {
  int prioridad(ProgresoObjetivo p) => switch (p.estado) {
        EstadoObjetivo.vencido => 0,
        EstadoObjetivo.enCamino => p.alcanzaATiempo == false ? 1 : 2,
        EstadoObjetivo.sinFecha => 3,
        EstadoObjetivo.logrado => 4,
      };
  final porCumplir = [for (final p in progreso) if (p.estado != EstadoObjetivo.logrado) p];
  final orden = {for (final (i, p) in porCumplir.indexed) p: i};
  porCumplir.sort((a, b) {
    final porEstado = prioridad(a).compareTo(prioridad(b));
    if (porEstado != 0) return porEstado;
    final fa = a.objetivo.fechaLimite;
    final fb = b.objetivo.fechaLimite;
    if (fa != null && fb != null && fa != fb) return fa.compareTo(fb);
    return orden[a]!.compareTo(orden[b]!);
  });
  return (
    porCumplir: porCumplir,
    logrados: [for (final p in progreso) if (p.estado == EstadoObjetivo.logrado) p],
  );
}

/// Lo que piden en el ciclo que corre los objetivos con fecha que aún no
/// se cumplen: la suma del primer tramo de cada reparto.
Dinero aApartarEsteCiclo(Iterable<ProgresoObjetivo> progreso) => Dinero.suma([
      for (final p in progreso)
        if (p.reparto.isNotEmpty) p.reparto.first.monto,
    ]);
