import 'package:app_finanzas/domain/pronostico/estadistica_robusta.dart';
import 'package:test/test.dart';

void main() {
  group('mediana', () {
    test('lista impar', () => expect(mediana([1, 3, 2]), 2));
    test('lista par promedia los dos de en medio', () => expect(mediana([1, 2, 3, 4]), 2.5));
    test('lista vacía da 0', () => expect(mediana([]), 0));
    test('un solo valor', () => expect(mediana([7]), 7));
  });

  group('mad', () {
    test('caso simple: montos [10, 12, 14, 100] -> mediana 13, MAD 2', () {
      // |10-13|=3, |12-13|=1, |14-13|=1, |100-13|=87 -> mediana de eso = 2
      expect(mad([10, 12, 14, 100]), 2);
    });

    test('salvaguarda: montos casi idénticos no dan MAD cero', () {
      final valores = List.filled(10, 239.0); // Spotify, mismo monto siempre
      expect(mad(valores), closeTo(0.05 * 239, 0.001));
    });

    test('lista vacía no explota', () => expect(mad([]), 0));
  });

  group('zModificado', () {
    test('valor igual a la mediana da z = 0', () {
      expect(zModificado(50, mediana: 50, mad: 5), 0);
    });

    test('valor muy por encima da z alto', () {
      final z = zModificado(100, mediana: 50, mad: 5);
      expect(z, closeTo(0.6745 * 50 / 5, 0.001));
    });

    test('MAD cero no divide entre cero', () {
      expect(zModificado(100, mediana: 50, mad: 0), 0);
    });
  });

  group('percentil', () {
    test('percentil 95 de una lista', () {
      final valores = List.generate(100, (i) => (i + 1).toDouble());
      expect(percentil(valores, 0.95), closeTo(95.05, 0.5));
    });

    test('lista de un elemento regresa ese elemento en cualquier percentil', () {
      expect(percentil([42], 0.95), 42);
    });

    test('lista vacía da 0', () => expect(percentil([], 0.5), 0));
  });
}
