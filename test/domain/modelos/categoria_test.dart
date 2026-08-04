import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:test/test.dart';

CategoriaFija _fija({int diaDelCiclo = 1}) => CategoriaFija(
      id: 'vivienda',
      nombre: 'Vivienda',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: const Dinero.pesos(9910),
      diaDelCiclo: diaDelCiclo,
    );

CategoriaVariable _variable() => const CategoriaVariable(
      id: 'super',
      nombre: 'Súper',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(8000),
    );

void main() {
  group('CategoriaFija', () {
    test('guarda sus campos', () {
      final c = _fija();
      expect(c.montoFijoCentavos, const Dinero.pesos(9910));
      expect(c.diaDelCiclo, 1);
      expect(c.esNecesaria, isTrue);
    });

    test('día del ciclo fuera de rango lanza (1-31)', () {
      expect(() => _fija(diaDelCiclo: 0), throwsA(isA<AssertionError>()));
      expect(() => _fija(diaDelCiclo: 32), throwsA(isA<AssertionError>()));
    });

    test('igualdad por id, monto y día', () {
      expect(_fija(), _fija());
      expect(_fija().hashCode, _fija().hashCode);
      expect(_fija(diaDelCiclo: 1) == _fija(diaDelCiclo: 5), isFalse);
    });
  });

  group('CategoriaVariable', () {
    test('guarda sus campos', () {
      final c = _variable();
      expect(c.presupuestoMensualCentavos, const Dinero.pesos(8000));
    });

    test('igualdad por id y presupuesto', () {
      expect(_variable(), _variable());
      expect(_variable().hashCode, _variable().hashCode);
    });
  });

  test('una fija y una variable con el mismo id nunca son iguales', () {
    final fija = CategoriaFija(
      id: 'x',
      nombre: 'X',
      emoji: '❔',
      activa: true,
      esNecesaria: false,
      montoFijoCentavos: const Dinero.cero(),
      diaDelCiclo: 1,
    );
    const variable = CategoriaVariable(
      id: 'x',
      nombre: 'X',
      emoji: '❔',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.cero(),
    );
    // ignore: unrelated_type_equality_checks
    expect(fija == variable, isFalse);
  });

  group('JSON', () {
    test('CategoriaFija: viaje redondo exacto', () {
      final original = _fija();
      final reconstruida = Categoria.fromJson(original.toJson());
      expect(reconstruida, original);
      expect(reconstruida, isA<CategoriaFija>());
    });

    test('CategoriaVariable: viaje redondo exacto', () {
      final original = _variable();
      final reconstruida = Categoria.fromJson(original.toJson());
      expect(reconstruida, original);
      expect(reconstruida, isA<CategoriaVariable>());
    });

    test('el discriminador "tipo" distingue fija de variable', () {
      expect(_fija().toJson()['tipo'], 'fija');
      expect(_variable().toJson()['tipo'], 'variable');
    });

    test('un tipo desconocido lanza FormatException', () {
      expect(
        () => Categoria.fromJson({'tipo': 'inventado'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('Categoria es sellada: el switch exhaustivo compila sin default', () {
    String describir(Categoria c) => switch (c) {
          CategoriaFija() => 'fija',
          CategoriaVariable() => 'variable',
        };
    expect(describir(_fija()), 'fija');
    expect(describir(_variable()), 'variable');
  });
}
