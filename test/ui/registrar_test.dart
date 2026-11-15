import 'dart:io';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/captura/pantalla_captura.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Registrar en dos toques (docs/rediseno/plan-rediseno.md, Etapa 3): monto
// con el teclado propio y tocar la categoría guarda y cierra.

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));

void main() {
  testWidgets('monto en el teclado y una categoría: se guarda y regresa el gasto', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final movimientos = MovimientoRepositorioMemoria([]);
    Object? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<Object?>(MaterialPageRoute(
                builder: (_) => PantallaCaptura(
                  perfil: _perfil,
                  categoriaRepositorio: CategoriaRepositorioMemoria([
                    const CategoriaVariable(
                      id: 'salidas',
                      nombre: 'Salidas',
                      emoji: '🍿',
                      activa: true,
                      esNecesaria: false,
                      presupuestoMensualCentavos: Dinero.pesos(3850),
                    ),
                  ]),
                  movimientoRepositorio: movimientos,
                  reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
                  cicloRepositorio: CicloRepositorioMemoria(),
                  documentos: Directory.systemTemp,
                ),
              ));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe cuánto gastaste'), findsOneWidget);
    // Sin monto, la categoría no guarda nada.
    await tester.tap(find.text('Salidas'));
    await tester.pumpAndSettle();
    expect(resultado, isNull);

    for (final t in ['2', '8', '0', '.', '5']) {
      await tester.tap(find.bySemanticsLabel(t == '.' ? 'Punto' : t));
      await tester.pump();
    }
    await tester.tap(find.bySemanticsLabel('Borrar'));
    await tester.tap(find.bySemanticsLabel('5'));
    await tester.pump();
    expect(find.text('Toca la categoría y listo'), findsOneWidget);

    await tester.tap(find.text('Salidas'));
    await tester.pumpAndSettle();
    expect(resultado, isA<Movimiento>());
    expect((resultado! as Movimiento).monto, const Dinero(28050));
    expect(await movimientos.listarTodos(), hasLength(1));
  });
}
