import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/presupuestos_del_cierre.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:test/test.dart';

CategoriaVariable _var(String id, int pesos, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: activa,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );

const _renta = CategoriaFija(
  id: 'renta',
  nombre: 'Renta',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: Dinero.pesos(5000),
  diaDelCiclo: 1,
);

RenglonSnapshot _renglon(String id, int presupuesto) => RenglonSnapshot(
      categoriaId: id,
      nombre: id,
      emoji: '🛒',
      presupuestoCentavos: Dinero.pesos(presupuesto),
      realCentavos: const Dinero.pesos(10),
      conteoMovimientos: 1,
    );

void main() {
  final categorias = <Categoria>[_var('super', 4000), _var('ropa', 800, activa: false), _var('cafe', 300), _renta];

  test('sin fotografía del cierre: las categorías tal cual', () {
    expect(presupuestosDelCierre(categorias: categorias, snapshot: null), same(categorias));
  });

  test('con fotografía: cada variable toma el presupuesto que tenía al cerrar', () {
    final snapshot = SnapshotCiclo(
      cicloId: '2026-10',
      fechaCierre: DateTime(2026, 11, 1),
      ingresoTotal: const Dinero.pesos(20000),
      metaApartado: const Dinero.pesos(2000),
      totalGastado: const Dinero.pesos(30),
      renglones: [_renglon('super', 3500), _renglon('ropa', 600), _renglon('cafe', 0), _renglon('renta', 5000)],
    );
    final r = presupuestosDelCierre(categorias: categorias, snapshot: snapshot);
    final superm = r[0] as CategoriaVariable;
    expect(superm.presupuestoMensualCentavos, const Dinero.pesos(3500));
    final ropa = r[1] as CategoriaVariable;
    expect(ropa.presupuestoMensualCentavos, const Dinero.pesos(600));
    expect(ropa.activa, isTrue, reason: 'se archivó después del cierre');
    expect((r[2] as CategoriaVariable).presupuestoMensualCentavos, const Dinero.pesos(300), reason: 'sin presupuesto en la foto');
    expect(r[3], same(_renta));
  });
}
