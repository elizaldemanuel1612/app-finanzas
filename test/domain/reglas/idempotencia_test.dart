import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/reglas/idempotencia.dart';
import 'package:test/test.dart';

void main() {
  group('validarClientId', () {
    test('clientId vacío falla', () {
      expect(validarClientId(''), isA<Falla<void>>());
    });

    test('clientId de solo espacios falla', () {
      expect(validarClientId('   '), isA<Falla<void>>());
    });

    test('clientId demasiado corto falla', () {
      expect(validarClientId('abc123'), isA<Falla<void>>());
    });

    test('clientId válido tiene éxito', () {
      expect(validarClientId('a1b2c3d4-e5f6'), isA<Exito<void>>());
    });
  });

  group('esDuplicado', () {
    test('true si el clientId ya existe', () {
      expect(esDuplicado('x1', ['a1', 'x1', 'b2']), isTrue);
    });

    test('false si el clientId no existe', () {
      expect(esDuplicado('nuevo', ['a1', 'x1']), isFalse);
    });

    test('false contra una lista vacía', () {
      expect(esDuplicado('x1', const []), isFalse);
    });
  });
}
