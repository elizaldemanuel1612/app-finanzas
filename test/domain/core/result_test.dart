import 'package:app_finanzas/core/result.dart';
import 'package:test/test.dart';

void main() {
  group('Resultado.exito', () {
    test('esExito es true, esFalla es false', () {
      const r = Resultado<int>.exito(5);
      expect(r.esExito, isTrue);
      expect(r.esFalla, isFalse);
    });

    test('valorOLanza regresa el valor', () {
      const r = Resultado<int>.exito(5);
      expect(r.valorOLanza, 5);
    });

    test('cuando() llama la rama de éxito', () {
      const r = Resultado<int>.exito(5);
      final texto = r.cuando(
        exito: (v) => 'ok:$v',
        falla: (m) => 'error:$m',
      );
      expect(texto, 'ok:5');
    });

    test('igualdad entre dos éxitos con el mismo valor', () {
      expect(const Exito(5), const Exito(5));
      expect(const Exito(5).hashCode, const Exito(5).hashCode);
    });

    test('toString', () {
      expect(const Exito(5).toString(), 'Exito(5)');
    });
  });

  group('Resultado.falla', () {
    test('esExito es false, esFalla es true', () {
      const r = Resultado<int>.falla('algo salió mal');
      expect(r.esExito, isFalse);
      expect(r.esFalla, isTrue);
    });

    test('valorOLanza lanza StateError con el mensaje', () {
      const r = Resultado<int>.falla('algo salió mal');
      expect(
        () => r.valorOLanza,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          'algo salió mal',
        )),
      );
    });

    test('cuando() llama la rama de falla', () {
      const r = Resultado<int>.falla('algo salió mal');
      final texto = r.cuando(
        exito: (v) => 'ok:$v',
        falla: (m) => 'error:$m',
      );
      expect(texto, 'error:algo salió mal');
    });

    test('igualdad entre dos fallas con el mismo mensaje', () {
      expect(const Falla<int>('x'), const Falla<int>('x'));
      expect(const Falla<int>('x').hashCode, const Falla<int>('x').hashCode);
    });

    test('toString', () {
      expect(const Falla<int>('x').toString(), 'Falla(x)');
    });
  });

  test('un patrón switch distingue Exito de Falla', () {
    Resultado<int> clasificar(Resultado<int> r) => switch (r) {
          Exito<int>() => const Exito(1),
          Falla<int>() => const Falla('no'),
        };
    expect(clasificar(const Exito(99)), const Exito(1));
    expect(clasificar(const Falla('x')), const Falla<int>('no'));
  });
}
