import '../../core/money.dart';

/// Para qué se está ahorrando (spec-app-finanzas-v2.md §7.3.3): "Fondo de
/// emergencia", "Viaje en junio". Su avance es el saldo de la cuenta de
/// ahorro a la que está ligado; no guarda cuánto lleva. Espejo del
/// documento `objetivos/{objetivoId}`. Se archiva, no se borra.
final class Objetivo {
  final String id;
  final String nombre;
  final String emoji;

  /// Cuánto se quiere juntar.
  final Dinero monto;

  /// Para cuándo; `null` si no tiene fecha.
  final DateTime? fechaLimite;

  /// La cuenta de ahorro donde se junta.
  final String cuentaId;
  final DateTime creado;
  final bool activo;

  const Objetivo({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.monto,
    required this.cuentaId,
    required this.creado,
    this.fechaLimite,
    this.activo = true,
  });

  Objetivo copyWith({
    String? nombre,
    String? emoji,
    Dinero? monto,
    DateTime? Function()? fechaLimite,
    String? cuentaId,
    bool? activo,
  }) =>
      Objetivo(
        id: id,
        nombre: nombre ?? this.nombre,
        emoji: emoji ?? this.emoji,
        monto: monto ?? this.monto,
        fechaLimite: fechaLimite != null ? fechaLimite() : this.fechaLimite,
        cuentaId: cuentaId ?? this.cuentaId,
        creado: creado,
        activo: activo ?? this.activo,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'montoCentavos': monto.centavos,
        if (fechaLimite != null) 'fechaLimite': fechaLimite!.toIso8601String(),
        'cuentaId': cuentaId,
        'creado': creado.toIso8601String(),
        'activo': activo,
      };

  factory Objetivo.fromJson(Map<String, dynamic> json) => Objetivo(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        emoji: json['emoji'] as String,
        monto: Dinero(json['montoCentavos'] as int),
        fechaLimite: json['fechaLimite'] == null ? null : DateTime.parse(json['fechaLimite'] as String),
        cuentaId: json['cuentaId'] as String,
        creado: DateTime.parse(json['creado'] as String),
        activo: json['activo'] as bool? ?? true,
      );
}
