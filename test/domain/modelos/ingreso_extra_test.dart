import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:test/test.dart';

IngresoExtra _base({
  Dinero monto = const Dinero.pesos(15000),
  DestinoExtra destino = DestinoExtra.apartado,
  EstadoIngreso estado = EstadoIngreso.activo,
}) =>
    IngresoExtra(
      id: 'ing-1',
      cicloId: '2026-07',
      etiqueta: 'Bono',
      monto: monto,
      fecha: DateTime(2026, 7, 15),
      destino: destino,
      estado: estado,
    );

void main() {
  test('dos ingresos con los mismos campos son iguales', () {
    expect(_base(), _base());
    expect(_base().hashCode, _base().hashCode);
  });

  test('difieren si el monto difiere', () {
    expect(_base() == _base(monto: const Dinero.pesos(1)), isFalse);
  });

  test('difieren si el destino difiere', () {
    expect(_base() == _base(destino: DestinoExtra.gasto), isFalse);
  });

  test('difieren si el estado difiere', () {
    expect(_base() == _base(estado: EstadoIngreso.anulado), isFalse);
  });

  test('toString incluye datos identificables', () {
    final texto = _base().toString();
    expect(texto, contains('Bono'));
    expect(texto, contains('2026-07'));
  });

  group('copyWith', () {
    test('sin argumentos regresa un ingreso igual', () {
      expect(_base().copyWith(), _base());
    });

    test('cambia el campo pedido y conserva el resto', () {
      final editado = _base().copyWith(etiqueta: 'Aguinaldo');
      expect(editado.etiqueta, 'Aguinaldo');
      expect(editado.monto, _base().monto);
      expect(editado.cicloId, _base().cicloId);
    });

    test('cicloId nunca cambia por copyWith — no existe como parámetro', () {
      final editado = _base().copyWith(monto: const Dinero.pesos(1));
      expect(editado.cicloId, _base().cicloId);
    });

    test('anular es un copyWith de estado', () {
      final anulado = _base().copyWith(estado: EstadoIngreso.anulado);
      expect(anulado.estado, EstadoIngreso.anulado);
    });
  });

  group('JSON', () {
    test('toJson/fromJson hace un viaje redondo exacto', () {
      final original = _base();
      final reconstruido = IngresoExtra.fromJson(original.toJson());
      expect(reconstruido, original);
    });

    test('destino y estado viajan por su .name', () {
      final json = _base(destino: DestinoExtra.gasto).toJson();
      expect(json['destino'], 'gasto');
      expect(json['estado'], 'activo');
    });

    test('toJson usa los mismos nombres de campo que la spec (§4)', () {
      final json = _base().toJson();
      expect(json['montoCentavos'], _base().monto.centavos);
      expect(json['cicloId'], _base().cicloId);
      expect(json['id'], _base().id);
    });
  });
}
