import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';

/// Regla no negociable #10: las categorías fijas se respetan tal cual al
/// repartir presupuesto; solo el sobrante se distribuye entre las
/// variables. Si las fijas exceden lo disponible, se bloquea y se informa
/// cuánto falta — nunca se generan montos negativos.
Resultado<Dinero> disponibleParaVariables({
  required Dinero ingresoDisponible,
  required List<CategoriaFija> fijas,
}) {
  final totalFijas = Dinero.suma(fijas.map((f) => f.montoFijoCentavos));
  if (totalFijas > ingresoDisponible) {
    final faltante = totalFijas - ingresoDisponible;
    return Falla(
      'Tus gastos fijos (${totalFijas.formateado()}) exceden el ingreso '
      'disponible (${ingresoDisponible.formateado()}) por '
      '${faltante.formateado()}.',
    );
  }
  return Exito(ingresoDisponible - totalFijas);
}

/// Regla no negociable #11: el total presupuestado en categorías variables
/// nunca puede exceder lo disponible sin que la app lo señale.
Resultado<void> validarPresupuestoNoExcedeDisponible({
  required Dinero disponible,
  required List<CategoriaVariable> variables,
}) {
  final totalVariables =
      Dinero.suma(variables.map((v) => v.presupuestoMensualCentavos));
  if (totalVariables > disponible) {
    final exceso = totalVariables - disponible;
    return Falla(
      'El presupuesto variable (${totalVariables.formateado()}) excede lo '
      'disponible (${disponible.formateado()}) por ${exceso.formateado()}.',
    );
  }
  return const Exito(null);
}
