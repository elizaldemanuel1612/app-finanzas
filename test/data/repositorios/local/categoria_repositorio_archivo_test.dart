import 'dart:io';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/repositorios/local/categoria_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:test/test.dart';

CategoriaFija _fija(String id, {bool activa = true}) => CategoriaFija(
      id: id,
      nombre: id,
      emoji: '🏠',
      activa: activa,
      esNecesaria: true,
      montoFijoCentavos: const Dinero.pesos(1000),
      diaDelCiclo: 1,
    );

void main() {
  late Directory temp;
  late CategoriaRepositorioArchivo repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    repo = CategoriaRepositorioArchivo(File('${temp.path}/categorias.json'));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('guardar y listarTodas', () async {
    await repo.guardar(_fija('vivienda'));
    expect(await repo.listarTodas(), hasLength(1));
  });

  test('guardar con el mismo id actualiza en vez de duplicar', () async {
    await repo.guardar(_fija('vivienda'));
    await repo.guardar(_fija('vivienda', activa: false));
    final todas = await repo.listarTodas();
    expect(todas, hasLength(1));
    expect(todas.single.activa, isFalse);
  });

  test('listarActivas excluye las desactivadas', () async {
    await repo.guardar(_fija('vivienda'));
    await repo.guardar(_fija('gimnasio', activa: false));
    final activas = await repo.listarActivas();
    expect(activas.map((c) => c.id), ['vivienda']);
  });

  test('buscarPorId encuentra la categoría', () async {
    await repo.guardar(_fija('vivienda'));
    expect((await repo.buscarPorId('vivienda'))?.id, 'vivienda');
  });

  test('buscarPorId regresa null si no existe', () async {
    expect(await repo.buscarPorId('no-existe'), isNull);
  });

  test('eliminar borra la categoría por completo', () async {
    await repo.guardar(_fija('vivienda'));
    await repo.guardar(_fija('gimnasio'));
    await repo.eliminar('vivienda');
    final todas = await repo.listarTodas();
    expect(todas.map((c) => c.id), ['gimnasio']);
  });

  test('eliminar un id que no existe no falla, solo no cambia nada', () async {
    await repo.guardar(_fija('vivienda'));
    await repo.eliminar('no-existe');
    expect(await repo.listarTodas(), hasLength(1));
  });
}
