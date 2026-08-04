import 'package:app_finanzas/core/money.dart';
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

  group('JSON', () {
    test('viaje redondo exacto', () {
      final original = _base();
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
  });
}
