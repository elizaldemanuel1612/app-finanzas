import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import 'package:app_finanzas/domain/presupuesto/traslado_sobrante.dart';
import 'package:test/test.dart';

// addendum-v3-ajuste-y-ux.md §2.5.2 (2026-11-15).

CategoriaVariable _var(String id, int pesos, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
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

var _n = 0;
Movimiento _mov(String categoria, int pesos, {String ciclo = 'oct', EstadoMovimiento estado = EstadoMovimiento.activo}) =>
    Movimiento(
      clientId: 'm${_n++}',
      fecha: DateTime(2026, 10, 10),
      cicloId: ciclo,
      periodoNatural: '2026-10',
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: MedioPago.tarjeta,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

final _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(30000));

void main() {
  final categorias = <Categoria>[_renta, _var('auto', 2000), _var('super', 4000), _var('salidas', 1000), _var('vieja', 900, activa: false)];

  test('solo variables activas con sobrante, con los ajustes del ciclo y de mayor a menor', () {
    final s = sobrantesDelCiclo(
      categorias: categorias,
      ajustesDelCiclo: [
        AjustePresupuestoCiclo(
          cicloId: 'oct',
          categoriaId: 'auto',
          deltaCentavos: Dinero.pesos(500),
          cuando: DateTime(2026, 10, 5),
          dispositivo: 'app',
        ),
      ],
      movimientos: [
        _mov('renta', 4000), // fija: no entra aunque "sobre"
        _mov('auto', 1500),
        _mov('super', 3700),
        _mov('salidas', 1200), // se pasó: no hay sobrante
        _mov('super', 999, estado: EstadoMovimiento.anulado),
        _mov('super', 300, ciclo: 'nov'), // otro ciclo
      ],
      cicloId: 'oct',
    );
    expect([for (final x in s) (x.categoria.id, x.sobrante.centavos ~/ 100)], [('auto', 1000), ('super', 300)]);
  });

  test('sin gastos en el ciclo no hay nada que ofrecer', () {
    expect(sobrantesDelCiclo(categorias: categorias, ajustesDelCiclo: const [], movimientos: const [], cicloId: 'oct'), isEmpty);
  });

  test('se pregunta una vez por ciclo y vienen marcadas las que se pidió recordar', () {
    final s = [
      SobranteCategoria(categoria: _var('auto', 2000), sobrante: Dinero.pesos(1000)),
      SobranteCategoria(categoria: _var('super', 4000), sobrante: Dinero.pesos(300)),
    ];
    expect(debePreguntarTraslado(_perfil, 'nov', s), isTrue);
    expect(debePreguntarTraslado(_perfil, 'nov', const []), isFalse);
    final decidido = perfilTrasDecidir(_perfil, 'nov', recordar: {'super', 'auto'});
    expect(debePreguntarTraslado(decidido, 'nov', s), isFalse);
    expect(debePreguntarTraslado(decidido, 'dic', s), isTrue);
    expect(decidido.trasladarSiempre, ['auto', 'super']);
    expect(trasladoPreseleccionado(decidido, [s.last]), {'super'});
    // Sin "recordar", se conserva lo que ya estaba.
    expect(perfilTrasDecidir(decidido, 'dic').trasladarSiempre, ['auto', 'super']);
    expect(trasladoPreseleccionado(_perfil, s), isEmpty);
  });

  test('los ajustes son deltas positivos solo para el ciclo nuevo', () {
    final a = ajustesDeTraslado(
      [SobranteCategoria(categoria: _var('auto', 2000), sobrante: Dinero.pesos(1000))],
      cicloNuevoId: 'nov',
      ahora: DateTime(2026, 11, 1),
    );
    expect(a.single.cicloId, 'nov');
    expect(a.single.categoriaId, 'auto');
    expect(a.single.deltaCentavos, Dinero.pesos(1000));
    expect(a.single.dispositivo, 'traslado');
  });

  test('el perfil guarda la decisión en JSON', () {
    final p = perfilTrasDecidir(_perfil, 'nov', recordar: {'auto'});
    final ida = Perfil.fromJson(p.toJson());
    expect(ida, p);
    expect(ida.hashCode, p.hashCode);
    expect(_perfil.toJson().containsKey('trasladarSiempre'), isFalse);
    expect(Perfil.fromJson(_perfil.toJson()), _perfil);
    expect(p == _perfil, isFalse);
  });
}
