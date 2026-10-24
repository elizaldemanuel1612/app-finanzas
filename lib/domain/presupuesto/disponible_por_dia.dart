import '../../core/ciclo.dart';
import '../../core/money.dart';

/// Cuánto queda para gastar hoy (spec-app-finanzas-v2.md §5.6): lo que
/// resta del presupuesto de las categorías **variables** del ciclo,
/// repartido parejo entre los días que faltan contando hoy.
///
/// Las fijas no entran — ya tienen su monto apartado y no se gastan "por
/// día". Si ya se pasó del presupuesto, queda cero (nunca negativo). El
/// reparto se redondea hacia abajo al centavo para no prometer más de lo
/// que hay.
///
/// Es el dato que muestra el widget de inicio; la app lo calcula aquí y lo
/// publica, el widget nunca calcula nada por su cuenta.
Dinero calcularDisponiblePorDia({
  required Dinero presupuestoVariables,
  required Dinero gastadoVariables,
  required Ciclo ciclo,
  required DateTime hoy,
}) {
  final restante = presupuestoVariables - gastadoVariables;
  if (!restante.esPositivo) return const Dinero.cero();
  final dias = ciclo.diasParaTerminar(hoy) + 1;
  return Dinero(restante.centavos ~/ dias);
}
