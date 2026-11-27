import '../../core/money.dart';
import '../modelos/cuenta.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'compra_a_meses.dart';

// Análisis › A meses (spec-app-finanzas-v2.md §7.3.1, 2026-11-27): cuánto
// se debe a meses sin intereses y cuánto se paga al mes solo de eso, para
// que el usuario lo tenga presente antes de endeudarse más.

/// Lo que se paga a meses en un mes del calendario.
final class PagoDelMes {
  /// Día 1 del mes.
  final DateTime mes;
  final Dinero monto;

  const PagoDelMes(this.mes, this.monto);
}

/// Lo que se debe a meses de una cuenta.
final class DeudaAMesesDeCuenta {
  final String cuentaId;
  final Dinero debes;
  final Dinero esteMes;
  final int compras;

  const DeudaAMesesDeCuenta({required this.cuentaId, required this.debes, required this.esteMes, required this.compras});
}

final class ResumenAMeses {
  /// Las compras con mensualidades por venir, de la más reciente a la más
  /// vieja.
  final List<CompraAMeses> compras;

  /// Lo que falta de todas: lo que se debe a meses.
  final Dinero debes;

  /// Lo que ya se pagó de esas mismas compras.
  final Dinero pagado;

  /// Lo que se paga a meses este mes y los [mesesAdelante] − 1 siguientes;
  /// el primero es este mes.
  final List<PagoDelMes> proximosMeses;

  /// Por cuenta, de la que más se debe a la que menos.
  final List<DeudaAMesesDeCuenta> porCuenta;

  const ResumenAMeses({
    required this.compras,
    required this.debes,
    required this.pagado,
    required this.proximosMeses,
    required this.porCuenta,
  });

  bool get vacio => compras.isEmpty;

  /// Lo que se paga a meses este mes.
  Dinero get esteMes => proximosMeses.first.monto;

  /// Lo del mes siguiente, para decir si sube o baja.
  Dinero get siguienteMes => proximosMeses[1].monto;

  /// El total de las compras vigentes (pagado + lo que falta).
  Dinero get total => pagado + debes;

  /// Compras diferidas que todavía no empiezan a cobrarse.
  List<CompraAMeses> get porEmpezar => [for (final c in compras) if (c.porEmpezar) c];

  /// El primer mes, desde el siguiente, en que se paga menos que este; `null`
  /// si no baja en los meses que se ven.
  PagoDelMes? get primerAlivio {
    for (final p in proximosMeses.skip(1)) {
      if (p.monto < esteMes) return p;
    }
    return null;
  }

  /// El primer mes, desde el siguiente, en que se paga más que este (una
  /// compra diferida que empieza, por ejemplo); `null` si no sube.
  PagoDelMes? get primerAumento {
    for (final p in proximosMeses.skip(1)) {
      if (p.monto > esteMes) return p;
    }
    return null;
  }

  /// El último mes con algo por pagar; `null` si no hay nada.
  DateTime? get ultimoPago {
    DateTime? ultimo;
    for (final c in compras) {
      final fin = fechaDeMensualidad(c.primerPago, c.meses);
      if (ultimo == null || fin.isAfter(ultimo)) ultimo = fin;
    }
    return ultimo;
  }

  /// De cada $100 de [ingreso], cuánto se va a meses este mes; `null` sin
  /// ingreso.
  int? porcentajeDe(Dinero ingreso) =>
      ingreso.esPositivo ? (esteMes.centavos * 100 / ingreso.centavos).round() : null;
}

/// Junta las compras a meses de [gastos] (solo de [soloCuentas] si no está
/// vacío). [cuentas] solo ordena y nombra el desglose por cuenta: las
/// compras de una cuenta que ya no existe entran igual.
ResumenAMeses resumirComprasAMeses({
  required List<Movimiento> gastos,
  required DateTime hoy,
  Set<String> soloCuentas = const {},
  int mesesAdelante = 12,
}) {
  final compras = comprasAMesesVigentes(gastos, hoy: hoy, soloCuentas: soloCuentas);
  final ids = {for (final c in compras) c.compraId};
  final porMes = List<int>.filled(mesesAdelante, 0);
  final esteMesPorCuenta = <String, int>{};
  for (final g in gastos) {
    if (!ids.contains(g.compraId) || g.estado != EstadoMovimiento.activo) continue;
    final k = (g.fecha.year - hoy.year) * 12 + g.fecha.month - hoy.month;
    if (k < 0 || k >= mesesAdelante) continue;
    porMes[k] += g.monto.centavos;
    if (k == 0) esteMesPorCuenta[cuentaDe(g)] = (esteMesPorCuenta[cuentaDe(g)] ?? 0) + g.monto.centavos;
  }
  final debesPorCuenta = <String, int>{};
  final comprasPorCuenta = <String, int>{};
  for (final c in compras) {
    debesPorCuenta[c.cuentaId] = (debesPorCuenta[c.cuentaId] ?? 0) + c.falta.centavos;
    comprasPorCuenta[c.cuentaId] = (comprasPorCuenta[c.cuentaId] ?? 0) + 1;
  }
  final porCuenta = [
    for (final MapEntry(key: id, value: debes) in debesPorCuenta.entries)
      DeudaAMesesDeCuenta(
        cuentaId: id,
        debes: Dinero(debes),
        esteMes: Dinero(esteMesPorCuenta[id] ?? 0),
        compras: comprasPorCuenta[id]!,
      ),
  ]..sort((a, b) => b.debes.compareTo(a.debes));
  return ResumenAMeses(
    compras: compras,
    debes: Dinero.suma(compras.map((c) => c.falta)),
    pagado: Dinero.suma(compras.map((c) => c.pagado)),
    proximosMeses: [
      for (var k = 0; k < mesesAdelante; k++) PagoDelMes(DateTime(hoy.year, hoy.month + k), Dinero(porMes[k])),
    ],
    porCuenta: porCuenta,
  );
}

/// Las cuentas que se ofrecen para filtrar: las que tienen compras a meses
/// vigentes, aunque ya estén archivadas.
List<Cuenta> cuentasConMeses(List<Cuenta> cuentas, ResumenAMeses todas) {
  final conCompras = {for (final c in todas.porCuenta) c.cuentaId};
  return [
    for (final c in cuentas)
      if (conCompras.contains(c.id)) c,
  ];
}
