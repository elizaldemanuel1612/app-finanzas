import 'package:app_finanzas/domain/modelos/cambio_auditoria.dart';
import 'package:test/test.dart';

void main() {
  CambioAuditoria crear() => CambioAuditoria(
        campo: 'monto',
        valorAnterior: r'$1,101.00',
        valorNuevo: r'$850.00',
        cuando: DateTime(2026, 7, 28, 19, 42),
        dispositivo: 'iPhone',
      );

  test('guarda todos los campos', () {
    final c = crear();
    expect(c.campo, 'monto');
    expect(c.valorAnterior, r'$1,101.00');
    expect(c.valorNuevo, r'$850.00');
    expect(c.dispositivo, 'iPhone');
  });

  test('igualdad estructural', () {
    expect(crear(), crear());
    expect(crear().hashCode, crear().hashCode);
  });

  test('toString describe el cambio', () {
    expect(crear().toString(), contains(r'$1,101.00 → $850.00'));
  });
}
