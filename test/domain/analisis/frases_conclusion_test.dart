import 'package:app_finanzas/domain/analisis/frases_conclusion.dart';
import 'package:test/test.dart';

void main() {
  test('fracciones conocidas en palabras; si no, porcentaje', () {
    expect(fraccionEnPalabras(0.496), 'la mitad');
    expect(fraccionEnPalabras(0.34), 'un tercio');
    expect(fraccionEnPalabras(0.67), 'dos tercios');
    expect(fraccionEnPalabras(0.42), 'el 42 %');
  });

  test('de cada peso', () {
    expect(deCadaPeso(0.67), '2 de cada 3 pesos');
    expect(deCadaPeso(0.8), '4 de cada 5 pesos');
    expect(deCadaPeso(0.58), 'el 58 % de cada peso');
  });

  test('veces más', () {
    expect(vecesMas(920, 182), '5 veces más');
    expect(vecesMas(400, 200), 'el doble');
    expect(vecesMas(300, 200), 'un poco más');
    expect(vecesMas(300, 0), isNull);
  });
}
