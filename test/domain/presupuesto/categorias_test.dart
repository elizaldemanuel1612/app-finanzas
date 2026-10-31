import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/categorias.dart';
import 'package:test/test.dart';

void main() {
  group('crearCategoriaFija', () {
    test('caso válido tiene éxito', () {
      final r = crearCategoriaFija(
        id: 'vivienda',
        nombre: 'Vivienda',
        emoji: '🏠',
        montoFijoCentavos: const Dinero.pesos(9910),
        diaDelCiclo: 1,
        esNecesaria: true,
      );
      expect(r.esExito, isTrue);
      expect((r as Exito<CategoriaFija>).valor.montoFijoCentavos, const Dinero.pesos(9910));
    });

    test('id vacío falla', () {
      final r = crearCategoriaFija(
        id: '',
        nombre: 'Vivienda',
        emoji: '🏠',
        montoFijoCentavos: const Dinero.pesos(9910),
        diaDelCiclo: 1,
      );
      expect(r.esFalla, isTrue);
    });

    test('nombre vacío falla', () {
      final r = crearCategoriaFija(
        id: 'vivienda',
        nombre: '   ',
        emoji: '🏠',
        montoFijoCentavos: const Dinero.pesos(9910),
        diaDelCiclo: 1,
      );
      expect(r.esFalla, isTrue);
    });

    test('monto cero falla', () {
      final r = crearCategoriaFija(
        id: 'vivienda',
        nombre: 'Vivienda',
        emoji: '🏠',
        montoFijoCentavos: const Dinero.cero(),
        diaDelCiclo: 1,
      );
      expect(r.esFalla, isTrue);
    });

    test('día del ciclo fuera de rango falla sin necesidad de assert', () {
      final r = crearCategoriaFija(
        id: 'vivienda',
        nombre: 'Vivienda',
        emoji: '🏠',
        montoFijoCentavos: const Dinero.pesos(9910),
        diaDelCiclo: 32,
      );
      expect(r.esFalla, isTrue);
    });
  });

  group('crearCategoriaVariable', () {
    test('caso válido tiene éxito', () {
      final r = crearCategoriaVariable(
        id: 'super',
        nombre: 'Súper',
        emoji: '🛒',
        presupuestoMensualCentavos: const Dinero.pesos(8000),
      );
      expect(r.esExito, isTrue);
    });

    test('presupuesto negativo falla', () {
      final r = crearCategoriaVariable(
        id: 'super',
        nombre: 'Súper',
        emoji: '🛒',
        presupuestoMensualCentavos: const Dinero(-1),
      );
      expect(r.esFalla, isTrue);
    });
  });

  group('actualizarMontoFijo (app-finanzas-fijos-cierre-v6.html §3)', () {
    final vivienda = crearCategoriaFija(
      id: 'vivienda',
      nombre: 'Vivienda',
      emoji: '🏠',
      montoFijoCentavos: const Dinero.pesos(9910),
      diaDelCiclo: 1,
    ).valorOLanza;

    test('"solo este mes" no cambia la categoría', () {
      final r = actualizarMontoFijo(
        categoria: vivienda,
        montoObservado: const Dinero.pesos(10400),
        actualizarParaSiguientesCiclos: false,
      );
      expect((r as Exito<CategoriaFija>).valor.montoFijoCentavos, const Dinero.pesos(9910));
    });

    test('"actualizar" cambia el monto fijo para adelante', () {
      final r = actualizarMontoFijo(
        categoria: vivienda,
        montoObservado: const Dinero.pesos(10400),
        actualizarParaSiguientesCiclos: true,
      );
      expect((r as Exito<CategoriaFija>).valor.montoFijoCentavos, const Dinero.pesos(10400));
    });

    test('el resto de los campos no se toca al actualizar', () {
      final r = actualizarMontoFijo(
        categoria: vivienda,
        montoObservado: const Dinero.pesos(10400),
        actualizarParaSiguientesCiclos: true,
      );
      final actualizada = (r as Exito<CategoriaFija>).valor;
      expect(actualizada.id, vivienda.id);
      expect(actualizada.diaDelCiclo, vivienda.diaDelCiclo);
    });

    test('monto observado inválido falla incluso si es "solo este mes"', () {
      final r = actualizarMontoFijo(
        categoria: vivienda,
        montoObservado: const Dinero.cero(),
        actualizarParaSiguientesCiclos: false,
      );
      expect(r.esFalla, isTrue);
    });
  });

  group('conActiva', () {
    test('desactiva una fija preservando el resto de sus campos', () {
      final fija = crearCategoriaFija(
        id: 'gimnasio',
        nombre: 'Gimnasio',
        emoji: '🏋️',
        montoFijoCentavos: const Dinero.pesos(658),
        diaDelCiclo: 5,
      ).valorOLanza;

      final desactivada = conActiva(fija, false) as CategoriaFija;
      expect(desactivada.activa, isFalse);
      expect(desactivada.montoFijoCentavos, fija.montoFijoCentavos);
      expect(desactivada.diaDelCiclo, fija.diaDelCiclo);
    });

    test('desactiva una variable preservando el resto de sus campos', () {
      final variable = crearCategoriaVariable(
        id: 'salidas',
        nombre: 'Salidas',
        emoji: '🍿',
        presupuestoMensualCentavos: const Dinero.pesos(6000),
      ).valorOLanza;

      final desactivada = conActiva(variable, false) as CategoriaVariable;
      expect(desactivada.activa, isFalse);
      expect(desactivada.presupuestoMensualCentavos, variable.presupuestoMensualCentavos);
    });

    test('reactivar regresa activa a true', () {
      final fija = crearCategoriaFija(
        id: 'x',
        nombre: 'X',
        emoji: '❔',
        montoFijoCentavos: const Dinero(100),
        diaDelCiclo: 1,
        activa: false,
      ).valorOLanza;

      expect((conActiva(fija, true) as CategoriaFija).activa, isTrue);
    });
  });
}
