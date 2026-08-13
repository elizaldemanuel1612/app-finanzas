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

/// Reparte [total] entre [pesos] proporcionalmente, en enteros — sin punto
/// flotante en ningún punto (mismo criterio que `L.repartir` del prototipo
/// interactivo, `app-finanzas-onboarding-INTERACTIVO.html`). Cada parte se
/// redondea hacia abajo y el residuo de esos redondeos se le suma completo
/// a la primera, para que la suma cuadre exacto contra [total] en vez de
/// quedar unos centavos cortos.
///
/// Usado por el paso "¿En qué se te va?" del onboarding (Bloque C) para
/// repartir el disponible entre las categorías sugeridas según su peso.
List<Dinero> repartirPorPesos(Dinero total, List<int> pesos) {
  if (pesos.isEmpty) return const [];
  final sumaPesos = pesos.fold(0, (a, b) => a + b);
  if (sumaPesos == 0) return List.filled(pesos.length, const Dinero.cero());

  final partes = [for (final peso in pesos) Dinero(total.centavos * peso ~/ sumaPesos)];
  final residuo = total - Dinero.suma(partes);
  return [partes.first + residuo, ...partes.skip(1)];
}
