import '../../core/money.dart';

/// A qué mueve un ingreso extra al cerrarse el ciclo (paquete-construccion-
/// final.md §4, documento `ingresos/{ingId}`). `repartido` queda fuera a
/// propósito: exige `metas/pctApartado`, que todavía no existe.
enum DestinoExtra { apartado, gasto }

/// Un ingreso extra **sí es registro financiero** — mueve todas las
/// métricas del ciclo — así que aplica la regla no negociable #3: no se
/// borra, se anula. Enum propio y no [EstadoMovimiento]: `propuesto` no
/// aplica a un ingreso, nadie más que el usuario los genera.
enum EstadoIngreso { activo, anulado }

/// Un ingreso extra registrado en un ciclo. Espejo del documento
/// `ingresos/{ingId}` (paquete-construccion-final.md §4) — solo guarda
/// extras, el ingreso base sigue viviendo en `Perfil.ingresoBaseMensual`.
final class IngresoExtra {
  final String id;
  final String cicloId;
  final String etiqueta;
  final Dinero monto;
  final DateTime fecha;
  final DestinoExtra destino;
  final EstadoIngreso estado;

  const IngresoExtra({
    required this.id,
    required this.cicloId,
    required this.etiqueta,
    required this.monto,
    required this.fecha,
    required this.destino,
    required this.estado,
  });

  /// Copia con cambios — a propósito **no** acepta [cicloId] como
  /// parámetro, misma razón que [Movimiento.copyWith] (regla no negociable
  /// #5): el ciclo se asigna una vez al crear y jamás se recalcula.
  IngresoExtra copyWith({
    String? etiqueta,
    Dinero? monto,
    DateTime? fecha,
    DestinoExtra? destino,
    EstadoIngreso? estado,
  }) =>
      IngresoExtra(
        id: id,
        cicloId: cicloId,
        etiqueta: etiqueta ?? this.etiqueta,
        monto: monto ?? this.monto,
        fecha: fecha ?? this.fecha,
        destino: destino ?? this.destino,
        estado: estado ?? this.estado,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cicloId': cicloId,
        'etiqueta': etiqueta,
        'montoCentavos': monto.centavos,
        'fecha': fecha.toIso8601String(),
        'destino': destino.name,
        'estado': estado.name,
      };

  factory IngresoExtra.fromJson(Map<String, dynamic> json) => IngresoExtra(
        id: json['id'] as String,
        cicloId: json['cicloId'] as String,
        etiqueta: json['etiqueta'] as String,
        monto: Dinero(json['montoCentavos'] as int),
        fecha: DateTime.parse(json['fecha'] as String),
        destino: DestinoExtra.values.byName(json['destino'] as String),
        estado: EstadoIngreso.values.byName(json['estado'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is IngresoExtra &&
      other.id == id &&
      other.cicloId == cicloId &&
      other.etiqueta == etiqueta &&
      other.monto == monto &&
      other.fecha == fecha &&
      other.destino == destino &&
      other.estado == estado;

  @override
  int get hashCode =>
      Object.hash(id, cicloId, etiqueta, monto, fecha, destino, estado);

  @override
  String toString() =>
      'IngresoExtra($etiqueta, $monto, ciclo=$cicloId, destino=${destino.name}, ${estado.name})';
}
