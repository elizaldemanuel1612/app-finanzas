import '../../core/money.dart';

/// Cuánto se apartaría al cierre del ciclo en curso (spec-app-finanzas-v2.md
/// §5.6.1):
///
/// `ingreso − fijas − variablesEstimadas`
///
/// - fijas: lo mayor entre su presupuesto y lo ya pagado (regla #9: no se
///   pronostican, se asumen completas).
/// - variablesEstimadas: lo mayor entre su presupuesto y
///   [proyeccionVariables], el cierre estimado por el MPC
///   (`proyeccionTotal`, `domain/pronostico/pronostico_del_ciclo.dart`): la
///   misma cifra en Inicio y Análisis (`docs/rediseno/plan-rediseno.md`,
///   Etapa 0). No promete lo que todavía no pasa.
///
/// Puede salir negativo: los gastos pasarían lo que entra.
Dinero calcularApartadoEstimado({
  required Dinero ingreso,
  required Dinero presupuestoFijas,
  required Dinero gastadoFijas,
  required Dinero presupuestoVariables,
  required Dinero proyeccionVariables,
}) {
  final fijas = gastadoFijas > presupuestoFijas ? gastadoFijas : presupuestoFijas;
  final variables = proyeccionVariables > presupuestoVariables ? proyeccionVariables : presupuestoVariables;
  return ingreso - fijas - variables;
}
