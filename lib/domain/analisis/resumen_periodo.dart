import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'reporte_analisis.dart';

// Resumen del año y rango de fechas (spec-app-finanzas-v2.md §5.7,
// "Periodo", 2026-11-15). Solo consulta.

/// Un rango de días, los dos extremos incluidos.
final class RangoFechas {
  final DateTime desde;
  final DateTime hasta;

  RangoFechas(DateTime desde, DateTime hasta)
      : desde = DateTime(desde.year, desde.month, desde.day),
        hasta = DateTime(hasta.year, hasta.month, hasta.day);

  /// Días del rango, contando los dos extremos.
  int get dias => (hasta.difference(desde).inHours / 24).round() + 1;

  bool contiene(DateTime fecha) {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    return !dia.isBefore(desde) && !dia.isAfter(hasta);
  }

  /// El mismo rango un año antes (el 29 de febrero cae en el 28).
  RangoFechas anioAnterior() => RangoFechas(_haceUnAnio(desde), _haceUnAnio(hasta));

  static DateTime _haceUnAnio(DateTime f) {
    final ultimo = DateTime(f.year - 1, f.month + 1, 0).day;
    return DateTime(f.year - 1, f.month, f.day < ultimo ? f.day : ultimo);
  }

  @override
  bool operator ==(Object other) => other is RangoFechas && other.desde == desde && other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);
}

/// Del 1 de enero a hoy.
RangoFechas rangoEsteAnio(DateTime hoy) => RangoFechas(DateTime(hoy.year), hoy);

/// Los últimos 12 meses: del día siguiente a hoy hace un año, a hoy.
RangoFechas rangoUltimos12Meses(DateTime hoy) =>
    RangoFechas(RangoFechas._haceUnAnio(hoy).add(const Duration(days: 1)), hoy);

/// El año calendario anterior completo.
RangoFechas rangoAnioPasado(DateTime hoy) => RangoFechas(DateTime(hoy.year - 1), DateTime(hoy.year - 1, 12, 31));

/// Lo gastado en un mes calendario del rango.
final class MesDelPeriodo {
  final int anio;
  final int mes;
  final Dinero total;
  const MesDelPeriodo({required this.anio, required this.mes, required this.total});
}

final class ResumenPeriodo {
  final RangoFechas rango;
  final Dinero total;
  final Dinero fijas;
  final Dinero variables;
  final int conteo;

  /// Total ÷ días × 30.44: cuánto al mes, en promedio.
  final Dinero promedioMensual;

  /// Mes por mes, del más viejo al más reciente; vacío si el rango abarca
  /// más de 13 meses.
  final List<MesDelPeriodo> meses;

  /// De mayor a menor; porcentaje sobre [total].
  final List<GastoCategoria> categorias;

  final MesDelPeriodo? mesMasAlto;
  final Movimiento? mayorGasto;

  /// Lo gastado en el mismo rango un año antes; `null` si no se registraba
  /// desde la primera semana de ese rango (no sería comparable).
  final Dinero? totalAnioAnterior;

  const ResumenPeriodo({
    required this.rango,
    required this.total,
    required this.fijas,
    required this.variables,
    required this.conteo,
    required this.promedioMensual,
    required this.meses,
    required this.categorias,
    required this.mesMasAlto,
    required this.mayorGasto,
    required this.totalAnioAnterior,
  });

  bool get vacio => conteo == 0;

  /// Cambio porcentual contra el año anterior, redondeado; `null` si no hay
  /// comparación o el año anterior fue cero.
  int? get cambioContraAnioAnterior {
    final antes = totalAnioAnterior;
    if (antes == null || !antes.esPositivo) return null;
    return ((total.centavos - antes.centavos) * 100 / antes.centavos).round();
  }
}

ResumenPeriodo calcularResumenPeriodo({
  required List<Movimiento> movimientos,
  required List<Categoria> categorias,
  required RangoFechas rango,
}) {
  final activos = [for (final m in movimientos) if (m.estado == EstadoMovimiento.activo) m];
  final enRango = [for (final m in activos) if (rango.contiene(m.fecha)) m];
  final porId = {for (final c in categorias) c.id: c};

  var total = 0;
  var fijas = 0;
  var variables = 0;
  final porCategoria = <String, ({int total, int conteo})>{};
  final porMes = <int, int>{};
  Movimiento? mayor;
  for (final m in enRango) {
    final c = m.monto.centavos;
    total += c;
    switch (porId[m.categoriaId]) {
      case CategoriaFija():
        fijas += c;
      case CategoriaVariable():
        variables += c;
      case null:
        break;
    }
    final previo = porCategoria[m.categoriaId];
    porCategoria[m.categoriaId] = (total: (previo?.total ?? 0) + c, conteo: (previo?.conteo ?? 0) + 1);
    final clave = m.fecha.year * 12 + m.fecha.month - 1;
    porMes[clave] = (porMes[clave] ?? 0) + c;
    if (mayor == null || c > mayor.monto.centavos) mayor = m;
  }

  final listaCategorias = [
    for (final MapEntry(key: id, value: v) in porCategoria.entries)
      if (porId[id] case final categoria?)
        GastoCategoria(
          categoria: categoria,
          total: Dinero(v.total),
          porcentaje: (v.total * 100 / total).round(),
          conteo: v.conteo,
        ),
  ]..sort((a, b) => b.total.centavos.compareTo(a.total.centavos));

  final primero = rango.desde.year * 12 + rango.desde.month - 1;
  final ultimo = rango.hasta.year * 12 + rango.hasta.month - 1;
  final meses = [
    for (var k = primero; k <= ultimo; k++) MesDelPeriodo(anio: k ~/ 12, mes: k % 12 + 1, total: Dinero(porMes[k] ?? 0)),
  ];
  MesDelPeriodo? masAlto;
  for (final m in meses) {
    if (m.total.esPositivo && (masAlto == null || m.total.centavos > masAlto.total.centavos)) masAlto = m;
  }

  // Comparable solo si ya se registraba en la primera semana del rango de
  // hace un año.
  final anterior = rango.anioAnterior();
  final primerRegistro = activos.isEmpty
      ? null
      : activos.map((m) => m.fecha).reduce((a, b) => a.isBefore(b) ? a : b);
  final comparable =
      primerRegistro != null && !primerRegistro.isAfter(anterior.desde.add(const Duration(days: 7)));
  final totalAnterior = comparable
      ? Dinero(activos.where((m) => anterior.contiene(m.fecha)).fold<int>(0, (s, m) => s + m.monto.centavos))
      : null;

  return ResumenPeriodo(
    rango: rango,
    total: Dinero(total),
    fijas: Dinero(fijas),
    variables: Dinero(variables),
    conteo: enRango.length,
    promedioMensual: Dinero((total * 30.4375 / rango.dias).round()),
    meses: meses.length <= 13 ? meses : const [],
    categorias: listaCategorias,
    mesMasAlto: masAlto,
    mayorGasto: mayor,
    totalAnioAnterior: totalAnterior,
  );
}
