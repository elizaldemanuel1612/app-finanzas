import 'dart:io';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/repositorios/local/ajuste_presupuesto_ciclo_repositorio_archivo.dart';
import 'package:app_finanzas/domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import 'package:test/test.dart';

AjustePresupuestoCiclo _ajuste({
  String cicloId = '2026-07',
  String categoriaId = 'cat-super',
  Dinero delta = const Dinero.pesos(100),
}) =>
    AjustePresupuestoCiclo(
      cicloId: cicloId,
      categoriaId: categoriaId,
      deltaCentavos: delta,
      cuando: DateTime(2026, 7, 15),
      dispositivo: 'android-1',
    );

void main() {
  late Directory temp;
  late AjustePresupuestoCicloRepositorioArchivo repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    repo = AjustePresupuestoCicloRepositorioArchivo(
      File('${temp.path}/ajustes_presupuesto_ciclo.json'),
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('archivo inexistente: listarPorCiclo regresa lista vacía', () async {
    expect(await repo.listarPorCiclo('2026-07'), isEmpty);
  });

  test('agregarLote guarda todos los ajustes del lote', () async {
    await repo.agregarLote([
      _ajuste(categoriaId: 'a'),
      _ajuste(categoriaId: 'b'),
    ]);
    final todos = await repo.listarPorCiclo('2026-07');
    expect(todos, hasLength(2));
  });

  test('agregarLote acumula en llamadas sucesivas (append-only, sin upsert)', () async {
    await repo.agregarLote([_ajuste(categoriaId: 'a', delta: const Dinero.pesos(100))]);
    await repo.agregarLote([_ajuste(categoriaId: 'a', delta: const Dinero.pesos(-40))]);

    final todos = await repo.listarPorCiclo('2026-07');
    expect(todos, hasLength(2));
    expect(todos.map((a) => a.deltaCentavos), [const Dinero.pesos(100), const Dinero.pesos(-40)]);
  });

  test('listarPorCiclo filtra por cicloId', () async {
    await repo.agregarLote([
      _ajuste(cicloId: '2026-07'),
      _ajuste(cicloId: '2026-08'),
    ]);

    final deJulio = await repo.listarPorCiclo('2026-07');
    expect(deJulio, hasLength(1));
    expect(deJulio.single.cicloId, '2026-07');
  });

  test('los datos sobreviven a una nueva instancia del repositorio (persistencia real)', () async {
    await repo.agregarLote([_ajuste()]);
    final otraInstancia = AjustePresupuestoCicloRepositorioArchivo(
      File('${temp.path}/ajustes_presupuesto_ciclo.json'),
    );
    expect(await otraInstancia.listarPorCiclo('2026-07'), hasLength(1));
  });
}
