import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/data/repositorios/local/categoria_ingreso_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/categoria_ingreso.dart';
import 'package:app_finanzas/domain/sincronizacion/fusion.dart';
import 'package:test/test.dart';

void main() {
  test('la primera vez siembra las sugeridas; luego agrega y reemplaza por id', () async {
    final repo = CategoriaIngresoRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final iniciales = await repo.listarTodas();
    expect(iniciales.map((c) => c.nombre), contains('Nómina'));
    await repo.guardar(const CategoriaIngreso(id: 'beca', nombre: 'Beca', emoji: '🎓'));
    await repo.guardar(iniciales.first.copyWith(activa: false));
    final todas = await repo.listarTodas();
    expect(todas.length, iniciales.length + 1);
    expect(todas.first.activa, isFalse);
    expect(todas.last.id, 'beca');
  });

  test('un archivo que ya existe vacío se respeta (no se vuelve a sembrar)', () async {
    final archivo = ArchivoTextoMemoria();
    await archivo.escribir('[]');
    expect(await CategoriaIngresoRepositorioArchivo.sobre(archivo).listarTodas(), isEmpty);
  });

  test('categorias_ingreso.json es parte de los datos de la app y se respalda por id', () {
    expect(AlmacenLocal.nombresDeArchivo, contains('categorias_ingreso.json'));
    expect(claveDeArchivo('categorias_ingreso.json')!({'id': 'ing-nomina'}), 'ing-nomina');
  });
}
