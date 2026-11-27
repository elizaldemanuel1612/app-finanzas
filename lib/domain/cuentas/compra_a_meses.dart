import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/cuenta.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../reglas/creacion_movimiento.dart';

// Compras a meses sin intereses (spec-app-finanzas-v2.md §7.3.1,
// 2026-11-16): una compra a N meses son N gastos, uno por mensualidad, cada
// uno en el ciclo de su fecha. Así el presupuesto de cada ciclo y el pago
// de cada corte de la tarjeta cargan solo su mensualidad.

/// Los plazos que se ofrecen al registrar.
const plazosAMeses = [3, 6, 9, 12, 18, 24];

/// Lo más que se acepta (también al importar).
const maxMeses = 48;

/// "Compra hoy y empieza a pagar en N meses" (2026-11-27): las
/// promociones de pago diferido de las tarjetas y tiendas departamentales.
/// La primera mensualidad (o el único pago) llega N meses después de la
/// compra; mientras, no se paga nada de ella, pero ya es deuda.
const plazosDiferidos = [2, 3, 4, 6];

/// Lo más que se acepta diferir.
const maxDiferido = 12;

/// El total entre [meses]: al centavo hacia abajo, y lo que sobra en la
/// primera. Siempre suma el total exacto.
List<Dinero> repartirEnMensualidades(Dinero total, int meses) {
  final base = total.centavos ~/ meses;
  final resto = total.centavos - base * meses;
  return [for (var i = 0; i < meses; i++) Dinero(i == 0 ? base + resto : base)];
}

/// La fecha de la mensualidad [numero] (1 = el día de la compra): un mes
/// después por cada una, mismo día y hora; en meses más cortos, el último.
DateTime fechaDeMensualidad(DateTime compra, int numero) {
  final mes = compra.month + numero - 1;
  final ultimo = DateTime(compra.year, mes + 1, 0).day;
  return DateTime(
    compra.year,
    mes,
    compra.day < ultimo ? compra.day : ultimo,
    compra.hour,
    compra.minute,
    compra.second,
  );
}

/// El `clientId` de la mensualidad [numero]: estable, para que reimportar
/// o reintentar no duplique (regla #2).
String clientIdDeMensualidad(String compraId, int numero) => '$compraId-m$numero';

/// Las [meses] mensualidades de una compra de [total], listas para guardar.
/// Cada una pasa por `crearMovimiento` (reglas #1, #2, #5, #18).
///
/// Con [diferido] (> 0) la primera llega [diferido] meses después de
/// [fecha], y cada mensualidad cuenta en el ciclo en que se paga. Diferida,
/// puede ser de un solo pago ([meses] = 1): "paga en 3 meses".
Resultado<List<Movimiento>> crearCompraAMeses({
  required String compraId,
  required DateTime fecha,
  required CalculadoraCiclo calculadoraCiclo,
  required Dinero total,
  required int meses,
  required String categoriaId,
  required String descripcion,
  required OrigenCaptura origenCaptura,
  required String? cuentaId,
  int diferido = 0,
}) {
  if (diferido < 0 || diferido > maxDiferido) return Falla('El primer pago se puede diferir hasta $maxDiferido meses.');
  final minimo = diferido > 0 ? 1 : 2;
  if (meses < minimo || meses > maxMeses) return Falla('Una compra a meses va de $minimo a $maxMeses meses.');
  if (total.centavos < meses) return Falla('El monto es muy chico para dividirlo en $meses meses.');
  final montos = repartirEnMensualidades(total, meses);
  final lista = <Movimiento>[];
  for (var n = 1; n <= meses; n++) {
    final creado = crearMovimiento(
      clientId: clientIdDeMensualidad(compraId, n),
      fecha: fechaDeMensualidad(fecha, diferido + n),
      calculadoraCiclo: calculadoraCiclo,
      monto: montos[n - 1],
      categoriaId: categoriaId,
      medio: MedioPago.tarjeta,
      descripcion: descripcion,
      origenCaptura: origenCaptura,
    );
    switch (creado) {
      case Falla(:final mensaje):
        return Falla(mensaje);
      case Exito(:final valor):
        lista.add(valor.copyWith(
          cuentaId: cuentaId,
          compraId: compraId,
          mensualidad: n,
          meses: meses,
          diferido: diferido > 0 ? diferido : null,
        ));
    }
  }
  return Exito(lista);
}

/// Las mensualidades de [compraId], en orden.
List<Movimiento> mensualidadesDe(String compraId, List<Movimiento> movimientos) =>
    [for (final m in movimientos) if (m.compraId == compraId) m]
      ..sort((a, b) => (a.mensualidad ?? 0).compareTo(b.mensualidad ?? 0));

/// Lo que viene de compras a meses en [cuenta]: las mensualidades activas
/// con fecha después de hoy. Es parte de lo que se debe, pero no se paga
/// en este corte.
Dinero porPagarAMeses(Cuenta cuenta, List<Movimiento> gastos, {required DateTime hoy}) {
  final finDeHoy = DateTime(hoy.year, hoy.month, hoy.day + 1);
  return Dinero.suma([
    for (final g in gastos)
      if (g.esAMeses && g.estado == EstadoMovimiento.activo && cuentaDe(g) == cuenta.id && !g.fecha.isBefore(finDeHoy))
        g.monto,
  ]);
}

/// Una compra a meses vista entera: para el detalle de la tarjeta y la
/// vista "A meses" de Análisis.
final class CompraAMeses {
  final String compraId;
  final String descripcion;
  final String cuentaId;
  final Dinero total;
  final Dinero mensualidad;
  final int meses;

  /// Las que ya pasaron (su fecha es hoy o antes).
  final int pagadas;

  /// Lo de las que ya pasaron.
  final Dinero pagado;

  /// Lo que falta: las mensualidades futuras.
  final Dinero falta;

  /// La siguiente mensualidad por pagar; `null` si ya no hay.
  final DateTime? proximoPago;

  /// La primera mensualidad.
  final DateTime primerPago;

  /// Meses que se difirió el primer pago (0 si no).
  final int diferido;

  const CompraAMeses({
    required this.compraId,
    required this.descripcion,
    required this.cuentaId,
    required this.total,
    required this.mensualidad,
    required this.meses,
    required this.pagadas,
    required this.pagado,
    required this.falta,
    required this.proximoPago,
    required this.primerPago,
    this.diferido = 0,
  });

  bool get terminada => pagadas >= meses;

  /// Diferida y sin ningún pago todavía: "empiezas a pagar en marzo".
  bool get porEmpezar => pagadas == 0;

  /// Un solo pago diferido ("paga en 3 meses"), no mensualidades.
  bool get unSoloPago => meses == 1;
}

/// Las compras a meses activas de [cuenta] que aún tienen mensualidades por
/// venir, de la más reciente a la más vieja.
List<CompraAMeses> comprasAMesesDe(Cuenta cuenta, List<Movimiento> gastos, {required DateTime hoy}) =>
    comprasAMesesVigentes(gastos, hoy: hoy, soloCuentas: {cuenta.id});

/// Las compras a meses activas con mensualidades por venir, de todas las
/// cuentas o solo de [soloCuentas] (vacío = todas), de la más reciente a la
/// más vieja (por su primer pago).
List<CompraAMeses> comprasAMesesVigentes(List<Movimiento> gastos, {required DateTime hoy, Set<String> soloCuentas = const {}}) {
  final finDeHoy = DateTime(hoy.year, hoy.month, hoy.day + 1);
  final porCompra = <String, List<Movimiento>>{};
  for (final g in gastos) {
    if (!g.esAMeses || g.estado != EstadoMovimiento.activo) continue;
    if (soloCuentas.isNotEmpty && !soloCuentas.contains(cuentaDe(g))) continue;
    porCompra.putIfAbsent(g.compraId!, () => []).add(g);
  }
  final compras = <CompraAMeses>[];
  for (final MapEntry(key: id, value: lista) in porCompra.entries) {
    lista.sort((a, b) => (a.mensualidad ?? 0).compareTo(b.mensualidad ?? 0));
    final futuras = [for (final m in lista) if (!m.fecha.isBefore(finDeHoy)) m];
    if (futuras.isEmpty) continue;
    final pasadas = [for (final m in lista) if (m.fecha.isBefore(finDeHoy)) m];
    final meses = lista.first.meses ?? lista.length;
    compras.add(CompraAMeses(
      compraId: id,
      descripcion: lista.first.descripcion,
      cuentaId: cuentaDe(lista.first),
      total: Dinero.suma(lista.map((m) => m.monto)),
      mensualidad: lista.last.monto,
      meses: meses,
      pagadas: meses - futuras.length,
      pagado: Dinero.suma(pasadas.map((m) => m.monto)),
      falta: Dinero.suma(futuras.map((m) => m.monto)),
      proximoPago: futuras.first.fecha,
      primerPago: lista.first.fecha,
      diferido: lista.first.diferido ?? 0,
    ));
  }
  compras.sort((a, b) => b.primerPago.compareTo(a.primerPago));
  return compras;
}
