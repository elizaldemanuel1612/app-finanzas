import 'dart:io';

import 'package:app_finanzas/data/repositorios/local/reglas_aprendidas_repositorio_archivo.dart';
import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('listarTodas en un archivo que no existe regresa lista vacía', () async {
    final repo = ReglasAprendidasRepositorioArchivo(File('${temp.path}/reglas.json'));
    expect(await repo.listarTodas(), isEmpty);
  });

  test('guardarTodas y volver a leer regresa las mismas reglas', () async {
    final repo = ReglasAprendidasRepositorioArchivo(File('${temp.path}/reglas.json'));
    const reglas = [
      ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 3),
      ReglaAprendida(patron: 'farmacia guadalajara', categoriaId: 'salud', contador: 1),
    ];
    await repo.guardarTodas(reglas);
    expect(await repo.listarTodas(), reglas);
  });

  test('guardarTodas reemplaza el contenido anterior por completo', () async {
    final repo = ReglasAprendidasRepositorioArchivo(File('${temp.path}/reglas.json'));
    await repo.guardarTodas(const [ReglaAprendida(patron: 'a', categoriaId: 'x', contador: 1)]);
    await repo.guardarTodas(const [ReglaAprendida(patron: 'b', categoriaId: 'y', contador: 1)]);
    final reglas = await repo.listarTodas();
    expect(reglas, hasLength(1));
    expect(reglas.single.patron, 'b');
  });

  test('los datos sobreviven a una nueva instancia del repositorio', () async {
    final archivo = File('${temp.path}/reglas.json');
    await ReglasAprendidasRepositorioArchivo(archivo)
        .guardarTodas(const [ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 2)]);
    final reglas = await ReglasAprendidasRepositorioArchivo(archivo).listarTodas();
    expect(reglas.single.contador, 2);
  });
}
