import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

Movimiento _mov(String clientId, {DateTime? fecha, int pesos = 100}) =>
    (crearMovimiento(
      clientId: clientId,
      fecha: fecha ?? DateTime(2026, 7, 15),
      calculadoraCiclo: const CalculadoraCiclo(12),
      monto: Dinero.pesos(pesos),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'Despensa',
      origenCaptura: OrigenCaptura.manual,
    ) as Exito<Movimiento>)
        .valor;

void main() {
  late Directory temp;
  late MovimientoRepositorioArchivo repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    repo = MovimientoRepositorioArchivo(File('${temp.path}/movimientos.json'));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('guardar y listarTodos regresa lo guardado', () async {
    await repo.guardar(_mov('cliente-1-uuid'));
    final todos = await repo.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.single.clientId, 'cliente-1-uuid');
  });

  test('guardar asigna un id cuando el movimiento no trae uno', () async {
    final guardado = await repo.guardar(_mov('cliente-1-uuid'));
    expect(guardado.id, isNotNull);
  });

  test('guardar con el mismo clientId dos veces no duplica (regla #2)', () async {
    await repo.guardar(_mov('cliente-1-uuid'));
    await repo.guardar(_mov('cliente-1-uuid'));
    expect(await repo.listarTodos(), hasLength(1));
  });

  test('guardar con clientId repetido regresa el que ya existía', () async {
    final primero = await repo.guardar(_mov('cliente-1-uuid', pesos: 100));
    final segundo = await repo.guardar(_mov('cliente-1-uuid', pesos: 999));
    expect(segundo.monto, primero.monto);
  });

  test('listarPorCiclo filtra por cicloId', () async {
    await repo.guardar(_mov('cliente-julio', fecha: DateTime(2026, 7, 15))); // ciclo 2026-07
    await repo.guardar(_mov('cliente-junio', fecha: DateTime(2026, 6, 15))); // ciclo 2026-06

    final julio = await repo.listarPorCiclo('2026-07');
    expect(julio, hasLength(1));
    expect(julio.single.clientId, 'cliente-julio');
  });

  test('listarPorCategoria filtra por categoriaId', () async {
    await repo.guardar(_mov('cliente-super', pesos: 100));
    final movTransporte = _mov('cliente-transporte').copyWith(categoriaId: 'transporte');
    await repo.guardar(movTransporte);

    final deSuper = await repo.listarPorCategoria('super');
    expect(deSuper, hasLength(1));
    expect(deSuper.single.clientId, 'cliente-super');
  });

  test('listarPorCategoria incluye movimientos anulados (no filtra por estado)', () async {
    final guardado = await repo.guardar(_mov('cliente-super'));
    await repo.anular(guardado.id!);

    final deSuper = await repo.listarPorCategoria('super');
    expect(deSuper, hasLength(1));
    expect(deSuper.single.estado, EstadoMovimiento.anulado);
  });

  test('existeClientId', () async {
    await repo.guardar(_mov('cliente-1-uuid'));
    expect(await repo.existeClientId('cliente-1-uuid'), isTrue);
    expect(await repo.existeClientId('otro'), isFalse);
  });

  test('actualizar reemplaza el movimiento existente', () async {
    final guardado = await repo.guardar(_mov('cliente-1-uuid', pesos: 100));
    final editado = guardado.copyWith(descripcion: 'Despensa y limpieza');
    await repo.actualizar(editado);

    final todos = await repo.listarTodos();
    expect(todos.single.descripcion, 'Despensa y limpieza');
  });

  test('actualizar un movimiento inexistente lanza', () async {
    final fantasma = _mov('cliente-1-uuid').copyWith(id: 'no-existe');
    expect(() => repo.actualizar(fantasma), throwsA(isA<StateError>()));
  });

  test('anular marca el movimiento como anulado sin borrarlo (regla #3)', () async {
    final guardado = await repo.guardar(_mov('cliente-1-uuid'));
    await repo.anular(guardado.id!);

    final todos = await repo.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.single.estado, EstadoMovimiento.anulado);
  });

  test('anular un movimiento inexistente lanza', () async {
    expect(() => repo.anular('no-existe'), throwsA(isA<StateError>()));
  });

  test('los datos sobreviven a una nueva instancia del repositorio (persistencia real)', () async {
    await repo.guardar(_mov('cliente-1-uuid'));
    final otraInstancia =
        MovimientoRepositorioArchivo(File('${temp.path}/movimientos.json'));
    expect(await otraInstancia.listarTodos(), hasLength(1));
  });
}
