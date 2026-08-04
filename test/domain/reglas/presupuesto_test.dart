import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/reglas/presupuesto.dart';
import 'package:test/test.dart';

CategoriaFija _fija(String id, int pesos, {int dia = 1}) => CategoriaFija(
      id: id,
      nombre: id,
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(pesos),
      diaDelCiclo: dia,
    );

CategoriaVariable _variable(String id, int pesos) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );

void main() {
  group('disponibleParaVariables (regla no negociable #10)', () {
    test('las fijas caben: regresa el sobrante exacto', () {
      final r = disponibleParaVariables(
        ingresoDisponible: const Dinero.pesos(100000),
        fijas: [_fija('vivienda', 9910), _fija('spotify', 239)],
      );
      expect(r, isA<Exito<Dinero>>());
      expect((r as Exito<Dinero>).valor, const Dinero.pesos(100000 - 9910 - 239));
    });

    test('sin fijas, todo el ingreso queda disponible', () {
      final r = disponibleParaVariables(
        ingresoDisponible: const Dinero.pesos(50000),
        fijas: const [],
      );
      expect((r as Exito<Dinero>).valor, const Dinero.pesos(50000));
    });

    test('las fijas exactamente iguales al ingreso dejan cero, no falla', () {
      final r = disponibleParaVariables(
        ingresoDisponible: const Dinero.pesos(9910),
        fijas: [_fija('vivienda', 9910)],
      );
      expect((r as Exito<Dinero>).valor, const Dinero.cero());
    });

    test('las fijas exceden el ingreso: se bloquea e informa cuánto falta', () {
      final r = disponibleParaVariables(
        ingresoDisponible: const Dinero.pesos(5000),
        fijas: [_fija('vivienda', 9910)],
      );
      expect(r.esFalla, isTrue);
      expect((r as Falla<Dinero>).mensaje, contains(r'$4,910.00'));
    });
  });

  group('validarPresupuestoNoExcedeDisponible (regla no negociable #11)', () {
    test('el total variable dentro de lo disponible tiene éxito', () {
      final r = validarPresupuestoNoExcedeDisponible(
        disponible: const Dinero.pesos(20000),
        variables: [_variable('super', 8000), _variable('salidas', 6000)],
      );
      expect(r.esExito, isTrue);
    });

    test('el total variable exactamente igual a lo disponible tiene éxito', () {
      final r = validarPresupuestoNoExcedeDisponible(
        disponible: const Dinero.pesos(8000),
        variables: [_variable('super', 8000)],
      );
      expect(r.esExito, isTrue);
    });

    test('el total variable que excede lo disponible falla con el exceso', () {
      final r = validarPresupuestoNoExcedeDisponible(
        disponible: const Dinero.pesos(10000),
        variables: [_variable('super', 8000), _variable('salidas', 6000)],
      );
      expect(r.esFalla, isTrue);
      expect((r as Falla<void>).mensaje, contains(r'$4,000.00'));
    });
  });
}
