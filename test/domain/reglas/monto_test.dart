import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/reglas/monto.dart';
import 'package:test/test.dart';

void main() {
  test('monto positivo tiene éxito', () {
    expect(validarMontoPositivo(const Dinero(100)), isA<Exito<void>>());
  });

  test('monto cero falla', () {
    expect(validarMontoPositivo(const Dinero.cero()), isA<Falla<void>>());
  });

  test('monto negativo falla', () {
    expect(validarMontoPositivo(const Dinero(-100)), isA<Falla<void>>());
  });

  test('el mensaje de falla usa la etiqueta dada', () {
    final r = validarMontoPositivo(
      const Dinero.cero(),
      etiqueta: 'presupuesto',
    );
    expect((r as Falla).mensaje, contains('presupuesto'));
  });
}
