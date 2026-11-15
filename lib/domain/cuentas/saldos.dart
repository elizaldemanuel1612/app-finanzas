import '../../core/ciclo.dart';
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
///
/// Con [hasta], el saldo como estaba ese momento (lo de después no cuenta);
/// `null` si la cuenta aún no llevaba saldo entonces.
Dinero? saldoDe(
  Cuenta cuenta,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  DateTime? hasta,
}) {
  if (!cuenta.llevaSaldo) return null;
  if (hasta != null && cuenta.fechaSaldoInicial.isAfter(hasta)) return null;
  bool cuenta_(DateTime fecha) =>
      !fecha.isBefore(cuenta.fechaSaldoInicial) && (hasta == null || !fecha.isAfter(hasta));
  var centavos = cuenta.saldoInicial.centavos;
  for (final m in movimientosCuenta) {
    if (m.toca(cuenta.id) && m.estado == EstadoMovimientoCuenta.activo && cuenta_(m.fecha)) {
      centavos += m.efectoEn(cuenta.id).centavos;
    }
  }
  for (final g in gastos) {
    if (cuentaDe(g) == cuenta.id && g.estado == EstadoMovimiento.activo && cuenta_(g.fecha)) {
      centavos -= g.monto.centavos;
    }
  }
  return Dinero(centavos);
}

/// Lo que hay para gastar: efectivo y débito que llevan saldo (las activas).
/// Las de crédito no entran —lo que se debe va aparte, en [sumaDeDeudas]—
/// ni las de ahorro, que van en [sumaDeAhorros].
Dinero sumaDeSaldos(
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  DateTime? hasta,
}) {
  var centavos = 0;
  for (final c in cuentas) {
    if (!c.activa || c.tipo == TipoCuenta.credito || c.tipo == TipoCuenta.ahorro) continue;
    centavos += saldoDe(c, gastos, movimientosCuenta, hasta: hasta)?.centavos ?? 0;
  }
  return Dinero(centavos);
}

/// Lo que hay en las cuentas de ahorro e inversión activas (spec §7.3.2).
Dinero sumaDeAhorros(
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  DateTime? hasta,
}) {
  var centavos = 0;
  for (final c in cuentas) {
    if (!c.activa || c.tipo != TipoCuenta.ahorro) continue;
    centavos += saldoDe(c, gastos, movimientosCuenta, hasta: hasta)?.centavos ?? 0;
  }
  return Dinero(centavos);
}

/// Todo lo que se tiene menos lo que se debe (spec §7.3.2).
final class Patrimonio {
  /// Efectivo y débito: [sumaDeSaldos].
  final Dinero disponible;

  /// Ahorro e inversiones: [sumaDeAhorros].
  final Dinero ahorros;

  /// Lo que se debe en tarjetas: [sumaDeDeudas].
  final Dinero deudas;

  const Patrimonio({required this.disponible, required this.ahorros, required this.deudas});

  Dinero get total => disponible + ahorros - deudas;
}

Patrimonio calcularPatrimonio(
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  DateTime? hasta,
}) =>
    Patrimonio(
      disponible: sumaDeSaldos(cuentas, gastos, movimientosCuenta, hasta: hasta),
      ahorros: sumaDeAhorros(cuentas, gastos, movimientosCuenta, hasta: hasta),
      deudas: sumaDeDeudas(cuentas, gastos, movimientosCuenta, hasta: hasta),
    );

/// El patrimonio al terminar un ciclo (o a hoy, en el que corre).
final class PatrimonioDeCiclo {
  final Ciclo ciclo;
  final Patrimonio patrimonio;

  /// El ciclo que corre: su cifra es la de hoy y todavía puede moverse.
  final bool enCurso;

  const PatrimonioDeCiclo({required this.ciclo, required this.patrimonio, required this.enCurso});
}

/// Cómo ha cambiado el patrimonio (spec §7.3.3): un punto por ciclo, del
/// más viejo al que corre, desde que la primera cuenta empezó a llevar
/// saldo. Cada cuenta cuenta desde su [Cuenta.fechaSaldoInicial], así que
/// dar de alta una cuenta se ve como un salto. Como mucho [maximo] ciclos.
List<PatrimonioDeCiclo> patrimonioPorCiclo({
  required List<Cuenta> cuentas,
  required List<Movimiento> gastos,
  required List<MovimientoCuenta> movimientosCuenta,
  required DateTime hoy,
  required CalculadoraCiclo calculadora,
  int maximo = 12,
}) {
  DateTime? primera;
  for (final c in cuentas) {
    if (!c.activa || !c.llevaSaldo) continue;
    if (primera == null || c.fechaSaldoInicial.isBefore(primera)) primera = c.fechaSaldoInicial;
  }
  if (primera == null || primera.isAfter(hoy)) return const [];
  final actual = calculadora.calcularPara(hoy);
  final puntos = <PatrimonioDeCiclo>[];
  var ciclo = calculadora.calcularPara(primera);
  while (true) {
    final enCurso = ciclo.id == actual.id;
    // Fin del último día del ciclo, o este momento en el que corre.
    final corte = enCurso
        ? hoy
        : DateTime(ciclo.fechaFin.year, ciclo.fechaFin.month, ciclo.fechaFin.day, 23, 59, 59, 999);
    puntos.add(PatrimonioDeCiclo(
      ciclo: ciclo,
      patrimonio: calcularPatrimonio(cuentas, gastos, movimientosCuenta, hasta: corte),
      enCurso: enCurso,
    ));
    if (enCurso) break;
    ciclo = calculadora.calcularPara(ciclo.fechaFin.add(const Duration(days: 1)));
  }
  return puntos.length > maximo ? puntos.sublist(puntos.length - maximo) : puntos;
}

/// Lo que se debe en una tarjeta de crédito que lleva saldo: positivo
/// mientras se debe; negativo si se pagó de más (saldo a favor). `null` si
/// no es de crédito o no lleva saldo.
Dinero? deudaDe(
  Cuenta cuenta,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  DateTime? hasta,
}) {
  if (cuenta.tipo != TipoCuenta.credito) return null;
  final saldo = saldoDe(cuenta, gastos, movimientosCuenta, hasta: hasta);
  return saldo == null ? null : Dinero(-saldo.centavos);
}

/// Lo que se debe en todas las tarjetas de crédito activas (sin contar los
/// saldos a favor).
Dinero sumaDeDeudas(
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta, {
  DateTime? hasta,
}) {
  var centavos = 0;
  for (final c in cuentas) {
    if (!c.activa) continue;
    final deuda = deudaDe(c, gastos, movimientosCuenta, hasta: hasta);
    if (deuda != null && deuda.esPositivo) centavos += deuda.centavos;
  }
  return Dinero(centavos);
}

typedef LecturaSaldo = ({String etiqueta, Dinero monto, bool alerta, Dinero? disponible});

/// Lo que se debe en una tarjeta a partir de su crédito disponible
/// (2026-11-07): el banco muestra cualquiera de los dos, así que al ajustar
/// se puede escribir el que se tenga a la mano. Disponible mayor que el
/// límite = saldo a favor (deuda negativa).
Dinero deudaDesdeDisponible({required Dinero limite, required Dinero disponible}) => limite - disponible;

/// Cómo se lee el saldo de [cuenta] en pantalla: en crédito, "Debes" (o
/// "A tu favor"), con lo disponible si hay límite; en las demás, "Saldo".
/// [alerta] marca lo que va en coral: saldo negativo o crédito pasado del
/// límite.
LecturaSaldo lecturaDeSaldo(Cuenta cuenta, Dinero saldo) {
  if (cuenta.tipo != TipoCuenta.credito) {
    return (etiqueta: 'Saldo', monto: saldo, alerta: saldo.esNegativo, disponible: null);
  }
  final deuda = Dinero(-saldo.centavos);
  final limite = cuenta.limite;
  final disponible = limite == null ? null : limite - deuda;
  if (deuda.esNegativo) {
    return (etiqueta: 'A tu favor', monto: saldo, alerta: false, disponible: disponible);
  }
  return (etiqueta: 'Debes', monto: deuda, alerta: disponible != null && disponible.esNegativo, disponible: disponible);
}

/// El ajuste que deja el saldo en [deseado]; `null` si ya cuadra.
({Dinero monto, bool entra})? ajusteParaSaldo({required Dinero actual, required Dinero deseado}) {
  final diferencia = deseado.centavos - actual.centavos;
  if (diferencia == 0) return null;
  return (monto: Dinero(diferencia.abs()), entra: diferencia > 0);
}

/// Para elegir al registrar un gasto: las activas, la más usada primero
/// (gastos activos); en empate, el orden de [cuentas]. Las de ahorro no
/// entran: no se paga con ellas.
List<Cuenta> ordenarCuentasPorUso(List<Cuenta> cuentas, List<Movimiento> gastos) {
  final usos = <String, int>{};
  for (final g in gastos) {
    if (g.estado == EstadoMovimiento.activo) usos[cuentaDe(g)] = (usos[cuentaDe(g)] ?? 0) + 1;
  }
  final activas = [for (final c in cuentas) if (c.activa && c.tipo != TipoCuenta.ahorro) c];
  final posicion = {for (final (i, c) in activas.indexed) c.id: i};
  return activas
    ..sort((a, b) {
      final porUso = (usos[b.id] ?? 0).compareTo(usos[a.id] ?? 0);
      return porUso != 0 ? porUso : posicion[a.id]!.compareTo(posicion[b.id]!);
    });
}

/// Las cuentas que se ofrecen al registrar (`docs/rediseno/plan-rediseno.md`,
/// Etapa 3: "solo cuentas reales"). La cuenta base genérica "Tarjeta" se
/// esconde en cuanto hay una tarjeta real (débito o crédito activa), y la
/// base "Efectivo", si el usuario dio de alta otra de efectivo. [conservar]
/// (la cuenta del gasto que se edita) se queda siempre.
///
/// Una base que el usuario renombró ya no es genérica: es su cuenta real
/// (por ejemplo, "Tarjeta" convertida en "Banamex platino") y nunca se
/// esconde.
List<Cuenta> cuentasParaRegistrar(List<Cuenta> ordenadas, {String? conservar}) {
  bool hay(bool Function(Cuenta) condicion) => ordenadas.any((c) => c.activa && condicion(c));
  final nombresBase = {for (final b in cuentasBase(DateTime(2000))) b.id: b.nombre};
  bool generica(Cuenta c, String id) => c.id == id && c.nombre.trim() == nombresBase[id];
  final tarjetaReal = hay((c) => !generica(c, idCuentaTarjeta) && (c.tipo == TipoCuenta.debito || c.tipo == TipoCuenta.credito));
  final efectivoReal = hay((c) => !generica(c, idCuentaEfectivo) && c.tipo == TipoCuenta.efectivo);
  return [
    for (final c in ordenadas)
      if (c.id == conservar ||
          !((generica(c, idCuentaTarjeta) && tarjetaReal) || (generica(c, idCuentaEfectivo) && efectivoReal)))
        c,
  ];
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
/// las activas aunque no tengan gasto, y las archivadas que sí tengan. Las
/// de ahorro solo si tienen gasto: no se paga con ellas.
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
    if ((!c.activa || c.tipo == TipoCuenta.ahorro) && suyos.isEmpty) continue;
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
