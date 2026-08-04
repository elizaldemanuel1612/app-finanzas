import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/reglas/ticket_dividido.dart';
import 'package:test/test.dart';

void main() {
  test('las partes que suman exacto tienen éxito (ejemplo del mockup del ticket)', () {
    final r = validarPartesTicket(
      total: const Dinero(184730),
      partes: const [Dinero(140230), Dinero(28500), Dinero(16000)],
    );
    expect(r.esExito, isTrue);
  });

  test('una sola parte igual al total tiene éxito', () {
    final r = validarPartesTicket(
      total: const Dinero(50000),
      partes: const [Dinero(50000)],
    );
    expect(r.esExito, isTrue);
  });

  test('partes que suman menos que el total falla y dice cuánto falta', () {
    final r = validarPartesTicket(
      total: const Dinero(1000),
      partes: const [Dinero(400), Dinero(400)],
    );
    expect(r.esFalla, isTrue);
    expect((r as Falla<void>).mensaje, contains(r'$2.00'));
  });

  test('partes que suman más que el total falla', () {
    final r = validarPartesTicket(
      total: const Dinero(1000),
      partes: const [Dinero(600), Dinero(600)],
    );
    expect(r.esFalla, isTrue);
  });

  test('ninguna parte falla', () {
    final r = validarPartesTicket(total: const Dinero(1000), partes: const []);
    expect(r.esFalla, isTrue);
  });
}
