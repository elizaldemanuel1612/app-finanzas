import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/pronostico/historico_desde_movimientos.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_del_ciclo.dart';
import 'package:test/test.dart';

final _nov = Ciclo(
  id: '2026-11',
  fechaInicio: DateTime(2026, 11, 1),
  fechaFin: DateTime(2026, 11, 30),
  etiqueta: 'Nov',
  estado: EstadoCiclo.abierto,
);

CategoriaVariable _var(String id, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
      presupuestoMensualCentavos: const Dinero.pesos(3000),
    );

var _n = 0;
Movimiento _gasto(String categoria, int pesos, DateTime fecha, {String ciclo = '2026-11', bool anulado = false}) =>
    Movimiento(
      clientId: 'movimiento-${_n++}',
      fecha: fecha,
      cicloId: ciclo,
      periodoNatural: '${fecha.year}-${fecha.month}',
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: MedioPago.tarjeta,
      descripcion: '',
      estado: anulado ? EstadoMovimiento.anulado : EstadoMovimiento.activo,
      origenCaptura: OrigenCaptura.manual,
    );

void main() {
  test('una por variable activa (o archivada con gasto), con el P50 del MPC', () {
    final hoy = DateTime(2026, 11, 14, 12);
    final movimientos = [
      _gasto('super', 1200, DateTime(2026, 11, 3)),
      _gasto('super', 500, DateTime(2026, 11, 4), anulado: true),
      _gasto('super', 900, DateTime(2026, 10, 3), ciclo: '2026-10'),
      _gasto('vieja', 100, DateTime(2026, 11, 5)),
    ];
    const renta = CategoriaFija(
      id: 'renta',
      nombre: 'renta',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(5000),
      diaDelCiclo: 1,
    );
    final estados = estadosDeVariables(
      categorias: [_var('super'), _var('salidas'), _var('vieja', activa: false), _var('olvidada', activa: false), renta],
      movimientos: movimientos,
      ciclo: _nov,
      hoy: hoy,
    );
    expect(estados.map((e) => e.categoria.id), ['super', 'salidas', 'vieja']);
    expect(estados.first.gastado, const Dinero.pesos(1200));
    expect(estados[1].gastado, const Dinero.cero());
    for (final e in estados) {
      final p50 = pronosticoDeCategoria(categoria: e.categoria, todos: movimientos, ciclo: _nov, hoy: hoy).pronosticoP50;
      expect(e.proyeccion, p50 < e.gastado ? e.gastado : p50);
      expect(e.proyeccion >= e.gastado, isTrue);
    }
    expect(proyeccionTotal(estados), Dinero.suma(estados.map((e) => e.proyeccion)));
  });

  test('el cierre estimado nunca queda abajo de lo ya gastado', () {
    // Ciclo ya terminado: lo gastado es el cierre.
    final estados = estadosDeVariables(
      categorias: [_var('super')],
      movimientos: [_gasto('super', 5000, DateTime(2026, 11, 3))],
      ciclo: _nov,
      hoy: DateTime(2026, 12, 20),
    );
    expect(estados.single.proyeccion >= const Dinero.pesos(5000), isTrue);
  });
}
