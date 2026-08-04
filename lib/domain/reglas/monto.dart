import '../../core/money.dart';
import '../../core/result.dart';

/// Regla no negociable #1 (paquete-construccion-final.md §6) y spec-app-
/// finanzas-v2.md §7.2: los montos financieros son enteros positivos. El
/// tipo [Dinero] ya garantiza "entero" en tiempo de compilación (nunca hay
/// un `double` que colar); esta función cubre la mitad que el tipo no
/// puede: que no sea cero ni negativo.
Resultado<void> validarMontoPositivo(Dinero monto, {String etiqueta = 'monto'}) {
  if (!monto.esPositivo) {
    return Falla('El $etiqueta debe ser mayor a cero (recibido: $monto).');
  }
  return const Exito(null);
}
