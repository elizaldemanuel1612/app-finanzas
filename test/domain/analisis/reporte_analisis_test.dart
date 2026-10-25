import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/reporte_analisis.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

Ciclo _ciclo(String id, DateTime inicio, DateTime fin) =>
    Ciclo(id: id, fechaInicio: inicio, fechaFin: fin, etiqueta: id, estado: EstadoCiclo.abierto);

final _oct = _ciclo('2026-10', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
final _sep = _ciclo('2026-09', DateTime(2026, 9, 1), DateTime(2026, 9, 30));

const _vivienda = CategoriaFija(
  id: 'vivienda',
  nombre: 'Vivienda',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: Dinero.pesos(5000),
  diaDelCiclo: 1,
);
CategoriaVariable _var(String id, int pesos, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );
final _super = _var('super', 4000);
final _salidas = _var('salidas', 2000);
final _viejo = _var('viejo', 900, activa: false);
final _categorias = <Categoria>[_vivienda, _super, _salidas, _viejo];

var _n = 0;
Movimiento _mov(
  DateTime fecha,
  int pesos,
  String categoria, {
  String ciclo = '2026-10',
  MedioPago medio = MedioPago.tarjeta,
  String descripcion = '',
  EstadoMovimiento estado = EstadoMovimiento.activo,
  int centavos = 0,
}) =>
    Movimiento(
      clientId: 'm${_n++}',
      fecha: fecha,
      cicloId: ciclo,
      periodoNatural: '${fecha.year}-${fecha.month}',
      monto: Dinero(pesos * 100 + centavos),
      categoriaId: categoria,
      medio: medio,
      descripcion: descripcion,
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

ReporteAnalisis _reporte(List<Movimiento> ms, {DateTime? hoy, Ciclo? anterior}) => calcularReporteAnalisis(
      ciclo: _oct,
      cicloAnterior: anterior,
      movimientos: ms,
      categorias: _categorias,
      hoy: hoy ?? DateTime(2026, 10, 20, 18),
    );

void main() {
  test('totales, proyección lineal de variables y presupuestos activos', () {
    final r = _reporte([
      _mov(DateTime(2026, 10, 1), 5000, 'vivienda'),
      _mov(DateTime(2026, 10, 2), 1000, 'super'),
      _mov(DateTime(2026, 10, 3), 1000, 'salidas', medio: MedioPago.efectivo),
      _mov(DateTime(2026, 10, 4), 999, 'super', estado: EstadoMovimiento.anulado),
      _mov(DateTime(2026, 10, 4), 999, 'no-existe'),
    ]);
    expect(r.diaDelCiclo, 20);
    expect(r.diasDelCiclo, 31);
    expect(r.diasRestantes, 11);
    expect(r.gastado, const Dinero.pesos(7000));
    expect(r.gastadoVariables, const Dinero.pesos(2000));
    expect(r.gastadoFijas, const Dinero.pesos(5000));
    expect(r.presupuestoVariables, const Dinero.pesos(6000), reason: 'sin la archivada');
    expect(r.presupuestoFijas, const Dinero.pesos(5000));
    expect(r.promedioDiarioVariables, const Dinero.pesos(100));
    expect(r.proyeccionVariables, const Dinero.pesos(3100));
    expect(r.conTarjeta, const Dinero.pesos(6000));
    expect(r.enEfectivo, const Dinero.pesos(1000));
    expect(r.sinMovimientos, isFalse);
  });

  test('¿En qué se va?: de mayor a menor, porcentaje redondeado y presupuesto', () {
    final r = _reporte([
      _mov(DateTime(2026, 10, 1), 2000, 'vivienda'),
      _mov(DateTime(2026, 10, 2), 600, 'super'),
      _mov(DateTime(2026, 10, 3), 400, 'super'),
      _mov(DateTime(2026, 10, 3), 1, 'salidas'),
    ]);
    expect(r.porCategoria.map((g) => g.categoria.id), ['vivienda', 'super', 'salidas']);
    expect(r.porCategoria.map((g) => g.porcentaje), [67, 33, 0]);
    expect(r.porCategoria[1].conteo, 2);
    expect(r.porCategoria[0].presupuesto, const Dinero.pesos(5000));
    expect(r.porCategoria[1].presupuesto, const Dinero.pesos(4000));
  });

  test('un gasto en cero no divide entre cero', () {
    final r = _reporte([_mov(DateTime(2026, 10, 2), 0, 'super')]);
    expect(r.porCategoria.single.porcentaje, 0);
    expect(r.sinMovimientos, isTrue);
  });

  test('día del ciclo acotado y acumulado de variables por día', () {
    final antes = _reporte([], hoy: DateTime(2026, 9, 20));
    expect(antes.diaDelCiclo, 1);
    final despues = _reporte([], hoy: DateTime(2026, 11, 5));
    expect(despues.diaDelCiclo, 31);
    expect(despues.diasRestantes, 0);

    final r = _reporte([
      _mov(DateTime(2026, 10, 1), 100, 'super'),
      _mov(DateTime(2026, 10, 3), 50, 'salidas'),
      _mov(DateTime(2026, 10, 3), 999, 'vivienda'),
      _mov(DateTime(2026, 10, 25), 70, 'super'),
    ], hoy: DateTime(2026, 10, 4));
    expect(r.acumuladoVariablesPorDia, [
      const Dinero.pesos(100),
      const Dinero.pesos(100),
      const Dinero.pesos(150),
      const Dinero.pesos(150),
    ]);
  });

  test('contra el ciclo pasado: mismos días transcurridos', () {
    final ms = [
      _mov(DateTime(2026, 10, 5), 500, 'super'),
      _mov(DateTime(2026, 9, 5), 300, 'super', ciclo: '2026-09'),
      _mov(DateTime(2026, 9, 6), 500, 'salidas', ciclo: '2026-09'),
      _mov(DateTime(2026, 9, 7), 500, 'vivienda', ciclo: '2026-09'),
      _mov(DateTime(2026, 9, 25), 9999, 'super', ciclo: '2026-09'),
    ];
    final r = _reporte(ms, hoy: DateTime(2026, 10, 10), anterior: _sep);
    expect(r.variablesAnteriorMismoDia, const Dinero.pesos(800), reason: 'el día 25 queda fuera');
    expect(r.contraAnterior.map((c) => c.categoria.id), ['super', 'salidas', 'vivienda']);
    expect(r.contraAnterior.first.diferencia, const Dinero.pesos(200));

    expect(_reporte(ms, hoy: DateTime(2026, 10, 10)).variablesAnteriorMismoDia, isNull);
    final sinDatos = _reporte([_mov(DateTime(2026, 10, 5), 1, 'super')], anterior: _sep);
    expect(sinDatos.variablesAnteriorMismoDia, isNull);
    expect(sinDatos.contraAnterior, isEmpty);
  });

  test('últimos ciclos: hasta 6, sin futuros, el actual aunque no tenga gastos', () {
    final ms = [
      for (var mes = 2; mes <= 9; mes++)
        _mov(DateTime(2026, mes, 3), mes * 10, 'super', ciclo: '2026-${mes.toString().padLeft(2, '0')}'),
      _mov(DateTime(2026, 11, 3), 1, 'super', ciclo: '2026-11'),
    ];
    final r = _reporte(ms);
    expect(r.ultimosCiclos.map((c) => c.cicloId), ['2026-05', '2026-06', '2026-07', '2026-08', '2026-09', '2026-10']);
    expect(r.ultimosCiclos.first.etiqueta, 'May');
    expect(r.ultimosCiclos.first.total, const Dinero.pesos(50));
    expect(r.ultimosCiclos.last.enCurso, isTrue);
    expect(r.ultimosCiclos.last.total, const Dinero.cero());

    final raro = _reporte([_mov(DateTime(2026, 1, 3), 5, 'super', ciclo: '0000-13')]);
    expect(raro.ultimosCiclos.first.etiqueta, '0000-13');
  });

  test('¿qué día gastas más?: promedio por día de la semana en 90 días', () {
    // Lunes 5 y 12 de oct: 100 y 300 → promedio de lunes 200 (2 lunes).
    final r = _reporte([
      _mov(DateTime(2026, 10, 5), 100, 'super'),
      _mov(DateTime(2026, 10, 12), 300, 'super'),
      _mov(DateTime(2026, 10, 12), 999, 'vivienda'),
      _mov(DateTime(2026, 6, 1), 999, 'super', ciclo: '2026-06'),
      _mov(DateTime(2026, 10, 30), 999, 'super'),
    ], hoy: DateTime(2026, 10, 18));
    expect(r.diasConDatos, 14);
    expect(r.promedioPorDiaSemana[0], const Dinero.pesos(200));
    expect(r.promedioPorDiaSemana[1], const Dinero.cero());

    final vacio = _reporte([]);
    expect(vacio.diasConDatos, 0);
    expect(vacio.promedioPorDiaSemana.every((d) => d.esCero), isTrue);
  });

  test('dónde más gastas: agrupa por texto normalizado, top 5, sin vacíos', () {
    final r = _reporte([
      _mov(DateTime(2026, 10, 2), 100, 'super', descripcion: 'Oxxo'),
      _mov(DateTime(2026, 10, 3), 50, 'super', descripcion: ' OXXO '),
      for (var i = 0; i < 6; i++) _mov(DateTime(2026, 10, 4), 10 + i, 'salidas', descripcion: 'lugar $i'),
      _mov(DateTime(2026, 10, 4), 999, 'salidas'),
      _mov(DateTime(2026, 10, 1), 5000, 'vivienda', descripcion: 'Renta'),
    ]);
    expect(r.dondeMasGastas, hasLength(5));
    expect(r.dondeMasGastas.any((d) => d.descripcion == 'Renta'), isFalse, reason: 'las fijas no entran');
    expect(r.dondeMasGastas.first.descripcion, 'Oxxo');
    expect(r.dondeMasGastas.first.total, const Dinero.pesos(150));
    expect(r.dondeMasGastas.first.conteo, 2);
  });

  test('gastos pequeños: variables de \$150 o menos', () {
    final r = _reporte([
      _mov(DateTime(2026, 10, 2), 150, 'super'),
      _mov(DateTime(2026, 10, 2), 150, 'super', centavos: 1),
      _mov(DateTime(2026, 10, 2), 20, 'vivienda'),
    ]);
    expect(r.gastosPequenos, 1);
    expect(r.totalGastosPequenos, const Dinero.pesos(150));
  });
}
