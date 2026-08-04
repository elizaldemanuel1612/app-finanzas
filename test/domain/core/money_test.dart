import 'package:app_finanzas/core/money.dart';
import 'package:test/test.dart';

void main() {
  group('Dinero — construcción', () {
    test('Dinero.pesos convierte a centavos', () {
      expect(const Dinero.pesos(19).centavos, 1900);
    });

    test('Dinero.cero es cero centavos', () {
      expect(const Dinero.cero().centavos, 0);
    });
  });

  group('Dinero — aritmética exacta (el punto de todo esto)', () {
    test('0.1 + 0.2 falla en double pero no en centavos enteros', () {
      // La razón de que este tipo exista: esto es falso en punto flotante.
      // ignore: unrelated_type_equality_checks
      expect(0.1 + 0.2 == 0.3, isFalse);
      expect(const Dinero(10) + const Dinero(20), const Dinero(30));
    });

    test(r'suma de mil montos de $19.99 es exacta', () {
      final montos = List.filled(1000, const Dinero.pesos(19) + const Dinero(99));
      expect(Dinero.suma(montos), const Dinero(1999000));
    });

    test('resta', () {
      expect(const Dinero(500) - const Dinero(200), const Dinero(300));
    });

    test('multiplicación por entero', () {
      expect(const Dinero(150) * 3, const Dinero(450));
    });

    test('negación', () {
      expect(-const Dinero(500), const Dinero(-500));
    });

    test('suma() de una lista vacía es cero', () {
      expect(Dinero.suma(const []), const Dinero.cero());
    });
  });

  group('Dinero — comparaciones', () {
    test('menor y menor o igual', () {
      expect(const Dinero(100) < const Dinero(200), isTrue);
      expect(const Dinero(200) < const Dinero(200), isFalse);
      expect(const Dinero(200) <= const Dinero(200), isTrue);
    });

    test('mayor y mayor o igual', () {
      expect(const Dinero(200) > const Dinero(100), isTrue);
      expect(const Dinero(200) > const Dinero(200), isFalse);
      expect(const Dinero(200) >= const Dinero(200), isTrue);
    });

    test('compareTo ordena una lista', () {
      final valores = [const Dinero(300), const Dinero(100), const Dinero(200)]
        ..sort();
      expect(valores, [const Dinero(100), const Dinero(200), const Dinero(300)]);
    });
  });

  group('Dinero — signo', () {
    test('esPositivo / esNegativo / esCero', () {
      expect(const Dinero(1).esPositivo, isTrue);
      expect(const Dinero(-1).esNegativo, isTrue);
      expect(const Dinero.cero().esCero, isTrue);
      expect(const Dinero(1).esCero, isFalse);
    });

    test('absoluto', () {
      expect(const Dinero(-500).absoluto, const Dinero(500));
      expect(const Dinero(500).absoluto, const Dinero(500));
    });
  });

  group('Dinero.intentarDesdeTexto — captura sin pasar por double', () {
    test('monto con dos decimales', () {
      expect(Dinero.intentarDesdeTexto('19.99'), const Dinero(1999));
    });

    test('monto con separador de miles', () {
      expect(Dinero.intentarDesdeTexto('1,019.84'), const Dinero(101984));
    });

    test('monto entero sin decimales', () {
      expect(Dinero.intentarDesdeTexto('100'), const Dinero(10000));
    });

    test('un solo decimal se interpreta como decenas de centavo', () {
      expect(Dinero.intentarDesdeTexto('0.5'), const Dinero(50));
    });

    test('texto vacío no es un monto', () {
      expect(Dinero.intentarDesdeTexto(''), isNull);
    });

    test('texto no numérico no es un monto', () {
      expect(Dinero.intentarDesdeTexto('abc'), isNull);
    });

    test('tres decimales no es un monto válido', () {
      expect(Dinero.intentarDesdeTexto('19.999'), isNull);
    });

    test('signo negativo no es un monto de captura', () {
      expect(Dinero.intentarDesdeTexto('-5'), isNull);
    });

    test('punto sin decimales no es un monto', () {
      expect(Dinero.intentarDesdeTexto('5.'), isNull);
    });

    test('espacios alrededor se ignoran', () {
      expect(Dinero.intentarDesdeTexto('  480  '), const Dinero(48000));
    });
  });

  group('Dinero — formateado', () {
    test('monto simple', () {
      expect(const Dinero(101984).formateado(), r'$1,019.84');
    });

    test('cero', () {
      expect(const Dinero.cero().formateado(), r'$0.00');
    });

    test('negativo', () {
      expect(const Dinero(-101984).formateado(), r'-$1,019.84');
    });

    test('millones con separadores múltiples', () {
      expect(const Dinero(100000000).formateado(), r'$1,000,000.00');
    });

    test('símbolo personalizado', () {
      expect(const Dinero(500).formateado(simbolo: 'MX\$'), 'MX\$5.00');
    });

    test('toString usa el formato de presentación', () {
      expect(const Dinero(101984).toString(), r'$1,019.84');
    });
  });

  group('Dinero — igualdad', () {
    test('mismos centavos son iguales', () {
      expect(const Dinero(500), const Dinero(500));
      expect(const Dinero(500).hashCode, const Dinero(500).hashCode);
    });

    test('distintos centavos no son iguales', () {
      expect(const Dinero(500) == const Dinero(501), isFalse);
    });
  });
}
