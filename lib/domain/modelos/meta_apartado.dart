import '../../core/money.dart';

/// Cuánto quiere apartar el usuario, declarado explícitamente
/// (paquete-construccion-final.md §4, `metas/ pctApartado, montoMetaCentavos`
/// — hoy vive dentro de `perfil`, no como colección aparte).
///
/// Jerarquía sellada con el mismo criterio que [Categoria]: el compilador
/// impide construir una meta "de porcentaje" sin porcentaje. `null` en
/// [Perfil.metaApartado] es un tercer estado fuera de esta jerarquía — la
/// meta derivada de `ResultadoReparto.sinAsignar` (ver
/// `domain/presupuesto/meta_base.dart`), no una meta declarada en cero.
sealed class MetaApartado {
  const MetaApartado();

  /// Monto que corresponde a esta meta para un ingreso base dado.
  Dinero montoPara(Dinero ingresoBase);

  /// Nombres de campo iguales a los de `metas/` (paquete-construccion-
  /// final.md §4) y discriminador `tipo`, igual que [Categoria.toJson].
  Map<String, dynamic> toJson();

  static MetaApartado fromJson(Map<String, dynamic> json) =>
      switch (json['tipo'] as String) {
        'monto' => MetaPorMonto(Dinero(json['montoMetaCentavos'] as int)),
        'porcentaje' => MetaPorPorcentaje(json['pctApartado'] as int),
        final otro => throw FormatException('Tipo de meta desconocido: $otro'),
      };
}

/// "Monto fijo": aparta siempre lo mismo, sin importar cómo varíe el
/// ingreso del ciclo.
final class MetaPorMonto extends MetaApartado {
  final Dinero monto;

  const MetaPorMonto(this.monto);

  @override
  Dinero montoPara(Dinero ingresoBase) => monto;

  @override
  Map<String, dynamic> toJson() => {
        'tipo': 'monto',
        'montoMetaCentavos': monto.centavos,
      };

  @override
  bool operator ==(Object other) => other is MetaPorMonto && other.monto == monto;
  @override
  int get hashCode => Object.hash(MetaPorMonto, monto);

  @override
  String toString() => 'MetaPorMonto($monto)';
}

/// "% de lo que entra": el monto sube y baja con el ingreso del ciclo —
/// pensado para quien tiene ingresos variables (addendum-v3-ajuste-y-ux.md
/// §4, `app-finanzas-onboarding-v5.html` §4).
final class MetaPorPorcentaje extends MetaApartado {
  /// Porcentaje entero (0–100), nunca `double` — mismo criterio que
  /// [Dinero]: sin punto flotante en nada que determine dinero.
  final int porcentaje;

  const MetaPorPorcentaje(this.porcentaje)
      : assert(porcentaje >= 0 && porcentaje <= 100);

  /// Redondeo entero medio arriba: `(centavos * pct + 50) ~/ 100`, sin
  /// pasar por `double` en ningún punto.
  @override
  Dinero montoPara(Dinero ingresoBase) =>
      Dinero((ingresoBase.centavos * porcentaje + 50) ~/ 100);

  @override
  Map<String, dynamic> toJson() => {
        'tipo': 'porcentaje',
        'pctApartado': porcentaje,
      };

  @override
  bool operator ==(Object other) =>
      other is MetaPorPorcentaje && other.porcentaje == porcentaje;
  @override
  int get hashCode => Object.hash(MetaPorPorcentaje, porcentaje);

  @override
  String toString() => 'MetaPorPorcentaje($porcentaje%)';
}
