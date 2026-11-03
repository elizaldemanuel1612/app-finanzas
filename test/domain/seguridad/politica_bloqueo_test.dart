import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/seguridad/politica_bloqueo.dart';
import 'package:test/test.dart';

void main() {
  final ahora = DateTime(2026, 11, 2, 12);

  test('el PIN se pide la primera vez y luego cada semana', () {
    expect(tocaPedirPin(ultimoPin: null, ahora: ahora), isTrue);
    expect(tocaPedirPin(ultimoPin: ahora.subtract(const Duration(days: 6, hours: 23)), ahora: ahora), isFalse);
    expect(tocaPedirPin(ultimoPin: ahora.subtract(const Duration(days: 7)), ahora: ahora), isTrue);
  });

  test('vuelve a bloquear tras 2 minutos sin tocar la app', () {
    expect(debeBloquearAlVolver(ultimaActividad: null, ahora: ahora), isTrue);
    expect(debeBloquearAlVolver(ultimaActividad: ahora.subtract(const Duration(seconds: 119)), ahora: ahora), isFalse);
    expect(debeBloquearAlVolver(ultimaActividad: ahora.subtract(const Duration(minutes: 2)), ahora: ahora), isTrue);
  });

  test('esperas crecientes y, al décimo fallo, solo recuperar', () {
    expect(esperaTrasFallidos(0), Duration.zero);
    expect(esperaTrasFallidos(4), Duration.zero);
    expect(esperaTrasFallidos(5), const Duration(seconds: 30));
    expect(esperaTrasFallidos(6), const Duration(minutes: 1));
    expect(esperaTrasFallidos(7), const Duration(minutes: 5));
    expect(esperaTrasFallidos(8), const Duration(minutes: 15));
    expect(esperaTrasFallidos(9), const Duration(hours: 1));
    expect(esperaTrasFallidos(10), isNull);
  });

  test('PIN: 6 números y no fácil de adivinar', () {
    expect(validarPinNuevo('482915').esExito, isTrue);
    for (final malo in ['12345', '1234567', '12a456', '111111', '123456', '654321', '890123', '098765']) {
      expect(validarPinNuevo(malo).esFalla, isTrue, reason: malo);
    }
    expect((validarPinNuevo('111111') as Falla).mensaje, contains('fácil'));
  });

  test('contraseña: 6 o más, con letras y números', () {
    expect(validarContrasenaNueva('casa12').esExito, isTrue);
    expect(validarContrasenaNueva('ñandú7').esExito, isTrue);
    expect((validarContrasenaNueva('ab1') as Falla).mensaje, contains('6'));
    expect(validarContrasenaNueva('casasola').esFalla, isTrue);
    expect(validarContrasenaNueva('12345678').esFalla, isTrue);
  });
}
