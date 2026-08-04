import 'dart:io';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/repositorios/local/perfil_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late PerfilRepositorioArchivo repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    repo = PerfilRepositorioArchivo(File('${temp.path}/perfil.json'));
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('obtener sin haber guardado nunca regresa null', () async {
    expect(await repo.obtener(), isNull);
  });

  test('guardar y obtener hace un viaje redondo exacto', () async {
    const perfil = Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(87000));
    await repo.guardar(perfil);
    expect(await repo.obtener(), perfil);
  });

  test('guardar dos veces sobreescribe, no acumula', () async {
    await repo.guardar(const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(87000)));
    await repo.guardar(const Perfil(diaCorte: 5, ingresoBaseMensual: Dinero.pesos(90000)));
    expect((await repo.obtener())?.diaCorte, 5);
  });
}
