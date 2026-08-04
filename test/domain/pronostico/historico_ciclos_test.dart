import 'package:app_finanzas/domain/pronostico/historico_ciclos.dart';
import 'package:test/test.dart';

void main() {
  test('lista vacía da 0', () => expect(historicoSuavizado([]), 0));

  test('un solo ciclo regresa ese mismo total', () {
    expect(historicoSuavizado([5000]), 5000);
  });

  test('2-4 ciclos usa la mediana', () {
    expect(historicoSuavizado([100, 300, 200]), 200);
    expect(historicoSuavizado([100, 500]), 300); // promedio de 2 = mediana
  });

  test('la mediana resiste un ciclo raro dentro de 2-4', () {
    final normal = historicoSuavizado([1000, 1050, 950]);
    final conRaro = historicoSuavizado([1000, 1050, 5000]);
    // Un ciclo raro no debe mover la mediana tanto como movería un promedio.
    expect(conRaro, 1050);
    expect(normal, 1000);
  });

  test('5+ ciclos usa EWMA con alpha=0.4, el más reciente pesa más', () {
    // Todos iguales -> EWMA debe dar ese mismo valor sin importar el peso.
    final resultado = historicoSuavizado([1000, 1000, 1000, 1000, 1000]);
    expect(resultado, closeTo(1000, 0.01));
  });

  test('EWMA responde más al ciclo reciente que a uno antiguo (orden importa)', () {
    // Reciente alto, antiguos bajos.
    final recienteAlto = historicoSuavizado([2000, 500, 500, 500, 500]);
    // Antiguo alto, resto bajo.
    final antiguoAlto = historicoSuavizado([500, 500, 500, 500, 2000]);
    expect(recienteAlto, greaterThan(antiguoAlto));
  });

  test('cambio estructural: 2 ciclos recientes muy por encima de la base se aceptan como nuevo nivel', () {
    // Base histórica estable en ~1000 (5 ciclos), luego 2 ciclos recientes
    // saltan a ~3000 (ej. subida de renta) -> el histórico debe reflejar
    // el nuevo nivel, no seguir anclado a 1000.
    final totales = <double>[3100.0, 3000, 1000, 1000, 1000, 1000, 1000];
    final resultado = historicoSuavizado(totales);
    expect(resultado, greaterThan(2000));
  });

  test('sin cambio estructural claro, no reinicia el histórico', () {
    final totales = <double>[1050.0, 980, 1000, 1000, 1000, 1000, 1000];
    final resultado = historicoSuavizado(totales);
    expect(resultado, closeTo(1000, 60));
  });

  test('dos ciclos recientes que difieren en direcciones opuestas no cuentan como cambio estructural', () {
    // Uno muy alto, otro muy bajo -> no es "la misma dirección".
    final totales = <double>[3000.0, -1000, 1000, 1000, 1000, 1000, 1000];
    final resultado = historicoSuavizado(totales);
    // Debe seguir anclado cerca de la base vieja (EWMA con los 7 datos),
    // no reiniciarse a solo los últimos 2.
    expect(resultado, isNot(closeTo(1000, 5))); // el EWMA sí se mueve algo
    expect(resultado, lessThan(2000)); // pero no se dispara al nivel "3000"
  });
}
