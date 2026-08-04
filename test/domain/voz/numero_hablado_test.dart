import 'package:app_finanzas/domain/voz/numero_hablado.dart';
import 'package:test/test.dart';

void main() {
  group('valorDeTokensNumericos', () {
    test('dígito simple', () {
      expect(valorDeTokensNumericos(['480']), 480);
    });

    test('centena + decena en palabras', () {
      expect(valorDeTokensNumericos(['cuatrocientos', 'ochenta']), 480);
    });

    test('mil + centena + decena + y + unidad', () {
      expect(valorDeTokensNumericos(['tres', 'mil', 'ciento', 'treinta', 'y', 'dos']), 3132);
    });

    test('mil solo (sin multiplicador explícito) equivale a 1000', () {
      expect(valorDeTokensNumericos(['mil']), 1000);
    });

    test('mil + centena en palabras ("mil doscientos")', () {
      expect(valorDeTokensNumericos(['mil', 'doscientos']), 1200);
    });

    test('dígito + mil + dígito ("3 mil 132")', () {
      expect(valorDeTokensNumericos(['3', 'mil', '132']), 3132);
    });

    test('decena + y + unidad ("treinta y dos")', () {
      expect(valorDeTokensNumericos(['treinta', 'y', 'dos']), 32);
    });

    test('unidad especial 11-29 ("veintidos")', () {
      expect(valorDeTokensNumericos(['veintidos']), 22);
    });

    test('cien vs ciento dan el mismo valor', () {
      expect(valorDeTokensNumericos(['cien']), 100);
      expect(valorDeTokensNumericos(['ciento']), 100);
    });

    test('token vacío o solo "y" no forma número', () {
      expect(valorDeTokensNumericos(['y']), null);
      expect(valorDeTokensNumericos([]), null);
    });
  });

  group('esPalabraDeNumero', () {
    test('reconoce dígitos, palabras numéricas y el conector "y"', () {
      expect(esPalabraDeNumero('480'), true);
      expect(esPalabraDeNumero('cuatrocientos'), true);
      expect(esPalabraDeNumero('mil'), true);
      expect(esPalabraDeNumero('y'), true);
    });

    test('no reconoce palabras normales', () {
      expect(esPalabraDeNumero('café'), false);
      expect(esPalabraDeNumero('tarjeta'), false);
      expect(esPalabraDeNumero('de'), false);
    });
  });
}
