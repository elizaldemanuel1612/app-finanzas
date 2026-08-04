import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';
import '../reglas/presupuesto.dart';

/// Efecto del reparto de un ingreso disponible entre categorías fijas y
/// variables (paquete-construccion-final.md §6, reglas #10 y #11).
final class ResultadoReparto {
  final Dinero ingresoDisponible;
  final Dinero totalFijas;
  final Dinero disponibleParaVariables;
  final Dinero totalPresupuestadoVariables;

  const ResultadoReparto({
    required this.ingresoDisponible,
    required this.totalFijas,
    required this.disponibleParaVariables,
    required this.totalPresupuestadoVariables,
  });

  /// Lo que queda libre después de cubrir fijas y el presupuesto variable
  /// declarado — lo que en la interfaz se llama "lo que vas a poder
  /// invertir" (addendum-v3 §4.1) antes de que el gasto real del ciclo lo
  /// mueva.
  Dinero get sinAsignar => disponibleParaVariables - totalPresupuestadoVariables;

  @override
  String toString() =>
      'ResultadoReparto(fijas=$totalFijas, disponibleVariables='
      '$disponibleParaVariables, presupuestadoVariables='
      '$totalPresupuestadoVariables, sinAsignar=$sinAsignar)';
}

/// Calcula el reparto completo: primero se respetan las fijas tal cual
/// (regla #10), y el presupuesto variable declarado nunca puede exceder lo
/// que queda (regla #11). Si cualquiera de las dos falla, el reparto entero
/// se bloquea — no tiene sentido mostrar un presupuesto variable que ya
/// sabemos que no cabe.
Resultado<ResultadoReparto> calcularReparto({
  required Dinero ingresoDisponible,
  required List<CategoriaFija> fijas,
  required List<CategoriaVariable> variables,
}) {
  final disponible = disponibleParaVariables(
    ingresoDisponible: ingresoDisponible,
    fijas: fijas,
  );
  if (disponible case Falla(:final mensaje)) return Falla(mensaje);
  final sobrante = (disponible as Exito<Dinero>).valor;

  final valido = validarPresupuestoNoExcedeDisponible(
    disponible: sobrante,
    variables: variables,
  );
  if (valido case Falla(:final mensaje)) return Falla(mensaje);

  return Exito(ResultadoReparto(
    ingresoDisponible: ingresoDisponible,
    totalFijas: Dinero.suma(fijas.map((f) => f.montoFijoCentavos)),
    disponibleParaVariables: sobrante,
    totalPresupuestadoVariables:
        Dinero.suma(variables.map((v) => v.presupuestoMensualCentavos)),
  ));
}
