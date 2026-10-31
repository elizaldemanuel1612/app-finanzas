import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/rollups/orden_categorias.dart';
import 'package:app_finanzas/domain/rollups/rollup.dart';
import 'package:test/test.dart';

CategoriaVariable _cat(String id) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: const Dinero.pesos(100),
    );

Rollup _rollup(String id, int gastado, int? presupuesto) => Rollup(
      categoriaId: id,
      cicloId: 'c',
      totalCentavos: Dinero.pesos(gastado),
      conteoMovimientos: 1,
      presupuestoCentavos: presupuesto == null ? null : Dinero.pesos(presupuesto),
      ultimaActualizacion: DateTime(2026),
    );

List<String> _ids(List<Categoria> c) => [for (final x in c) x.id];

void main() {
  final categorias = [_cat('chica'), _cat('grande'), _cat('sin-gasto')];
  final rollups = {
    'chica': _rollup('chica', 90, 100), // 90 %, $90
    'grande': _rollup('grande', 500, 1000), // 50 %, $500
  };

  test('por presupuesto consumido, de mayor a menor', () {
    expect(_ids(ordenarCategorias(categorias, rollups, OrdenCategorias.porcentajeUsado)),
        ['chica', 'grande', 'sin-gasto']);
  });

  test('por dinero gastado, de mayor a menor', () {
    expect(_ids(ordenarCategorias(categorias, rollups, OrdenCategorias.dineroGastado)),
        ['grande', 'chica', 'sin-gasto']);
  });

  test('no modifica la lista original', () {
    final original = [_cat('a'), _cat('b')];
    ordenarCategorias(original, {'b': _rollup('b', 1, 10)}, OrdenCategorias.dineroGastado);
    expect(_ids(original), ['a', 'b']);
  });

  test('gastado sin presupuesto va primero al ordenar por consumido', () {
    final r = {'chica': _rollup('chica', 1, null), 'grande': _rollup('grande', 99, 100)};
    expect(_ids(ordenarCategorias(categorias, r, OrdenCategorias.porcentajeUsado)).first, 'chica');
  });

  test('sin presupuesto ni gasto cuenta como cero', () {
    final r = {'chica': _rollup('chica', 0, 0), 'grande': _rollup('grande', 1, 100)};
    expect(_ids(ordenarCategorias(categorias, r, OrdenCategorias.porcentajeUsado)).first, 'grande');
  });

  test('empate: decide el otro criterio y luego el nombre', () {
    final r = {
      'chica': _rollup('chica', 10, 100), // mismo 10 %, menos dinero
      'grande': _rollup('grande', 100, 1000),
    };
    expect(_ids(ordenarCategorias(categorias, r, OrdenCategorias.porcentajeUsado)).take(2), ['grande', 'chica']);

    final igual = {'chica': _rollup('chica', 50, 100), 'grande': _rollup('grande', 50, 1000)};
    expect(_ids(ordenarCategorias(categorias, igual, OrdenCategorias.dineroGastado)).take(2), ['chica', 'grande']);

    expect(_ids(ordenarCategorias([_cat('b'), _cat('a')], const {}, OrdenCategorias.dineroGastado)), ['a', 'b']);
  });
}
