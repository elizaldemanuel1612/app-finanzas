import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/meta_apartado.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:test/test.dart';

Perfil _base() => const Perfil(
      diaCorte: 12,
      ingresoBaseMensual: Dinero.pesos(87000),
    );

void main() {
  test('valores por defecto de moneda y zona horaria', () {
    final p = _base();
    expect(p.moneda, 'MXN');
    expect(p.zonaHoraria, 'America/Mexico_City');
  });

  test('metaApartado es null por defecto (perfil viejo, meta derivada)', () {
    expect(_base().metaApartado, isNull);
  });

  test('igualdad estructural', () {
    expect(_base(), _base());
    expect(_base().hashCode, _base().hashCode);
  });

  test('copyWith cambia solo lo pedido', () {
    final editado = _base().copyWith(diaCorte: 5);
    expect(editado.diaCorte, 5);
    expect(editado.ingresoBaseMensual, _base().ingresoBaseMensual);
  });

  test('copyWith sin argumentos conserva todos los campos, incluido diaCorte', () {
    expect(_base().copyWith(), _base());
  });

  test('copyWith puede cambiar ingreso, moneda y zona horaria', () {
    final editado = _base().copyWith(
      ingresoBaseMensual: const Dinero.pesos(90000),
      moneda: 'USD',
      zonaHoraria: 'America/New_York',
    );
    expect(editado.ingresoBaseMensual, const Dinero.pesos(90000));
    expect(editado.moneda, 'USD');
    expect(editado.zonaHoraria, 'America/New_York');
    expect(editado.diaCorte, _base().diaCorte);
  });

  group('meta de apartado', () {
    test('copyWith puede declarar una meta', () {
      final editado = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      expect(editado.metaApartado, const MetaPorPorcentaje(30));
    });

    test('copyWith con quitarMeta regresa al modo derivado aunque no se pase metaApartado', () {
      final conMeta = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      final sinMeta = conMeta.copyWith(quitarMeta: true);
      expect(sinMeta.metaApartado, isNull);
    });

    test('copyWith sin quitarMeta ni metaApartado conserva la meta existente', () {
      final conMeta = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      expect(conMeta.copyWith(diaCorte: 5).metaApartado, const MetaPorPorcentaje(30));
    });

    test('quitarMeta gana aunque también se pase metaApartado por accidente', () {
      final conMeta = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      final resultado = conMeta.copyWith(metaApartado: const MetaPorPorcentaje(50), quitarMeta: true);
      expect(resultado.metaApartado, isNull);
    });

    test('la meta entra a la igualdad estructural', () {
      final a = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      final b = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      final c = _base().copyWith(metaApartado: const MetaPorPorcentaje(40));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('JSON', () {
    test('viaje redondo exacto', () {
      final original = _base();
      expect(Perfil.fromJson(original.toJson()), original);
    });

    test('viaje redondo exacto con meta declarada', () {
      final original = _base().copyWith(metaApartado: const MetaPorPorcentaje(30));
      expect(Perfil.fromJson(original.toJson()), original);
    });

    test('fromJson usa defaults si moneda/zonaHoraria faltan', () {
      final p = Perfil.fromJson({
        'diaCorte': 12,
        'ingresoBaseMensualCentavos': 8700000,
      });
      expect(p.moneda, 'MXN');
      expect(p.zonaHoraria, 'America/Mexico_City');
    });

    test('fromJson de un perfil viejo sin metaApartado sigue abriendo con meta derivada', () {
      final p = Perfil.fromJson({
        'diaCorte': 12,
        'ingresoBaseMensualCentavos': 8700000,
        'moneda': 'MXN',
        'zonaHoraria': 'America/Mexico_City',
      });
      expect(p.metaApartado, isNull);
    });
  });
}
