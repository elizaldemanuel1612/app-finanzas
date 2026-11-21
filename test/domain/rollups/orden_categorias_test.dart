import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
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

  test('sin presupuesto va al final al ordenar por consumido: no se juzga (spec §7.3.6)', () {
    final r = {'chica': _rollup('chica', 1, null), 'grande': _rollup('grande', 99, 100)};
    final orden = _ids(ordenarCategorias(categorias, r, OrdenCategorias.porcentajeUsado)).toList();
    expect(orden.first, 'grande');
    expect(orden.indexOf('chica'), greaterThan(orden.indexOf('grande')));
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

  group('ordenarPorUso', () {
    CategoriaVariable variable(String id, int presupuesto) => CategoriaVariable(
          id: id,
          nombre: id,
          emoji: '🛒',
          activa: true,
          esNecesaria: false,
          presupuestoMensualCentavos: Dinero.pesos(presupuesto),
        );
    const fija = CategoriaFija(
      id: 'renta',
      nombre: 'renta',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(500),
      diaDelCiclo: 1,
    );
    Movimiento gasto(String categoriaId, int n, [EstadoMovimiento estado = EstadoMovimiento.activo]) => Movimiento(
          clientId: '$categoriaId-$n',
          fecha: DateTime(2026, 10, 1),
          cicloId: 'c',
          periodoNatural: '2026-10',
          monto: const Dinero.pesos(1),
          categoriaId: categoriaId,
          medio: MedioPago.tarjeta,
          descripcion: 'x',
          estado: estado,
          origenCaptura: OrigenCaptura.manual,
        );
    final lista = <Categoria>[variable('chica', 100), fija, variable('grande', 900)];

    test('sin historial: de mayor a menor presupuesto, contando el monto de las fijas', () {
      expect(_ids(ordenarPorUso(lista, const [])), ['grande', 'renta', 'chica']);
    });

    test('con historial: la más usada primero, aunque tenga menos presupuesto', () {
      final usados = [gasto('chica', 1), gasto('chica', 2), gasto('renta', 1)];
      expect(_ids(ordenarPorUso(lista, usados)), ['chica', 'renta', 'grande']);
    });

    test('lo anulado y lo pendiente no cuentan como uso', () {
      final usados = [gasto('chica', 1, EstadoMovimiento.anulado), gasto('chica', 2, EstadoMovimiento.propuesto)];
      expect(_ids(ordenarPorUso(lista, usados)).first, 'grande');
    });

    test('empate de uso y presupuesto: por nombre, sin tocar la lista original', () {
      final original = <Categoria>[variable('b', 1), variable('a', 1)];
      expect(_ids(ordenarPorUso(original, const [])), ['a', 'b']);
      expect(_ids(original), ['b', 'a']);
    });
  });

  test('presupuesto de Inicio: lo que necesita atención va primero', () {
    final cats = [_cat('bien'), _cat('rapida'), _cat('pasada'), _cat('muy-pasada'), _cat('a-bien'), _cat('nada')];
    final r = {
      'bien': _rollup('bien', 30, 100), // 30 % a mitad de ciclo
      'a-bien': _rollup('a-bien', 30, 100), // empate: por nombre
      'rapida': _rollup('rapida', 80, 100), // 80 % > 50 % × 1.15
      'pasada': _rollup('pasada', 110, 100),
      'muy-pasada': _rollup('muy-pasada', 150, 100),
    };
    expect(_ids(ordenarPorAtencion(cats, r, avanceCiclo: 0.5)), ['muy-pasada', 'pasada', 'rapida', 'a-bien', 'bien', 'nada']);
  });

  test('sin presupuesto van al final, de mayor a menor gasto (spec §7.3.6)', () {
    final cats = [_cat('cafe'), _cat('super'), _cat('bien'), _cat('nada')];
    final r = {
      'cafe': _rollup('cafe', 200, 0),
      'super': _rollup('super', 900, 0),
      'bien': _rollup('bien', 10, 100),
    };
    expect(_ids(ordenarPorAtencion(cats, r, avanceCiclo: 0.5)), ['bien', 'nada', 'super', 'cafe']);
  });

  group('ordenarPresupuesto (spec §5.6.4)', () {
    CategoriaVariable con(String id, String nombre) => CategoriaVariable(
          id: id,
          nombre: nombre,
          emoji: '🛒',
          activa: true,
          esNecesaria: false,
          presupuestoMensualCentavos: const Dinero.pesos(100),
        );
    final cats = [con('s', 'Súper'), con('a', 'auto'), con('e', 'Éxito'), con('b', 'Auto')];
    final r = {'s': _rollup('s', 50, 100), 'a': _rollup('a', 120, 100), 'e': _rollup('e', 50, 100)};
    List<String> orden(OrdenPresupuesto o, [List<String> propio = const []]) =>
        _ids(ordenarPresupuesto(cats, r, orden: o, avanceCiclo: 0.5, ordenPropio: propio));

    test('atención es el de siempre', () {
      expect(orden(OrdenPresupuesto.atencion), _ids(ordenarPorAtencion(cats, r, avanceCiclo: 0.5)));
      expect(orden(OrdenPresupuesto.atencion).first, 'a');
    });

    test('por nombre, sin acentos ni mayúsculas; empate por id', () {
      expect(orden(OrdenPresupuesto.nombre), ['a', 'b', 'e', 's']);
    });

    test('lo más gastado primero; empate por nombre', () {
      expect(orden(OrdenPresupuesto.masGastado), ['a', 'e', 's', 'b']);
    });

    test('mi orden: lo nuevo al final por nombre, lo que ya no existe se ignora', () {
      expect(orden(OrdenPresupuesto.propio, ['s', 'borrada', 'e']), ['s', 'e', 'a', 'b']);
      expect(orden(OrdenPresupuesto.propio, ['b', 'a', 'e', 's']), ['b', 'a', 'e', 's']);
      expect(orden(OrdenPresupuesto.propio), ['a', 'b', 'e', 's']);
    });

    test('el nombre guardado se lee; uno desconocido o ausente es atención', () {
      expect(OrdenPresupuesto.deNombre('propio'), OrdenPresupuesto.propio);
      expect(OrdenPresupuesto.deNombre('otro'), OrdenPresupuesto.atencion);
      expect(OrdenPresupuesto.deNombre(null), OrdenPresupuesto.atencion);
    });
  });
}
