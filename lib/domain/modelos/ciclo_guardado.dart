import '../../core/ciclo.dart';
import 'snapshot_ciclo.dart';

/// Un [Ciclo] tal como quedó persistido — un ciclo solo llega al disco
/// cuando se cierra o se reabre (ver `ciclo_repositorio.dart`); mientras
/// no exista un [CicloGuardado] para un id, ese ciclo se sigue derivando
/// al vuelo con `CalculadoraCiclo` y se trata como abierto.
final class CicloGuardado {
  final Ciclo ciclo;

  /// Se conserva al reabrir (regla no negociable #6: reabrir deja rastro,
  /// no borra lo anterior) y se recalcula y sobrescribe al volver a cerrar
  /// (ver `cierre_ciclo.dart`).
  final SnapshotCiclo? snapshot;

  const CicloGuardado({required this.ciclo, this.snapshot});

  /// Nombres de campo iguales a los del documento `ciclos/{cicloId}`
  /// (paquete-construccion-final.md §4).
  Map<String, dynamic> toJson() => {
        'id': ciclo.id,
        'fechaInicio': ciclo.fechaInicio.toIso8601String(),
        'fechaFin': ciclo.fechaFin.toIso8601String(),
        'etiqueta': ciclo.etiqueta,
        'estado': ciclo.estado.name,
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
      };

  factory CicloGuardado.fromJson(Map<String, dynamic> json) => CicloGuardado(
        ciclo: Ciclo(
          id: json['id'] as String,
          fechaInicio: DateTime.parse(json['fechaInicio'] as String),
          fechaFin: DateTime.parse(json['fechaFin'] as String),
          etiqueta: json['etiqueta'] as String,
          estado: EstadoCiclo.values.byName(json['estado'] as String),
        ),
        snapshot: json['snapshot'] == null
            ? null
            : SnapshotCiclo.fromJson(json['snapshot'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      other is CicloGuardado && other.ciclo == ciclo && other.snapshot == snapshot;

  @override
  int get hashCode => Object.hash(ciclo, snapshot);
}
