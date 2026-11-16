import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/objetivo_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/objetivos/pantalla_editar_objetivo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Eliminar un objetivo (spec-app-finanzas-v2.md §7.3.3): pide confirmación
// y cancelar no borra nada.
void main() {
  testWidgets('Eliminar objetivo confirma antes de quitarlo', (tester) async {
    final objetivos = ObjetivoRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final viaje = Objetivo(
      id: 'viaje',
      nombre: 'Viaje',
      emoji: '✈️',
      monto: const Dinero.pesos(20000),
      cuentaId: 'cetes',
      creado: DateTime(2026, 11, 1),
    );
    await objetivos.guardar(viaje);

    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: PantallaEditarObjetivo(
        objetivoRepositorio: objetivos,
        cuentaRepositorio: CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria()),
        existente: viaje,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Eliminar objetivo'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Eliminar objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar Viaje?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await objetivos.listarTodos(), hasLength(1));

    await tester.tap(find.text('Eliminar objetivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(await objetivos.listarTodos(), isEmpty);
  });
}
