import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/categoria_ingreso_repositorio_archivo.dart';
import 'package:app_finanzas/ui/categorias/pantalla_categorias.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// spec §7.3.4: Categorías con selector Gastos | Ingresos; el + crea del
// tipo que se está viendo.

void main() {
  testWidgets('Ingresos lista las de ingreso y el + abre su editor', (tester) async {
    final ingresos = CategoriaIngresoRepositorioArchivo.sobre(ArchivoTextoMemoria());
    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: PantallaCategorias(
        categoriaRepositorio: CategoriaRepositorioMemoria([]),
        movimientoRepositorio: MovimientoRepositorioMemoria([]),
        reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
        cicloRepositorio: CicloRepositorioMemoria(),
        categoriaIngresoRepositorio: ingresos,
      ),
    ));
    await tester.pumpAndSettle();
    // Arranca en Gastos: las de ingreso no se ven.
    expect(find.text('Nómina'), findsNothing);

    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();
    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('Rentas'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Nueva categoría de ingreso'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Beca');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect((await ingresos.listarTodas()).last.nombre, 'Beca');
    // Queda al final de la lista, fuera de la pantalla de la prueba.
    await tester.scrollUntilVisible(find.text('Beca'), 200);
    expect(find.text('Beca'), findsOneWidget);
  });
}
