import '../../core/money.dart';
import 'meta_apartado.dart';

/// Configuración de la cuenta que el resto del dominio necesita para
/// calcular ciclos y repartos (paquete-construccion-final.md §4, documento
/// `perfil` bajo `cuentas/{cuentaId}`).
final class Perfil {
  /// Día del corte de tarjeta (1–31). Insumo de [CalculadoraCiclo].
  final int diaCorte;

  final Dinero ingresoBaseMensual;
  final String moneda;
  final String zonaHoraria;

  /// `null` = meta derivada (comportamiento de hoy: lo que sobra tras
  /// fijas y presupuesto variable, ver `domain/presupuesto/meta_base.dart`).
  /// Perfiles ya guardados sin este campo siguen leyéndose sin migración.
  final MetaApartado? metaApartado;

  const Perfil({
    required this.diaCorte,
    required this.ingresoBaseMensual,
    this.moneda = 'MXN',
    this.zonaHoraria = 'America/Mexico_City',
    this.metaApartado,
  });

  /// [quitarMeta] regresa al modo derivado (`metaApartado = null`) sin
  /// tener que pasar un centinela por [metaApartado] — que de por sí no
  /// puede distinguir "no cambiar" de "poner en null".
  Perfil copyWith({
    int? diaCorte,
    Dinero? ingresoBaseMensual,
    String? moneda,
    String? zonaHoraria,
    MetaApartado? metaApartado,
    bool quitarMeta = false,
  }) =>
      Perfil(
        diaCorte: diaCorte ?? this.diaCorte,
        ingresoBaseMensual: ingresoBaseMensual ?? this.ingresoBaseMensual,
        moneda: moneda ?? this.moneda,
        zonaHoraria: zonaHoraria ?? this.zonaHoraria,
        metaApartado: quitarMeta ? null : (metaApartado ?? this.metaApartado),
      );

  Map<String, dynamic> toJson() => {
        'diaCorte': diaCorte,
        'ingresoBaseMensualCentavos': ingresoBaseMensual.centavos,
        'moneda': moneda,
        'zonaHoraria': zonaHoraria,
        if (metaApartado != null) 'metaApartado': metaApartado!.toJson(),
      };

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
        diaCorte: json['diaCorte'] as int,
        ingresoBaseMensual: Dinero(json['ingresoBaseMensualCentavos'] as int),
        moneda: json['moneda'] as String? ?? 'MXN',
        zonaHoraria: json['zonaHoraria'] as String? ?? 'America/Mexico_City',
        metaApartado: json['metaApartado'] == null
            ? null
            : MetaApartado.fromJson(json['metaApartado'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      other is Perfil &&
      other.diaCorte == diaCorte &&
      other.ingresoBaseMensual == ingresoBaseMensual &&
      other.moneda == moneda &&
      other.zonaHoraria == zonaHoraria &&
      other.metaApartado == metaApartado;

  @override
  int get hashCode => Object.hash(
        diaCorte,
        ingresoBaseMensual,
        moneda,
        zonaHoraria,
        metaApartado,
      );
}
