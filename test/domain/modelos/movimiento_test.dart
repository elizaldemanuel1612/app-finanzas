import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

Movimiento _base({
  Dinero monto = const Dinero(48000),
  EstadoMovimiento estado = EstadoMovimiento.activo,
  String cicloId = '2026-07',
}) =>
    Movimiento(
      clientId: 'abc123def456',
      fecha: DateTime(2026, 7, 15),
      cicloId: cicloId,
      periodoNatural: '2026-07',
      monto: monto,
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'Despensa',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

void main() {
  test('dos movimientos con los mismos campos son iguales', () {
    expect(_base(), _base());
    expect(_base().hashCode, _base().hashCode);
  });

  test('difieren si el monto difiere', () {
    expect(_base() == _base(monto: const Dinero(1)), isFalse);
  });

  test('difieren si el estado difiere', () {
    expect(
      _base() == _base(estado: EstadoMovimiento.anulado),
      isFalse,
    );
  });

  test('difieren si el cicloId difiere', () {
    expect(_base() == _base(cicloId: '2026-08'), isFalse);
  });

  test('campos opcionales tienen los valores por defecto correctos', () {
    final m = _base();
    expect(m.id, isNull);
    expect(m.clasificadoPorIA, isFalse);
    expect(m.ticketId, isNull);
    expect(m.granularidad, isNull);
  });

  test('toString incluye datos identificables', () {
    final texto = _base().toString();
    expect(texto, contains('abc123def456'));
    expect(texto, contains('Despensa'));
    expect(texto, contains('2026-07'));
  });

  group('copyWith', () {
    test('sin argumentos regresa un movimiento igual', () {
      expect(_base().copyWith(), _base());
    });

    test('cambia el campo pedido y conserva el resto', () {
      final editado = _base().copyWith(descripcion: 'Despensa y limpieza');
      expect(editado.descripcion, 'Despensa y limpieza');
      expect(editado.monto, _base().monto);
      expect(editado.cicloId, _base().cicloId);
    });

    test('cicloId nunca cambia por copyWith — no existe como parámetro', () {
      // No hay forma de pasar cicloId: esto es una garantía de compilación,
      // no algo que se pueda probar en runtime. Esta prueba documenta que
      // copiar con otros cambios preserva el cicloId original siempre.
      final editado = _base().copyWith(monto: const Dinero(1), estado: EstadoMovimiento.anulado);
      expect(editado.cicloId, _base().cicloId);
    });

    test('idOrigen se puede fijar vía copyWith', () {
      final editado = _base().copyWith(idOrigen: 'HIST-0099');
      expect(editado.idOrigen, 'HIST-0099');
    });
  });

  group('JSON', () {
    test('toJson/fromJson hace un viaje redondo exacto (campos requeridos)', () {
      final original = _base();
      final reconstruido = Movimiento.fromJson(original.toJson());
      expect(reconstruido, original);
    });

    test('toJson/fromJson conserva todos los campos opcionales', () {
      final original = _base().copyWith(
        id: 'mov-1',
        ticketId: 'ticket-1',
        fotoUrl: 'https://x/foto.jpg',
        clasificadoPorIA: true,
        confianzaIA: 0.87,
        granularidad: Granularidad.agregadoDiario,
        idOrigen: 'HIST-0005',
      );
      final reconstruido = Movimiento.fromJson(original.toJson());
      expect(reconstruido, original);
    });

    test('toJson omite los campos opcionales que son null', () {
      final json = _base().toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('ticketId'), isFalse);
      expect(json.containsKey('idOrigen'), isFalse);
    });

    test('toJson usa los mismos nombres de campo que la spec (§4)', () {
      final json = _base().toJson();
      expect(json['montoCentavos'], _base().monto.centavos);
      expect(json['cicloId'], _base().cicloId);
      expect(json['clientId'], _base().clientId);
    });

    test(
        'fromJson de un JSON viejo con esReembolsable no truena — '
        'compatibilidad hacia atrás, la clave simplemente se ignora', () {
      final json = _base().toJson()
        ..['esReembolsable'] = true
        ..['reembolsoId'] = 'reembolso-1';
      final movimiento = Movimiento.fromJson(json);
      expect(movimiento, _base());
    });
  });
}
