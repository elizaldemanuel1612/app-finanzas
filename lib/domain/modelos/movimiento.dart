import '../../core/money.dart';
import 'estado_movimiento.dart';

enum MedioPago { tarjeta, efectivo }

/// Cómo se originó la captura del movimiento (spec-app-finanzas-v2.md §1.4,
/// paquete-construccion-final.md §4). [migracion] es para los `HIST-####`
/// importados del Excel (spec-app-finanzas-v2.md §8.1) — nace `activo`
/// igual que una captura manual, porque ya es dinero que de verdad se
/// movió, no algo que el sistema generó solo.
enum OrigenCaptura { manual, voz, ticket, recurrente, migracion }

/// Marca los movimientos migrados desde el Excel histórico que llegaron
/// como totales diarios agregados, sin detalle por compra (spec-app-
/// finanzas-v2.md §8.2). `null` significa detalle normal.
enum Granularidad { agregadoDiario }

/// Un movimiento financiero. Espejo del documento `movimientos/{movId}`
/// (paquete-construccion-final.md §4).
///
/// Es un contenedor de datos inmutable a propósito: no expone un `copyWith`
/// que permita cambiar [cicloId] después de creado (regla no negociable #5:
/// el ciclo se asigna al crear y jamás se recalcula). Quien necesite "editar"
/// un movimiento construye uno nuevo reusando el [cicloId] original — el
/// dominio no ofrece un atajo que lo pierda por accidente.
final class Movimiento {
  final String? id;
  final String clientId;
  final DateTime fecha;
  final String cicloId;
  final String periodoNatural;
  final Dinero monto;
  final String categoriaId;
  final MedioPago medio;
  final String descripcion;
  final EstadoMovimiento estado;
  final OrigenCaptura origenCaptura;
  final String? ticketId;
  final String? fotoUrl;
  final bool esReembolsable;
  final String? reembolsoId;
  final bool clasificadoPorIA;
  final double? confianzaIA;
  final Granularidad? granularidad;

  /// Id del renglón en el Excel de origen (ej. "HIST-0001"), solo para
  /// movimientos migrados (spec-app-finanzas-v2.md §8.1).
  final String? idOrigen;

  const Movimiento({
    this.id,
    required this.clientId,
    required this.fecha,
    required this.cicloId,
    required this.periodoNatural,
    required this.monto,
    required this.categoriaId,
    required this.medio,
    required this.descripcion,
    required this.estado,
    required this.origenCaptura,
    this.ticketId,
    this.fotoUrl,
    this.esReembolsable = false,
    this.reembolsoId,
    this.clasificadoPorIA = false,
    this.confianzaIA,
    this.granularidad,
    this.idOrigen,
  });

  /// Copia con cambios — a propósito **no** acepta [cicloId] como
  /// parámetro. El ciclo se asigna una vez al crear y jamás se recalcula
  /// (regla no negociable #5); si necesitas cambiarlo, no es una edición,
  /// es un movimiento distinto.
  Movimiento copyWith({
    String? id,
    String? clientId,
    DateTime? fecha,
    String? periodoNatural,
    Dinero? monto,
    String? categoriaId,
    MedioPago? medio,
    String? descripcion,
    EstadoMovimiento? estado,
    OrigenCaptura? origenCaptura,
    String? ticketId,
    String? fotoUrl,
    bool? esReembolsable,
    String? reembolsoId,
    bool? clasificadoPorIA,
    double? confianzaIA,
    Granularidad? granularidad,
    String? idOrigen,
  }) =>
      Movimiento(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        fecha: fecha ?? this.fecha,
        cicloId: cicloId,
        periodoNatural: periodoNatural ?? this.periodoNatural,
        monto: monto ?? this.monto,
        categoriaId: categoriaId ?? this.categoriaId,
        medio: medio ?? this.medio,
        descripcion: descripcion ?? this.descripcion,
        estado: estado ?? this.estado,
        origenCaptura: origenCaptura ?? this.origenCaptura,
        ticketId: ticketId ?? this.ticketId,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        esReembolsable: esReembolsable ?? this.esReembolsable,
        reembolsoId: reembolsoId ?? this.reembolsoId,
        clasificadoPorIA: clasificadoPorIA ?? this.clasificadoPorIA,
        confianzaIA: confianzaIA ?? this.confianzaIA,
        granularidad: granularidad ?? this.granularidad,
        idOrigen: idOrigen ?? this.idOrigen,
      );

  /// Nombres de campo iguales a los del documento `movimientos/{movId}`
  /// (paquete-construccion-final.md §4) — la misma forma sirve hoy para
  /// guardar en disco y mañana para escribir en Firestore.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'clientId': clientId,
        'fecha': fecha.toIso8601String(),
        'cicloId': cicloId,
        'periodoNatural': periodoNatural,
        'montoCentavos': monto.centavos,
        'categoriaId': categoriaId,
        'medio': medio.name,
        'descripcion': descripcion,
        'estado': estado.name,
        'origenCaptura': origenCaptura.name,
        if (ticketId != null) 'ticketId': ticketId,
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        'esReembolsable': esReembolsable,
        if (reembolsoId != null) 'reembolsoId': reembolsoId,
        'clasificadoPorIA': clasificadoPorIA,
        if (confianzaIA != null) 'confianzaIA': confianzaIA,
        if (granularidad != null) 'granularidad': granularidad!.name,
        if (idOrigen != null) 'idOrigen': idOrigen,
      };

  factory Movimiento.fromJson(Map<String, dynamic> json) => Movimiento(
        id: json['id'] as String?,
        clientId: json['clientId'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        cicloId: json['cicloId'] as String,
        periodoNatural: json['periodoNatural'] as String,
        monto: Dinero(json['montoCentavos'] as int),
        categoriaId: json['categoriaId'] as String,
        medio: MedioPago.values.byName(json['medio'] as String),
        descripcion: json['descripcion'] as String,
        estado: EstadoMovimiento.values.byName(json['estado'] as String),
        origenCaptura:
            OrigenCaptura.values.byName(json['origenCaptura'] as String),
        ticketId: json['ticketId'] as String?,
        fotoUrl: json['fotoUrl'] as String?,
        esReembolsable: json['esReembolsable'] as bool? ?? false,
        reembolsoId: json['reembolsoId'] as String?,
        clasificadoPorIA: json['clasificadoPorIA'] as bool? ?? false,
        confianzaIA: (json['confianzaIA'] as num?)?.toDouble(),
        granularidad: json['granularidad'] == null
            ? null
            : Granularidad.values.byName(json['granularidad'] as String),
        idOrigen: json['idOrigen'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Movimiento &&
      other.id == id &&
      other.clientId == clientId &&
      other.fecha == fecha &&
      other.cicloId == cicloId &&
      other.periodoNatural == periodoNatural &&
      other.monto == monto &&
      other.categoriaId == categoriaId &&
      other.medio == medio &&
      other.descripcion == descripcion &&
      other.estado == estado &&
      other.origenCaptura == origenCaptura &&
      other.ticketId == ticketId &&
      other.fotoUrl == fotoUrl &&
      other.esReembolsable == esReembolsable &&
      other.reembolsoId == reembolsoId &&
      other.clasificadoPorIA == clasificadoPorIA &&
      other.confianzaIA == confianzaIA &&
      other.granularidad == granularidad &&
      other.idOrigen == idOrigen;

  @override
  int get hashCode => Object.hashAll([
        id,
        clientId,
        fecha,
        cicloId,
        periodoNatural,
        monto,
        categoriaId,
        medio,
        descripcion,
        estado,
        origenCaptura,
        ticketId,
        fotoUrl,
        esReembolsable,
        reembolsoId,
        clasificadoPorIA,
        confianzaIA,
        granularidad,
        idOrigen,
      ]);

  @override
  String toString() =>
      'Movimiento($clientId, $descripcion, $monto, ciclo=$cicloId, ${estado.name})';
}
