import '../../core/money.dart';

/// Configuración de la cuenta que el resto del dominio necesita para
/// calcular ciclos y repartos (paquete-construccion-final.md §4, documento
/// `perfil` bajo `cuentas/{cuentaId}`).
final class Perfil {
  /// Día del corte de tarjeta (1–31). Insumo de [CalculadoraCiclo].
  final int diaCorte;

  final Dinero ingresoBaseMensual;
  final String moneda;
  final String zonaHoraria;

  const Perfil({
    required this.diaCorte,
    required this.ingresoBaseMensual,
    this.moneda = 'MXN',
    this.zonaHoraria = 'America/Mexico_City',
  });

  Perfil copyWith({
    int? diaCorte,
    Dinero? ingresoBaseMensual,
    String? moneda,
    String? zonaHoraria,
  }) =>
      Perfil(
        diaCorte: diaCorte ?? this.diaCorte,
        ingresoBaseMensual: ingresoBaseMensual ?? this.ingresoBaseMensual,
        moneda: moneda ?? this.moneda,
        zonaHoraria: zonaHoraria ?? this.zonaHoraria,
      );

  Map<String, dynamic> toJson() => {
        'diaCorte': diaCorte,
        'ingresoBaseMensualCentavos': ingresoBaseMensual.centavos,
        'moneda': moneda,
        'zonaHoraria': zonaHoraria,
      };

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
        diaCorte: json['diaCorte'] as int,
        ingresoBaseMensual: Dinero(json['ingresoBaseMensualCentavos'] as int),
        moneda: json['moneda'] as String? ?? 'MXN',
        zonaHoraria: json['zonaHoraria'] as String? ?? 'America/Mexico_City',
      );

  @override
  bool operator ==(Object other) =>
      other is Perfil &&
      other.diaCorte == diaCorte &&
      other.ingresoBaseMensual == ingresoBaseMensual &&
      other.moneda == moneda &&
      other.zonaHoraria == zonaHoraria;

  @override
  int get hashCode =>
      Object.hash(diaCorte, ingresoBaseMensual, moneda, zonaHoraria);
}
