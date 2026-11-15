import '../../core/money.dart';
import 'movimiento.dart';

/// De dónde sale el dinero de un gasto (spec-app-finanzas-v2.md §7.3.1).
enum TipoCuenta {
  efectivo('Efectivo'),
  debito('Débito'),
  credito('Crédito'),

  /// Ahorro o inversión (spec §7.3.2): dinero apartado. No se paga con
  /// ella; se le transfiere y se ajusta su valor. Siempre lleva saldo.
  ahorro('Ahorro');

  final String etiqueta;

  const TipoCuenta(this.etiqueta);

  /// El medio de pago de siempre, que sigue viviendo en cada movimiento.
  MedioPago get medio => this == TipoCuenta.efectivo ? MedioPago.efectivo : MedioPago.tarjeta;

  /// Débito y ahorro no tienen sentido sin saldo; en efectivo y crédito es
  /// opcional.
  bool get siempreLlevaSaldo => this == TipoCuenta.debito || this == TipoCuenta.ahorro;
}

/// Ids de las dos cuentas que siempre existen. Los gastos de antes de las
/// cuentas (sin `cuentaId`) caen en una u otra según su medio.
const idCuentaEfectivo = 'efectivo';
const idCuentaTarjeta = 'tarjeta';

/// Una tarjeta o el efectivo. Espejo del documento `cuentas/{cuentaId}`.
/// Se archiva ([activa] en `false`), nunca se borra: tiene historial.
final class Cuenta {
  final String id;
  final String nombre;
  final String emoji;
  final TipoCuenta tipo;

  /// Si se le lleva saldo. Débito siempre; efectivo y crédito, si el
  /// usuario quiere. En crédito el saldo es negativo mientras se debe: cada
  /// gasto lo baja y cada pago o devolución lo sube (ver `deudaDe`).
  final bool llevaSaldo;

  /// Lo que había el día [fechaSaldoInicial]; los movimientos de antes no
  /// cuentan para el saldo. En crédito, menos lo que se debía ese día.
  final Dinero saldoInicial;
  final DateTime fechaSaldoInicial;
  final bool activa;

  /// Límite de crédito, si el usuario lo dio. Solo crédito.
  final Dinero? limite;

  /// Día de corte y día límite de pago (1–31), si el usuario los dio. Solo
  /// crédito (spec §7.3.1, 2026-11-15); las fechas salen de
  /// `domain/cuentas/fechas_tarjeta.dart`.
  final int? diaCorte;
  final int? diaPago;

  /// Si es un apartado (spec §7.3.5, 2026-11-15): la cuenta de débito o de
  /// ahorro donde vive. Un apartado siempre es de ahorro. No cambia al
  /// editar: mover un apartado a otra cuenta sería otra cosa.
  final String? cuentaPadreId;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.tipo,
    required this.llevaSaldo,
    required this.saldoInicial,
    required this.fechaSaldoInicial,
    this.activa = true,
    this.limite,
    this.diaCorte,
    this.diaPago,
    this.cuentaPadreId,
  });

  /// Un apartado dentro de otra cuenta (spec §7.3.5).
  bool get esApartado => cuentaPadreId != null;

  /// Solo débito y ahorro que no sean ya apartados pueden tener apartados.
  bool get puedeTenerApartados => !esApartado && (tipo == TipoCuenta.debito || tipo == TipoCuenta.ahorro);

  Cuenta copyWith({
    String? nombre,
    String? emoji,
    TipoCuenta? tipo,
    bool? llevaSaldo,
    Dinero? saldoInicial,
    DateTime? fechaSaldoInicial,
    bool? activa,
    Dinero? Function()? limite,
    int? Function()? diaCorte,
    int? Function()? diaPago,
  }) {
    final credito = (tipo ?? this.tipo) == TipoCuenta.credito;
    final nuevoTipo = tipo ?? this.tipo;
    return Cuenta(
      id: id,
      nombre: nombre ?? this.nombre,
      emoji: emoji ?? this.emoji,
      tipo: nuevoTipo,
      llevaSaldo: nuevoTipo.siempreLlevaSaldo || (llevaSaldo ?? this.llevaSaldo),
      saldoInicial: saldoInicial ?? this.saldoInicial,
      fechaSaldoInicial: fechaSaldoInicial ?? this.fechaSaldoInicial,
      activa: activa ?? this.activa,
      limite: nuevoTipo != TipoCuenta.credito ? null : (limite != null ? limite() : this.limite),
      diaCorte: !credito ? null : (diaCorte != null ? diaCorte() : this.diaCorte),
      diaPago: !credito ? null : (diaPago != null ? diaPago() : this.diaPago),
      cuentaPadreId: cuentaPadreId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'tipo': tipo.name,
        'llevaSaldo': llevaSaldo,
        'saldoInicialCentavos': saldoInicial.centavos,
        'fechaSaldoInicial': fechaSaldoInicial.toIso8601String(),
        'activa': activa,
        if (limite != null) 'limiteCentavos': limite!.centavos,
        if (diaCorte != null) 'diaCorte': diaCorte,
        if (diaPago != null) 'diaPago': diaPago,
        if (cuentaPadreId != null) 'cuentaPadreId': cuentaPadreId,
      };

  factory Cuenta.fromJson(Map<String, dynamic> json) => Cuenta(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        emoji: json['emoji'] as String,
        tipo: TipoCuenta.values.byName(json['tipo'] as String),
        llevaSaldo: json['llevaSaldo'] as bool,
        saldoInicial: Dinero(json['saldoInicialCentavos'] as int),
        fechaSaldoInicial: DateTime.parse(json['fechaSaldoInicial'] as String),
        activa: json['activa'] as bool? ?? true,
        limite: json['limiteCentavos'] == null ? null : Dinero(json['limiteCentavos'] as int),
        diaCorte: json['diaCorte'] as int?,
        diaPago: json['diaPago'] as int?,
        cuentaPadreId: json['cuentaPadreId'] as String?,
      );
}

/// Las dos cuentas base, como se crean la primera vez.
List<Cuenta> cuentasBase(DateTime ahora) => [
      Cuenta(
        id: idCuentaTarjeta,
        nombre: 'Tarjeta',
        emoji: '💳',
        tipo: TipoCuenta.credito,
        llevaSaldo: false,
        saldoInicial: const Dinero.cero(),
        fechaSaldoInicial: ahora,
      ),
      Cuenta(
        id: idCuentaEfectivo,
        nombre: 'Efectivo',
        emoji: '💵',
        tipo: TipoCuenta.efectivo,
        llevaSaldo: false,
        saldoInicial: const Dinero.cero(),
        fechaSaldoInicial: ahora,
      ),
    ];

/// La cuenta de un gasto: la suya o, si es de antes de las cuentas, la base
/// que corresponde a su medio.
String cuentaDe(Movimiento m) =>
    m.cuentaId ?? (m.medio == MedioPago.efectivo ? idCuentaEfectivo : idCuentaTarjeta);
