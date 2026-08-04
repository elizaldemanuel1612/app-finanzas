import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/reglas/estado_inicial.dart';
import 'package:test/test.dart';

void main() {
  group('capturado por el usuario (manual, voz, ticket, migración)', () {
    for (final origen in [
      OrigenCaptura.manual,
      OrigenCaptura.voz,
      OrigenCaptura.ticket,
      OrigenCaptura.migracion,
    ]) {
      test('$origen + activo tiene éxito', () {
        final r = validarEstadoInicial(
          origenCaptura: origen,
          estado: EstadoMovimiento.activo,
        );
        expect(r.esExito, isTrue);
      });

      test('$origen + propuesto falla (el usuario sí lo escribió)', () {
        final r = validarEstadoInicial(
          origenCaptura: origen,
          estado: EstadoMovimiento.propuesto,
        );
        expect(r.esFalla, isTrue);
      });
    }
  });

  group('generado por el sistema (recurrente)', () {
    test('recurrente + propuesto tiene éxito', () {
      final r = validarEstadoInicial(
        origenCaptura: OrigenCaptura.recurrente,
        estado: EstadoMovimiento.propuesto,
      );
      expect(r.esExito, isTrue);
    });

    test('recurrente + activo falla (nadie lo confirmó todavía)', () {
      final r = validarEstadoInicial(
        origenCaptura: OrigenCaptura.recurrente,
        estado: EstadoMovimiento.activo,
      );
      expect(r.esFalla, isTrue);
    });
  });

  test('ningún origen puede nacer anulado', () {
    for (final origen in OrigenCaptura.values) {
      final r = validarEstadoInicial(
        origenCaptura: origen,
        estado: EstadoMovimiento.anulado,
      );
      expect(r.esFalla, isTrue, reason: '$origen no debería poder nacer anulado');
    }
  });
}
