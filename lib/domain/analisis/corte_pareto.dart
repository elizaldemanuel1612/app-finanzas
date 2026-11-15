import '../../core/money.dart';

/// Dónde va la línea del 80/20 en "¿Cuánto pesa cada parte?" (spec §5.7):
/// las primeras categorías —de mayor a menor— que juntas llegan al
/// [porcentaje] de lo asignado.
final class CortePareto {
  /// Cuántas categorías quedan arriba de la línea.
  final int cuantas;

  /// Qué porcentaje de lo asignado suman (entero, redondeado).
  final int porcentaje;

  const CortePareto({required this.cuantas, required this.porcentaje});
}

/// [montos] ya ordenados de mayor a menor. `null` si no hay línea que
/// dibujar: sin total, o si hacen falta todas para llegar.
CortePareto? calcularCortePareto(List<Dinero> montos, {int porcentaje = 80}) {
  final total = Dinero.suma(montos).centavos;
  if (total <= 0) return null;
  // Con total positivo hay al menos un monto, y la suma completa es el 100 %:
  // el ciclo siempre termina dentro de la lista.
  var i = 0;
  var acumulado = montos[0].centavos;
  while (acumulado * 100 < total * porcentaje) {
    i++;
    acumulado += montos[i].centavos;
  }
  if (i + 1 == montos.length) return null;
  return CortePareto(cuantas: i + 1, porcentaje: (acumulado * 100 + total ~/ 2) ~/ total);
}
