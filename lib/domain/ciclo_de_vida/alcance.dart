import '../../core/money.dart';

/// Alcance y tasa de ahorro de un ciclo, calculados **juntos** en un solo
/// valor — así ningún llamador puede obtener el uno sin el otro, lo que
/// hace cumplir la regla no negociable #14 con el tipo en vez de dejarlo a
/// la disciplina de quien escriba la UI (app-finanzas-fijos-cierre-v6.html
/// §5).
final class MetricasApartado {
  final Dinero apartado;

  /// `apartado / meta`. `null` si la meta es cero — no hay contra qué medir.
  final double? alcance;

  /// Qué tan lejos habría llegado sin el ingreso extra: numerador y
  /// denominador **ambos sin extra** (`(ingresoTotal - extraTotal -
  /// totalGastado) / metaBase`, nunca contra `meta` — mezclar un numerador
  /// sin extra con un denominador que sí lo incluye da una cifra que
  /// miente). `null` si no hubo extra este ciclo o si `metaBase` no es
  /// positiva.
  final double? alcanceSinExtra;

  /// `apartado / ingresoTotal`. `null` si no entró nada este ciclo.
  final double? tasaDeAhorro;

  const MetricasApartado({
    required this.apartado,
    required this.alcance,
    required this.alcanceSinExtra,
    required this.tasaDeAhorro,
  });
}

/// `double` es correcto aquí: [alcance] y [tasaDeAhorro] son razones, no
/// dinero — se redondean a entero solo al pintarlas, igual que hace el MPC
/// en su frontera de salida (domain/pronostico/).
///
/// Verificado contra app-finanzas-fijos-cierre-v6.html §5: ingreso 87,000 ·
/// gastado 42,674 · meta 34,800 → apartado 44,326, alcance 127%, tasa 51%.
///
/// [extraAApartado] y [extraAGasto] llegan como [Dinero] sueltos —
/// deliberadamente **no** un `IngresosDelCiclo` — porque los cinco valores
/// de esta función salen del snapshot congelado de un ciclo, no del
/// repositorio vivo de ingresos: eso hace estructuralmente difícil
/// recalcular un ciclo cerrado con datos que cambiaron después (regla no
/// negociable #6, ver también el docstring de `PantallaCierreCiclo`).
MetricasApartado calcularMetricasApartado({
  required Dinero ingresoTotal,
  required Dinero totalGastado,
  required Dinero meta,
  required Dinero extraAApartado,
  required Dinero extraAGasto,
}) {
  final apartado = ingresoTotal - totalGastado;
  final extraTotal = extraAApartado + extraAGasto;
  final metaBase = meta - extraAApartado;

  final double? alcanceSinExtra;
  if (extraTotal.esCero || !metaBase.esPositivo) {
    alcanceSinExtra = null;
  } else {
    final apartadoSinExtra = ingresoTotal - extraTotal - totalGastado;
    alcanceSinExtra = apartadoSinExtra.centavos / metaBase.centavos;
  }

  return MetricasApartado(
    apartado: apartado,
    alcance: meta.esCero ? null : apartado.centavos / meta.centavos,
    alcanceSinExtra: alcanceSinExtra,
    tasaDeAhorro: ingresoTotal.esCero ? null : apartado.centavos / ingresoTotal.centavos,
  );
}

/// Nivel de alcance para elegir color y titular en la interfaz — extraído
/// para que `_AnilloAlcance` (pantalla_cierre_ciclo.dart) y la gráfica de
/// trazabilidad (grafica_evolucion.dart) compartan el mismo umbral y no
/// puedan divergir.
enum NivelAlcance { logrado, cerca, corto }

/// `null` si [alcance] es `null` (meta en cero: no hay contra qué medir).
NivelAlcance? calcularNivelAlcance(double? alcance) {
  if (alcance == null) return null;
  if (alcance >= 1.0) return NivelAlcance.logrado;
  if (alcance >= 0.7) return NivelAlcance.cerca;
  return NivelAlcance.corto;
}
