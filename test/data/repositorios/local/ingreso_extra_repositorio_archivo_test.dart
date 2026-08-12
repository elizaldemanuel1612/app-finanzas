import 'dart:io';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/repositorios/local/ingreso_extra_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:test/test.dart';

IngresoExtra _ingreso({
  String id = 'ing-1',
  String cicloId = '2026-07',
  DestinoExtra destino = DestinoExtra.apartado,
}) =>
    IngresoExtra(
      id: id,
      cicloId: cicloId,
      etiqueta: 'Bono',
      monto: const Dinero.pesos(15000),
      fecha: DateTime(2026, 7, 15),
      destino: destino,
      estado: EstadoIngreso.activo,
    );

void main() {
  late Directory temp;
  late IngresoExtraRepositorioArchivo repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    repo = IngresoExtraRepositorioArchivo(File('${temp.path}/ingresos.json'));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('archivo inexistente: listarTodos regresa lista vacía', () async {
    expect(await repo.listarTodos(), isEmpty);
  });

  test('guardar y listarTodos regresa lo guardado', () async {
    await repo.guardar(_ingreso());
    final todos = await repo.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.single, _ingreso());
  });

  test('guardar con el mismo id sobrescribe en vez de duplicar (upsert)', () async {
    await repo.guardar(_ingreso());
    await repo.guardar(_ingreso().copyWith(etiqueta: 'Aguinaldo'));

    final todos = await repo.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.single.etiqueta, 'Aguinaldo');
  });

  test('listarPorCiclo filtra por cicloId', () async {
    await repo.guardar(_ingreso(id: 'a', cicloId: '2026-07'));
    await repo.guardar(_ingreso(id: 'b', cicloId: '2026-08'));

    final deJulio = await repo.listarPorCiclo('2026-07');
    expect(deJulio, hasLength(1));
    expect(deJulio.single.id, 'a');
  });

  test('anular marca estado sin borrar físicamente', () async {
    await repo.guardar(_ingreso());
    await repo.anular('ing-1');

    final todos = await repo.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.single.estado, EstadoIngreso.anulado);
  });

  test('anular un id inexistente lanza', () async {
    expect(() => repo.anular('no-existe'), throwsStateError);
  });

  test('los datos sobreviven a una nueva instancia del repositorio (persistencia real)', () async {
    await repo.guardar(_ingreso());
    final otraInstancia = IngresoExtraRepositorioArchivo(File('${temp.path}/ingresos.json'));
    expect(await otraInstancia.listarTodos(), hasLength(1));
  });
}
