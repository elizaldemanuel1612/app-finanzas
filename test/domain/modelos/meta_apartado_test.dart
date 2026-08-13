import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/meta_apartado.dart';
import 'package:test/test.dart';

void main() {
  group('MetaPorMonto', () {
    test('montoPara regresa el monto fijo sin importar el ingreso', () {
      const meta = MetaPorMonto(Dinero.pesos(5000));
      expect(meta.montoPara(const Dinero.pesos(1)), const Dinero.pesos(5000));
      expect(meta.montoPara(const Dinero.pesos(999999)), const Dinero.pesos(5000));
    });

    test('toJson/fromJson viaje redondo', () {
      const meta = MetaPorMonto(Dinero.pesos(5000));
      final json = meta.toJson();
      expect(json, {'tipo': 'monto', 'montoMetaCentavos': 500000});
      expect(MetaApartado.fromJson(json), meta);
    });

    test('igualdad estructural', () {
      expect(const MetaPorMonto(Dinero.pesos(100)), const MetaPorMonto(Dinero.pesos(100)));
      expect(
        const MetaPorMonto(Dinero.pesos(100)).hashCode,
        const MetaPorMonto(Dinero.pesos(100)).hashCode,
      );
      expect(const MetaPorMonto(Dinero.pesos(100)) == const MetaPorMonto(Dinero.pesos(200)), isFalse);
    });

    test('toString describe la meta', () {
      expect(const MetaPorMonto(Dinero.pesos(100)).toString(), contains('MetaPorMonto'));
    });
  });

  group('MetaPorPorcentaje', () {
    test('redondeo entero medio arriba, sin punto flotante', () {
      // 101 centavos * 50% = 50.5 centavos exactos -> redondea a 51.
      expect(const MetaPorPorcentaje(50).montoPara(const Dinero(101)), const Dinero(51));
    });

    test('0% siempre da cero', () {
      expect(const MetaPorPorcentaje(0).montoPara(const Dinero.pesos(87000)), const Dinero.cero());
    });

    test('100% regresa el ingreso completo', () {
      const ingreso = Dinero(12345);
      expect(const MetaPorPorcentaje(100).montoPara(ingreso), ingreso);
    });

    test('caso del mockup: 40% de 87,000 da 34,800', () {
      expect(
        const MetaPorPorcentaje(40).montoPara(const Dinero.pesos(87000)),
        const Dinero.pesos(34800),
      );
    });

    test('toJson/fromJson viaje redondo', () {
      const meta = MetaPorPorcentaje(30);
      final json = meta.toJson();
      expect(json, {'tipo': 'porcentaje', 'pctApartado': 30});
      expect(MetaApartado.fromJson(json), meta);
    });

    test('igualdad estructural', () {
      expect(const MetaPorPorcentaje(30), const MetaPorPorcentaje(30));
      expect(const MetaPorPorcentaje(30).hashCode, const MetaPorPorcentaje(30).hashCode);
      expect(const MetaPorPorcentaje(30) == const MetaPorPorcentaje(40), isFalse);
    });

    test('toString describe la meta', () {
      expect(const MetaPorPorcentaje(30).toString(), contains('30%'));
    });
  });

  test('fromJson lanza con un tipo desconocido', () {
    expect(
      () => MetaApartado.fromJson({'tipo': 'quien-sabe'}),
      throwsA(isA<FormatException>()),
    );
  });
}
