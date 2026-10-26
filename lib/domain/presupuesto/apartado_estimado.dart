import '../../core/money.dart';

/// Cuánto se apartaría al cierre del ciclo en curso si sigue el ritmo
/// actual (spec-app-finanzas-v2.md §5.6.1):
///
/// `ingreso − fijas − variablesEstimadas`
///
/// - fijas: lo mayor entre su presupuesto y lo ya pagado (regla #9: no se
///   pronostican, se asumen completas).
/// - variablesEstimadas: lo mayor entre su presupuesto y la proyección
///   lineal de lo gastado. No promete lo que todavía no pasa.
///
/// Puede salir negativo: los gastos pasarían lo que entra.
Dinero calcularApartadoEstimado({
  required Dinero ingreso,
  required Dinero presupuestoFijas,
  required Dinero gastadoFijas,
  required Dinero presupuestoVariables,
  required Dinero gastadoVariables,
  required int diaDelCiclo,
  required int diasDelCiclo,
}) {
  final fijas = gastadoFijas > presupuestoFijas ? gastadoFijas : presupuestoFijas;
  final dia = diaDelCiclo < 1 ? 1 : diaDelCiclo;
  final restantes = diasDelCiclo - dia < 0 ? 0 : diasDelCiclo - dia;
  final proyeccion = Dinero(gastadoVariables.centavos + gastadoVariables.centavos * restantes ~/ dia);
  final variables = proyeccion > presupuestoVariables ? proyeccion : presupuestoVariables;
  return ingreso - fijas - variables;
}
