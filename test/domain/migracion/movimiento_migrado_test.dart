import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/migracion/movimiento_migrado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

void main() {
  const calculadora = CalculadoraCiclo(12);

  test('un HIST-#### válido nace activo con clientId = idOrigen', () {
    final r = crearMovimientoMigrado(
      idOrigen: 'HIST-0001',
      fecha: DateTime(2026, 5, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(500),
      categoriaId: 'super',
      medio: MedioPago.efectivo,
      descripcion: 'Compra de mayo',
    );

    expect(r.esExito, isTrue);
    final m = (r as Exito<Movimiento>).valor;
    expect(m.idOrigen, 'HIST-0001');
    expect(m.clientId, 'HIST-0001');
    expect(m.estado, EstadoMovimiento.activo);
    expect(m.origenCaptura, OrigenCaptura.migracion);
    expect(m.granularidad, isNull);
  });

  test('idOrigen vacío falla', () {
    final r = crearMovimientoMigrado(
      idOrigen: '',
      fecha: DateTime(2026, 5, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero(100),
      categoriaId: 'super',
      medio: MedioPago.efectivo,
      descripcion: 'x',
    );
    expect(r.esFalla, isTrue);
  });

  test('monto cero falla', () {
    final r = crearMovimientoMigrado(
      idOrigen: 'HIST-0002',
      fecha: DateTime(2026, 5, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.cero(),
      categoriaId: 'super',
      medio: MedioPago.efectivo,
      descripcion: 'x',
    );
    expect(r.esFalla, isTrue);
  });

  test('marca agregado_diario cuando se indica (mayo/junio históricos)', () {
    final r = crearMovimientoMigrado(
      idOrigen: 'HIST-0003',
      fecha: DateTime(2026, 5, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(1200),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'Total diario de mayo',
      granularidadAgregadaDiaria: true,
    );
    expect(
      (r as Exito<Movimiento>).valor.granularidad,
      Granularidad.agregadoDiario,
    );
  });

  test('el cicloId se calcula igual que para captura en vivo', () {
    final fecha = DateTime(2026, 5, 15);
    final r = crearMovimientoMigrado(
      idOrigen: 'HIST-0004',
      fecha: fecha,
      calculadoraCiclo: calculadora,
      monto: const Dinero(100),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'x',
    );
    expect(
      (r as Exito<Movimiento>).valor.cicloId,
      calculadora.calcularPara(fecha).id,
    );
  });
}
