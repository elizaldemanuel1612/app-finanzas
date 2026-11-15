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

  /// Lo que habría que juntar por ciclo para llegar a la fecha (hacia
  /// arriba al centavo); `null` cuando [ciclosRestantes] lo es.
  final Dinero? porCiclo;

  /// A lo que se aparta hoy por ciclo, en cuántos ciclos se llega; `null`
  /// si ya se logró o no se aparta nada.
  final int? ciclosAlRitmoActual;

  const ProgresoObjetivo({
    required this.objetivo,
    required this.llevas,
    required this.falta,
    required this.estado,
    this.ciclosRestantes,
    this.porCiclo,
    this.ciclosAlRitmoActual,
  });

  /// De 0 a 1.
  double get avance => objetivo.monto.esPositivo ? llevas.centavos / objetivo.monto.centavos : 0;

  /// Con fecha: si lo que se aparta por ciclo alcanza para llegar a tiempo.
  /// `null` si no aplica (sin fecha, logrado, vencido o sin apartado).
  bool? get alcanzaATiempo {
    final restantes = ciclosRestantes;
    final alRitmo = ciclosAlRitmoActual;
    return restantes == null || alRitmo == null ? null : alRitmo <= restantes;
  }
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
    final restantes = fecha == null ? null : ciclosHasta(hoy: hoy, fecha: fecha, calculadora: calculadora);
    final enCamino = restantes != null && restantes > 0;
    resultado.add(ProgresoObjetivo(
      objetivo: o,
      llevas: Dinero(llevas),
      falta: Dinero(falta),
      estado: restantes == null
          ? EstadoObjetivo.sinFecha
          : enCamino
              ? EstadoObjetivo.enCamino
              : EstadoObjetivo.vencido,
      ciclosRestantes: enCamino ? restantes : null,
      porCiclo: enCamino ? Dinero(_haciaArriba(falta, restantes)) : null,
      ciclosAlRitmoActual: alRitmo,
    ));
  }
  return resultado;
}
