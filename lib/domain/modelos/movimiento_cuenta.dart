import '../../core/money.dart';

/// Abono: entra dinero a la cuenta. Ajuste: corrige el saldo para que
/// cuadre con el banco. Transferencia: pasa dinero de una cuenta a otra
/// (retirar efectivo, pagar la tarjeta de crédito); no es gasto
/// (spec-app-finanzas-v2.md §7.3.1).
enum TipoMovimientoCuenta { abono, ajuste, transferencia }

enum EstadoMovimientoCuenta { activo, anulado }

/// Dinero que entra o se corrige en una cuenta sin ser un gasto: no toca
/// categorías ni presupuesto. Registro financiero: se anula, no se borra
/// (regla #3). Espejo del documento `movimientosCuenta/{clientId}`.
final class MovimientoCuenta {
  final String clientId;
  final String cuentaId;
  final DateTime fecha;

  /// Siempre positivo; [entra] dice el sentido.
  final Dinero monto;
  final TipoMovimientoCuenta tipo;

  /// Un abono siempre entra; un ajuste puede subir o bajar el saldo.
  final bool entra;
  final String nota;
  final EstadoMovimientoCuenta estado;

  /// El ingreso del ciclo que se creó con este abono, si se marcó así.
  final String? ingresoExtraId;

  /// A dónde va el dinero, solo en una transferencia ([cuentaId] es de
  /// dónde sale).
  final String? cuentaDestinoId;

  const MovimientoCuenta({
    required this.clientId,
    required this.cuentaId,
    required this.fecha,
    required this.monto,
    required this.tipo,
    required this.entra,
    this.nota = '',
    this.estado = EstadoMovimientoCuenta.activo,
    this.ingresoExtraId,
    this.cuentaDestinoId,
  });

  /// Lo que mueve el saldo de la cuenta en la que se registró: positivo si
  /// entra. En una transferencia, lo que sale del origen.
  Dinero get efecto => entra ? monto : Dinero(-monto.centavos);

  /// ¿Toca a la cuenta [id]? Una transferencia toca a las dos.
  bool toca(String id) => cuentaId == id || cuentaDestinoId == id;

  /// Lo que mueve el saldo de la cuenta [id]: una transferencia resta en el
  /// origen y suma en el destino; lo demás, solo en su cuenta.
  Dinero efectoEn(String id) {
    if (tipo == TipoMovimientoCuenta.transferencia) {
      if (cuentaDestinoId == id) return monto;
      if (cuentaId == id) return Dinero(-monto.centavos);
      return const Dinero.cero();
    }
    return cuentaId == id ? efecto : const Dinero.cero();
  }

  MovimientoCuenta anulado() => MovimientoCuenta(
        clientId: clientId,
        cuentaId: cuentaId,
        fecha: fecha,
        monto: monto,
        tipo: tipo,
        entra: entra,
        nota: nota,
        estado: EstadoMovimientoCuenta.anulado,
        ingresoExtraId: ingresoExtraId,
        cuentaDestinoId: cuentaDestinoId,
      );

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'cuentaId': cuentaId,
        'fecha': fecha.toIso8601String(),
        'montoCentavos': monto.centavos,
        'tipo': tipo.name,
        'entra': entra,
        'nota': nota,
        'estado': estado.name,
        if (ingresoExtraId != null) 'ingresoExtraId': ingresoExtraId,
        if (cuentaDestinoId != null) 'cuentaDestinoId': cuentaDestinoId,
      };

  factory MovimientoCuenta.fromJson(Map<String, dynamic> json) => MovimientoCuenta(
        clientId: json['clientId'] as String,
        cuentaId: json['cuentaId'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        monto: Dinero(json['montoCentavos'] as int),
        tipo: TipoMovimientoCuenta.values.byName(json['tipo'] as String),
        entra: json['entra'] as bool,
        nota: json['nota'] as String? ?? '',
        estado: EstadoMovimientoCuenta.values.byName(json['estado'] as String),
        ingresoExtraId: json['ingresoExtraId'] as String?,
        cuentaDestinoId: json['cuentaDestinoId'] as String?,
      );
}
