import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/traslado_sobrante.dart';
import 'package:app_finanzas/ui/ciclo/hoja_traslado_sobrante.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// addendum-v3-ajuste-y-ux.md §2.5.2: nada marcado por omisión; se elige
// categoría por categoría y la hoja dice el efecto en lo que apartas.

SobranteCategoria _s(String nombre, int pesos) => SobranteCategoria(
      categoria: CategoriaVariable(
        id: nombre.toLowerCase(),
        nombre: nombre,
        emoji: '🚗',
        activa: true,
        esNecesaria: false,
        presupuestoMensualCentavos: Dinero.pesos(pesos * 2),
      ),
      sobrante: Dinero.pesos(pesos),
    );

void main() {
  testWidgets('elegir solo Auto y trasladar regresa solo Auto', (tester) async {
    DecisionTraslado? decision;
    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                decision = await mostrarHojaTraslado(context, sobrantes: [_s('Súper', 800), _s('Auto', 500)], preseleccion: const {}),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Te sobró en 2 categorías'), findsOneWidget);
    // Nada marcado: el botón principal no traslada nada todavía.
    expect(find.text('Elige qué trasladar'), findsOneWidget);

    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(find.text(r'Apartarías hasta $500 menos este ciclo.'), findsOneWidget);
    await tester.tap(find.text(r'Trasladar $500'));
    await tester.pumpAndSettle();
    expect(decision!.elegidas, {'auto'});
    expect(decision!.recordar, isFalse);
  });

  testWidgets('"No trasladar nada" no elige ninguna', (tester) async {
    DecisionTraslado? decision;
    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                decision = await mostrarHojaTraslado(context, sobrantes: [_s('Auto', 500)], preseleccion: const {'auto'}),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Te sobró en una categoría'), findsOneWidget);
    expect(find.text(r'Trasladar $500'), findsOneWidget); // recordada: ya viene marcada
    await tester.tap(find.text('No trasladar nada'));
    await tester.pumpAndSettle();
    expect(decision!.elegidas, isEmpty);
  });
}
