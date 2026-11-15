import '../../core/money.dart';
import '../modelos/categoria_ingreso.dart';
import '../modelos/cuenta.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../modelos/movimiento_cuenta.dart';
import 'resumen_periodo.dart';

// Análisis → Ingresos (spec-app-finanzas-v2.md §7.3.4, 2026-11-15): lo que
// entró a las cuentas, por categoría de ingreso. Solo consulta.

/// Lo que entró por una categoría; [categoria] `null` = sin categoría.
final class IngresoPorCategoria {
  final CategoriaIngreso? categoria;
  final Dinero total;

  /// Porcentaje entero (0–100) de todo lo que entró.
  final int porcentaje;
  final int conteo;

  const IngresoPorCategoria({
    required this.categoria,
    required this.total,
    required this.porcentaje,
    required this.conteo,
  });
}

/// Lo que entró a una cuenta.
final class IngresoPorCuenta {
  final Cuenta cuenta;
  final Dinero total;
  final int porcentaje;

  const IngresoPorCuenta({required this.cuenta, required this.total, required this.porcentaje});
}

final class ReporteIngresos {
  final RangoFechas rango;
  final Dinero total;
  final int conteo;

  /// Total ÷ días × 30.44.
  final Dinero promedioMensual;

  /// De mayor a menor.
  final List<IngresoPorCategoria> porCategoria;
  final List<IngresoPorCuenta> porCuenta;

  /// Mes por mes; vacío si el rango abarca más de 13 meses.
  final List<MesDelPeriodo> meses;
  final MesDelPeriodo? mesMasAlto;
  final MovimientoCuenta? mayor;

  /// Lo gastado (gastos activos) en las mismas fechas.
  final Dinero gastado;

  const ReporteIngresos({
    required this.rango,
    required this.total,
    required this.conteo,
    required this.promedioMensual,
    required this.porCategoria,
    required this.porCuenta,
    required this.meses,
    required this.mesMasAlto,
    required this.mayor,
    required this.gastado,
  });

  bool get vacio => conteo == 0;

  /// Lo que entró menos lo que se gastó; negativo si se gastó de más.
  Dinero get quedo => total - gastado;

  /// Qué parte de lo que entró se gastó, en porcentaje entero; `null` sin
  /// ingresos.
  int? get porcentajeGastado => total.esPositivo ? (gastado.centavos * 100 / total.centavos).round() : null;

  /// La categoría de la que se depende: una sola (con nombre) que pasa de
  /// 80 % de lo que entra, habiendo más de un abono. `null` si no hay.
  IngresoPorCategoria? get fuenteDominante {
    final primera = porCategoria.firstOrNull;
    if (primera == null || primera.categoria == null || conteo < 2 || primera.porcentaje <= 80) return null;
    return primera;
  }
}

/// Ingreso = abono activo a una cuenta que no sea de crédito (ahí un abono
/// baja la deuda), con fecha en [rango]. Transferencias y ajustes no
/// cuentan: no es dinero nuevo.
///
/// Con [soloCuentas] (spec §7.3.4, filtro por cuenta) solo entran los
/// abonos a esas cuentas y, en "contra lo gastado", lo gastado con ellas.
/// `null` o vacío = todas.
ReporteIngresos calcularReporteIngresos({
  required List<MovimientoCuenta> movimientosCuenta,
  required List<CategoriaIngreso> categorias,
  required List<Cuenta> cuentas,
  required List<Movimiento> gastos,
  required RangoFechas rango,
  Set<String>? soloCuentas,
}) {
  final filtro = soloCuentas == null || soloCuentas.isEmpty ? null : soloCuentas;
  final cuentaPorId = {for (final c in cuentas) c.id: c};
  final categoriaPorId = {for (final c in categorias) c.id: c};
  final abonos = [
    for (final m in movimientosCuenta)
      if (m.tipo == TipoMovimientoCuenta.abono &&
          m.estado == EstadoMovimientoCuenta.activo &&
          rango.contiene(m.fecha) &&
          cuentaPorId[m.cuentaId] != null &&
          cuentaPorId[m.cuentaId]!.tipo != TipoCuenta.credito &&
          (filtro == null || filtro.contains(m.cuentaId)))
        m,
  ];

  var total = 0;
  final porCategoria = <String?, ({int total, int conteo})>{};
  final porCuenta = <String, int>{};
  final porMes = <int, int>{};
  MovimientoCuenta? mayor;
  for (final a in abonos) {
    final c = a.monto.centavos;
    total += c;
    // Una categoría que ya no existe cuenta como "sin categoría".
    final clave = categoriaPorId.containsKey(a.categoriaIngresoId) ? a.categoriaIngresoId : null;
    final previo = porCategoria[clave];
    porCategoria[clave] = (total: (previo?.total ?? 0) + c, conteo: (previo?.conteo ?? 0) + 1);
    porCuenta[a.cuentaId] = (porCuenta[a.cuentaId] ?? 0) + c;
    final mes = a.fecha.year * 12 + a.fecha.month - 1;
    porMes[mes] = (porMes[mes] ?? 0) + c;
    if (mayor == null || c > mayor.monto.centavos) mayor = a;
  }
  int porcentaje(int parte) => (parte * 100 / total).round();

  final primero = rango.desde.year * 12 + rango.desde.month - 1;
  final ultimo = rango.hasta.year * 12 + rango.hasta.month - 1;
  final meses = [
    for (var k = primero; k <= ultimo; k++) MesDelPeriodo(anio: k ~/ 12, mes: k % 12 + 1, total: Dinero(porMes[k] ?? 0)),
  ];
  MesDelPeriodo? masAlto;
  for (final m in meses) {
    if (m.total.esPositivo && (masAlto == null || m.total.centavos > masAlto.total.centavos)) masAlto = m;
  }

  return ReporteIngresos(
    rango: rango,
    total: Dinero(total),
    conteo: abonos.length,
    promedioMensual: Dinero((total * 30.4375 / rango.dias).round()),
    porCategoria: [
      for (final MapEntry(key: id, value: v) in porCategoria.entries)
        IngresoPorCategoria(
          categoria: categoriaPorId[id],
          total: Dinero(v.total),
          porcentaje: porcentaje(v.total),
          conteo: v.conteo,
        ),
    ]..sort((a, b) => b.total.centavos.compareTo(a.total.centavos)),
    porCuenta: [
      for (final MapEntry(key: id, value: v) in porCuenta.entries)
        IngresoPorCuenta(cuenta: cuentaPorId[id]!, total: Dinero(v), porcentaje: porcentaje(v)),
    ]..sort((a, b) => b.total.centavos.compareTo(a.total.centavos)),
    meses: meses.length <= 13 ? meses : const [],
    mesMasAlto: masAlto,
    mayor: mayor,
    gastado: Dinero(gastos
        .where((g) =>
            g.estado == EstadoMovimiento.activo &&
            rango.contiene(g.fecha) &&
            (filtro == null || filtro.contains(cuentaDe(g))))
        .fold<int>(0, (s, g) => s + g.monto.centavos)),
  );
}
