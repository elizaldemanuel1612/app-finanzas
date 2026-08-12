import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/repositorios/local/ciclo_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);
final _cicloAbierto = _calculadora.calcularPara(DateTime(2026, 7, 15));

SnapshotCiclo _snapshot() => SnapshotCiclo(
      cicloId: _cicloAbierto.id,
      fechaCierre: DateTime(2026, 8, 12),
      ingresoTotal: const Dinero.pesos(87000),
      metaApartado: const Dinero.pesos(34800),
      totalGastado: const Dinero.pesos(42674),
      renglones: const [],
    );

void main() {
  late Directory temp;
  late CicloRepositorioArchivo repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    repo = CicloRepositorioArchivo(File('${temp.path}/ciclos.json'));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('buscarPorId regresa null cuando el ciclo nunca se guardó', () async {
    expect(await repo.buscarPorId('2026-07'), isNull);
  });

  test('guardar y buscarPorId regresa lo guardado', () async {
    final cerrado = _cicloAbierto.cerrar().valorOLanza;
    await repo.guardar(CicloGuardado(ciclo: cerrado, snapshot: _snapshot()));

    final encontrado = await repo.buscarPorId(_cicloAbierto.id);
    expect(encontrado, isNotNull);
    expect(encontrado!.ciclo.estado, EstadoCiclo.cerrado);
    expect(encontrado.snapshot, _snapshot());
  });

  test('guardar con el mismo id sobrescribe en vez de duplicar', () async {
    final cerrado = _cicloAbierto.cerrar().valorOLanza;
    await repo.guardar(CicloGuardado(ciclo: cerrado, snapshot: _snapshot()));

    final reabierto = cerrado.reabrir().valorOLanza;
    await repo.guardar(CicloGuardado(ciclo: reabierto, snapshot: _snapshot()));

    final todos = await repo.listarTodos();
    expect(todos, hasLength(1));
    expect(todos.single.ciclo.estado, EstadoCiclo.abierto);
  });

  test('listarTodos regresa todos los ciclos guardados', () async {
    final julio = _calculadora.calcularPara(DateTime(2026, 7, 15));
    final junio = _calculadora.calcularPara(DateTime(2026, 6, 15));
    await repo.guardar(CicloGuardado(ciclo: julio.cerrar().valorOLanza, snapshot: _snapshot()));
    await repo.guardar(CicloGuardado(ciclo: junio.cerrar().valorOLanza, snapshot: _snapshot()));

    expect(await repo.listarTodos(), hasLength(2));
  });

  test('un ciclo guardado sin snapshot conserva null', () async {
    await repo.guardar(CicloGuardado(ciclo: _cicloAbierto, snapshot: null));
    final encontrado = await repo.buscarPorId(_cicloAbierto.id);
    expect(encontrado!.snapshot, isNull);
  });

  test('los datos sobreviven a una nueva instancia del repositorio (persistencia real)', () async {
    final cerrado = _cicloAbierto.cerrar().valorOLanza;
    await repo.guardar(CicloGuardado(ciclo: cerrado, snapshot: _snapshot()));

    final otraInstancia = CicloRepositorioArchivo(File('${temp.path}/ciclos.json'));
    expect(await otraInstancia.listarTodos(), hasLength(1));
  });
}
