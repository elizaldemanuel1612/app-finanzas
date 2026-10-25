import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/meta_apartado.dart';
import 'package:app_finanzas/domain/presupuesto/reajuste_ingreso.dart';
import 'package:test/test.dart';

CategoriaFija _fija(String id, Dinero monto, {bool activa = true}) => CategoriaFija(
      id: id,
      nombre: id,
      emoji: '🏠',
      activa: activa,
      esNecesaria: true,
      montoFijoCentavos: monto,
      diaDelCiclo: 5,
    );

CategoriaVariable _variable(String id, Dinero monto, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
      presupuestoMensualCentavos: monto,
    );

void main() {
  group('reajustarAlNuevoIngreso', () {
    test('el caso del cero de más: 350,000 → 35,000 divide todo entre 10', () {
      final r = reajustarAlNuevoIngreso(
        categorias: [
          _fija('renta', const Dinero.pesos(150000)),
          _variable('super', const Dinero.pesos(70000)),
        ],
        meta: const MetaPorMonto(Dinero.pesos(35000)),
        ingresoAnterior: const Dinero.pesos(350000),
        ingresoNuevo: const Dinero.pesos(35000),
      );
      final renta = r.categorias[0] as CategoriaFija;
      final superm = r.categorias[1] as CategoriaVariable;
      expect(renta.montoFijoCentavos, const Dinero.pesos(15000));
      expect(renta.diaDelCiclo, 5, reason: 'solo cambia el monto');
      expect(renta.esNecesaria, isTrue);
      expect(superm.presupuestoMensualCentavos, const Dinero.pesos(7000));
      expect((r.meta! as MetaPorMonto).monto, const Dinero.pesos(3500));
    });

    test('redondea hacia abajo al peso entero', () {
      final r = reajustarAlNuevoIngreso(
        categorias: [_variable('super', const Dinero(100050))], // $1,000.50
        meta: null,
        ingresoAnterior: const Dinero.pesos(3),
        ingresoNuevo: const Dinero.pesos(2),
      );
      // 1,000.50 × 2/3 = 667.00 → $667.
      expect((r.categorias.single as CategoriaVariable).presupuestoMensualCentavos,
          const Dinero.pesos(667));
      expect(r.meta, isNull);
    });

    test('nunca deja un presupuesto en cero: mínimo \$1', () {
      final r = reajustarAlNuevoIngreso(
        categorias: [_variable('cafe', const Dinero.pesos(5))],
        meta: null,
        ingresoAnterior: const Dinero.pesos(100000),
        ingresoNuevo: const Dinero.pesos(1000),
      );
      expect((r.categorias.single as CategoriaVariable).presupuestoMensualCentavos,
          const Dinero.pesos(1));
    });

    test('las archivadas y la meta por porcentaje no se tocan', () {
      final archivada = _variable('viejo', const Dinero.pesos(900), activa: false);
      const meta = MetaPorPorcentaje(15);
      final r = reajustarAlNuevoIngreso(
        categorias: [archivada],
        meta: meta,
        ingresoAnterior: const Dinero.pesos(20000),
        ingresoNuevo: const Dinero.pesos(40000),
      );
      expect(identical(r.categorias.single, archivada), isTrue);
      expect(identical(r.meta, meta), isTrue);
    });

    test('si el ingreso no cambió o no es positivo, regresa todo igual', () {
      final cats = [_variable('super', const Dinero.pesos(500))];
      for (final (anterior, nuevo) in [
        (const Dinero.pesos(100), const Dinero.pesos(100)),
        (const Dinero.cero(), const Dinero.pesos(100)),
        (const Dinero.pesos(100), const Dinero.cero()),
      ]) {
        final r = reajustarAlNuevoIngreso(
          categorias: cats,
          meta: null,
          ingresoAnterior: anterior,
          ingresoNuevo: nuevo,
        );
        expect(identical(r.categorias, cats), isTrue);
      }
    });
  });

  test('totalPresupuestado suma fijas y variables activas', () {
    expect(
      totalPresupuestado([
        _fija('renta', const Dinero.pesos(1000)),
        _variable('super', const Dinero.pesos(500)),
        _variable('viejo', const Dinero.pesos(999), activa: false),
      ]),
      const Dinero.pesos(1500),
    );
  });
}
