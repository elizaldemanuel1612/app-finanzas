import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/voz/monto_hablado.dart';
import 'package:test/test.dart';

void main() {
  test('cero', () {
    expect(montoEnPalabras(const Dinero.cero()), 'cero pesos');
  });

  test('un peso exacto usa "un peso" (singular, no "uno pesos")', () {
    expect(montoEnPalabras(const Dinero.pesos(1)), 'un peso');
  });

  test('unidades 2-9', () {
    expect(montoEnPalabras(const Dinero.pesos(5)), 'cinco pesos');
    expect(montoEnPalabras(const Dinero.pesos(9)), 'nueve pesos');
  });

  test('10-19', () {
    expect(montoEnPalabras(const Dinero.pesos(10)), 'diez pesos');
    expect(montoEnPalabras(const Dinero.pesos(15)), 'quince pesos');
    expect(montoEnPalabras(const Dinero.pesos(19)), 'diecinueve pesos');
  });

  test('20 exacto y 21-29', () {
    expect(montoEnPalabras(const Dinero.pesos(20)), 'veinte pesos');
    expect(montoEnPalabras(const Dinero.pesos(24)), 'veinticuatro pesos');
    expect(montoEnPalabras(const Dinero.pesos(29)), 'veintinueve pesos');
  });

  test('30+ exacto y con unidad ("y")', () {
    expect(montoEnPalabras(const Dinero.pesos(30)), 'treinta pesos');
    expect(montoEnPalabras(const Dinero.pesos(45)), 'cuarenta y cinco pesos');
    expect(montoEnPalabras(const Dinero.pesos(99)), 'noventa y nueve pesos');
  });

  test('cien exacto', () {
    expect(montoEnPalabras(const Dinero.pesos(100)), 'cien pesos');
  });

  test('centena exacta (múltiplo de 100, no 100 mismo)', () {
    expect(montoEnPalabras(const Dinero.pesos(500)), 'quinientos pesos');
  });

  test('centena con resto', () {
    expect(montoEnPalabras(const Dinero.pesos(480)), 'cuatrocientos ochenta pesos');
    expect(montoEnPalabras(const Dinero.pesos(101)), 'ciento uno pesos');
  });

  test('mil exacto', () {
    expect(montoEnPalabras(const Dinero.pesos(1000)), 'mil pesos');
  });

  test('miles exactos (múltiplo, sin resto)', () {
    expect(montoEnPalabras(const Dinero.pesos(3000)), 'tres mil pesos');
  });

  test('miles con resto', () {
    expect(montoEnPalabras(const Dinero.pesos(1234)), 'mil doscientos treinta y cuatro pesos');
  });

  test('un millón exacto', () {
    expect(montoEnPalabras(const Dinero.pesos(1000000)), 'un millón pesos');
  });

  test('un millón con resto', () {
    expect(montoEnPalabras(const Dinero.pesos(1000500)), 'un millón quinientos pesos');
  });

  test('varios millones', () {
    expect(montoEnPalabras(const Dinero.pesos(2000000)), 'dos millones pesos');
  });

  test('monto con centavos', () {
    expect(montoEnPalabras(const Dinero(123456)), 'mil doscientos treinta y cuatro pesos con cincuenta y seis centavos');
  });

  test('centavo singular', () {
    expect(montoEnPalabras(const Dinero(101)), 'un peso con un centavo');
  });

  test('centavos en cero se omiten', () {
    expect(montoEnPalabras(const Dinero.pesos(100)), isNot(contains('con')));
  });

  test('cero pesos con centavos', () {
    expect(montoEnPalabras(const Dinero(99)), 'cero pesos con noventa y nueve centavos');
  });

  test('negativo antepone "menos"', () {
    expect(montoEnPalabras(const Dinero(-99)), 'menos cero pesos con noventa y nueve centavos');
    expect(montoEnPalabras(const Dinero.pesos(-50)), 'menos cincuenta pesos');
  });

  test('mil millones o más: se trunca la lectura en vez de fallar', () {
    expect(
      montoEnPalabras(const Dinero.pesos(1000000000)),
      'uno mil millones y más pesos',
    );
  });
}
