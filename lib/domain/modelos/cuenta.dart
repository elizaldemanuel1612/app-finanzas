import '../../core/money.dart';
import 'movimiento.dart';

/// De dónde sale el dinero de un gasto (spec-app-finanzas-v2.md §7.3.1).
enum TipoCuenta {
  efectivo('Efectivo'),
  debito('Débito'),
  credito('Crédito');

  final String etiqueta;

  const TipoCuenta(this.etiqueta);

  /// El medio de pago de siempre, que sigue viviendo en cada movimiento.
  MedioPago get medio => this == TipoCuenta.efectivo ? MedioPago.efectivo : MedioPago.tarjeta;
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

  /// Si se le lleva saldo. Débito siempre; efectivo, si el usuario quiere;
  /// crédito, nunca (lo que debe no es un saldo disponible).
  final bool llevaSaldo;

  /// Lo que había el día [fechaSaldoInicial]; los movimientos de antes no
  /// cuentan para el saldo.
  final Dinero saldoInicial;
  final DateTime fechaSaldoInicial;
  final bool activa;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.tipo,
    required this.llevaSaldo,
    required this.saldoInicial,
    required this.fechaSaldoInicial,
    this.activa = true,
  });

  Cuenta copyWith({
    String? nombre,
    String? emoji,
    TipoCuenta? tipo,
    bool? llevaSaldo,
    Dinero? saldoInicial,
    DateTime? fechaSaldoInicial,
    bool? activa,
  }) {
    final nuevoTipo = tipo ?? this.tipo;
    return Cuenta(
      id: id,
      nombre: nombre ?? this.nombre,
      emoji: emoji ?? this.emoji,
      tipo: nuevoTipo,
      llevaSaldo: switch (nuevoTipo) {
        TipoCuenta.debito => true,
        TipoCuenta.credito => false,
        TipoCuenta.efectivo => llevaSaldo ?? this.llevaSaldo,
      },
      saldoInicial: saldoInicial ?? this.saldoInicial,
      fechaSaldoInicial: fechaSaldoInicial ?? this.fechaSaldoInicial,
      activa: activa ?? this.activa,
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
