import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/data/repositorios/local/objetivo_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/domain/sincronizacion/fusion.dart';
import 'package:test/test.dart';

void main() {
  test('guarda en orden, reemplaza por id y conserva lo archivado', () async {
    final repo = ObjetivoRepositorioArchivo.sobre(ArchivoTextoMemoria());
    expect(await repo.listarTodos(), isEmpty);
    Objetivo obj(String id) => Objetivo(
          id: id,
          nombre: id,
          emoji: '🎯',
          monto: const Dinero.pesos(1000),
          cuentaId: 'cetes',
          creado: DateTime(2026, 11, 14),
        );
    await repo.guardar(obj('fondo'));
    await repo.guardar(obj('viaje'));
    await repo.guardar(obj('fondo').copyWith(nombre: 'Fondo de emergencia', activo: false));
    final todos = await repo.listarTodos();
    expect(todos.map((o) => o.id), ['fondo', 'viaje']);
    expect(todos.first.nombre, 'Fondo de emergencia');
    expect(todos.first.activo, isFalse);
  });

  test('objetivos.json es parte de los datos de la app y se respalda por id', () {
    expect(AlmacenLocal.nombresDeArchivo, contains('objetivos.json'));
    expect(claveDeArchivo('objetivos.json')!({'id': 'fondo'}), 'fondo');
  });
}
