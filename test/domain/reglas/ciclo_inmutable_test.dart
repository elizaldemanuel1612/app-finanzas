import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/domain/reglas/ciclo_inmutable.dart';
import 'package:test/test.dart';

void main() {
  group('validarCicloSinCambios', () {
    test('mismo cicloId tiene éxito', () {
      final r = validarCicloSinCambios(
        cicloIdOriginal: '2026-07',
        cicloIdPropuesto: '2026-07',
      );
      expect(r.esExito, isTrue);
    });

    test('cicloId distinto falla', () {
      final r = validarCicloSinCambios(
        cicloIdOriginal: '2026-07',
        cicloIdPropuesto: '2026-08',
      );
      expect(r.esFalla, isTrue);
    });
  });

  group('validarPuedeModificarse', () {
    final abierto = const CalculadoraCiclo(12).calcularPara(DateTime(2026, 7, 15));

    test('ciclo abierto se puede modificar', () {
      expect(validarPuedeModificarse(abierto).esExito, isTrue);
    });

    test('ciclo cerrado no se puede modificar sin reabrir', () {
      final cerrado = abierto.cerrar().valorOLanza;
      expect(validarPuedeModificarse(cerrado).esFalla, isTrue);
    });

    test('reabierto explícitamente vuelve a ser modificable', () {
      final cerrado = abierto.cerrar().valorOLanza;
      final reabierto = cerrado.reabrir().valorOLanza;
      expect(validarPuedeModificarse(reabierto).esExito, isTrue);
    });
  });
}
