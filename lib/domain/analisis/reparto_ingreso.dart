import '../../core/money.dart';
import 'reporte_analisis.dart';

/// Cuánto de lo que entra se llevan las fijas y las variables, y cuánto
/// sobra (spec-app-finanzas-v2.md §5.7, vista "Total" de "¿Cuánto pesa cada
/// parte?").
final class RepartoIngreso {
  final Dinero ingreso;
  final Dinero fijas;
  final Dinero variables;

  const RepartoIngreso({required this.ingreso, required this.fijas, required this.variables});

  Dinero get gastos => fijas + variables;

  /// Negativa si los gastos pasan lo que entra.
  Dinero get sobra => ingreso - gastos;

  /// Porcentaje entero de [parte] sobre lo que entra (0 si no entra nada).
  int porcentaje(Dinero parte) {
    if (!ingreso.esPositivo) return 0;
    return (parte.centavos * 100 + ingreso.centavos ~/ 2) ~/ ingreso.centavos;
  }
}

/// Hasta hoy y al cierre si sigue igual: las fijas completas (o lo pagado,
/// si fue más) y las variables a su proyección lineal (regla #9: las fijas
/// no se pronostican, se suman por su monto).
({RepartoIngreso hoy, RepartoIngreso alCierre}) calcularRepartoIngreso({
  required ReporteAnalisis reporte,
  required Dinero ingreso,
}) {
  final r = reporte;
  Dinero mayor(Dinero a, Dinero b) => a > b ? a : b;
  return (
    hoy: RepartoIngreso(ingreso: ingreso, fijas: r.gastadoFijas, variables: r.gastadoVariables),
    alCierre: RepartoIngreso(
      ingreso: ingreso,
      fijas: mayor(r.presupuestoFijas, r.gastadoFijas),
      variables: mayor(r.proyeccionVariables, r.gastadoVariables),
    ),
  );
}
