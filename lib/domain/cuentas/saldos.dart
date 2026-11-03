import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/cuenta.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../modelos/movimiento_cuenta.dart';

/// Saldo de [cuenta] (spec-app-finanzas-v2.md §7.3.1): se calcula siempre,
/// nunca se guarda, así editar o anular un gasto lo corrige solo. Cuenta lo
/// que pasó desde [Cuenta.fechaSaldoInicial] (inclusive). `null` si la
/// cuenta no lleva saldo.
Dinero? saldoDe(Cuenta cuenta, List<Movimiento> gastos, List<MovimientoCuenta> movimientosCuenta) {
  if (!cuenta.llevaSaldo) return null;
  bool cuenta_(DateTime fecha) => !fecha.isBefore(cuenta.fechaSaldoInicial);
  var centavos = cuenta.saldoInicial.centavos;
  for (final m in movimientosCuenta) {
    if (m.cuentaId == cuenta.id && m.estado == EstadoMovimientoCuenta.activo && cuenta_(m.fecha)) {
      centavos += m.efecto.centavos;
    }
  }
  for (final g in gastos) {
    if (cuentaDe(g) == cuenta.id && g.estado == EstadoMovimiento.activo && cuenta_(g.fecha)) {
      centavos -= g.monto.centavos;
    }
  }
  return Dinero(centavos);
}

/// El ajuste que deja el saldo en [deseado]; `null` si ya cuadra.
({Dinero monto, bool entra})? ajusteParaSaldo({required Dinero actual, required Dinero deseado}) {
  final diferencia = deseado.centavos - actual.centavos;
  if (diferencia == 0) return null;
  return (monto: Dinero(diferencia.abs()), entra: diferencia > 0);
}

/// Para elegir al registrar un gasto: las activas, la más usada primero
/// (gastos activos); en empate, el orden de [cuentas].
List<Cuenta> ordenarCuentasPorUso(List<Cuenta> cuentas, List<Movimiento> gastos) {
  final usos = <String, int>{};
  for (final g in gastos) {
    if (g.estado == EstadoMovimiento.activo) usos[cuentaDe(g)] = (usos[cuentaDe(g)] ?? 0) + 1;
  }
  final activas = [for (final c in cuentas) if (c.activa) c];
  final posicion = {for (final (i, c) in activas.indexed) c.id: i};
  return activas
    ..sort((a, b) {
      final porUso = (usos[b.id] ?? 0).compareTo(usos[a.id] ?? 0);
      return porUso != 0 ? porUso : posicion[a.id]!.compareTo(posicion[b.id]!);
    });
}

/// La cuenta del último gasto registrado (el último de [gastos], que se
/// guardan en orden), para proponerla al registrar el siguiente.
String? ultimaCuentaUsada(List<Movimiento> gastos) {
  for (final g in gastos.reversed) {
    if (g.estado == EstadoMovimiento.activo) return cuentaDe(g);
  }
  return null;
}

/// Una cuenta en el análisis "Cuentas".
final class ResumenCuenta {
  final Cuenta cuenta;
  final Dinero gastado;
  final int conteo;

  /// Porcentaje entero del gasto del ciclo.
  final int porcentaje;

  /// Hasta 3 categorías donde más se gastó con esta cuenta.
  final List<({Categoria categoria, Dinero total})> principales;

  /// `null` si la cuenta no lleva saldo.
  final Dinero? saldo;

  const ResumenCuenta({
    required this.cuenta,
    required this.gastado,
    required this.conteo,
    required this.porcentaje,
    required this.principales,
    required this.saldo,
  });
}

/// Por cuenta, lo gastado en el ciclo [cicloId], de mayor a menor. Entran
/// las activas aunque no tengan gasto, y las archivadas que sí tengan.
List<ResumenCuenta> resumenPorCuenta({
  required List<Cuenta> cuentas,
  required List<Categoria> categorias,
  required List<Movimiento> gastos,
  required List<MovimientoCuenta> movimientosCuenta,
  required String cicloId,
}) {
  final delCiclo = [
    for (final g in gastos)
      if (g.cicloId == cicloId && g.estado == EstadoMovimiento.activo) g,
  ];
  final total = delCiclo.fold<int>(0, (s, g) => s + g.monto.centavos);
  final categoriaPorId = {for (final c in categorias) c.id: c};
  final resumenes = <ResumenCuenta>[];
  for (final c in cuentas) {
    final suyos = [for (final g in delCiclo) if (cuentaDe(g) == c.id) g];
    if (!c.activa && suyos.isEmpty) continue;
    final gastado = suyos.fold<int>(0, (s, g) => s + g.monto.centavos);
    final porCategoria = <String, int>{};
    for (final g in suyos) {
      porCategoria[g.categoriaId] = (porCategoria[g.categoriaId] ?? 0) + g.monto.centavos;
    }
    final principales = [
      for (final e in porCategoria.entries)
        if (categoriaPorId[e.key] != null) (categoria: categoriaPorId[e.key]!, total: Dinero(e.value)),
    ]..sort((a, b) => b.total.compareTo(a.total));
    resumenes.add(ResumenCuenta(
      cuenta: c,
      gastado: Dinero(gastado),
      conteo: suyos.length,
      porcentaje: total == 0 ? 0 : (gastado * 100 + total ~/ 2) ~/ total,
      principales: principales.take(3).toList(),
      saldo: saldoDe(c, gastos, movimientosCuenta),
    ));
  }
  return resumenes..sort((a, b) => b.gastado.compareTo(a.gastado));
}
