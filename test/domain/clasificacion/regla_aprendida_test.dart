import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:test/test.dart';

void main() {
  group('registrarCorreccion', () {
    test('crea una regla nueva cuando no existe', () {
      final reglas = registrarCorreccion(
        reglasActuales: const [],
        patron: 'Oxxo',
        categoriaId: 'super',
      );
      expect(reglas, hasLength(1));
      expect(reglas.single.patron, 'oxxo'); // normalizado
      expect(reglas.single.categoriaId, 'super');
      expect(reglas.single.contador, 1);
    });

    test('incrementa el contador si la misma regla se confirma de nuevo', () {
      var reglas = registrarCorreccion(reglasActuales: const [], patron: 'Oxxo', categoriaId: 'super');
      reglas = registrarCorreccion(reglasActuales: reglas, patron: 'oxxo', categoriaId: 'super');
      reglas = registrarCorreccion(reglasActuales: reglas, patron: 'OXXO', categoriaId: 'super');
      expect(reglas, hasLength(1));
      expect(reglas.single.contador, 3);
    });

    test('un mismo patrón con distinta categoría crea una regla aparte', () {
      var reglas = registrarCorreccion(reglasActuales: const [], patron: 'Oxxo', categoriaId: 'super');
      reglas = registrarCorreccion(reglasActuales: reglas, patron: 'Oxxo', categoriaId: 'efectivo');
      expect(reglas, hasLength(2));
    });

    test('patrón vacío no crea ninguna regla', () {
      final reglas = registrarCorreccion(reglasActuales: const [], patron: '   ', categoriaId: 'super');
      expect(reglas, isEmpty);
    });

    test('no modifica la lista original (inmutable)', () {
      const original = <ReglaAprendida>[];
      registrarCorreccion(reglasActuales: original, patron: 'Oxxo', categoriaId: 'super');
      expect(original, isEmpty);
    });
  });
}
