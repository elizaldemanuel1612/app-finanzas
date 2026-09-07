import 'package:app_finanzas/ui/ayuda/pantalla_guia.dart';
import 'package:app_finanzas/ui/onboarding/pantalla_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Cubre el rediseño del onboarding (Bloque C, guía por temas): que arranque
// en la bienvenida con el titular correcto, que el indicador tenga 7
// puntos, el recorrido feliz hasta el paso final, que "Omitir" y "Ver la
// guía" hagan lo que prometen, y que el paso de ingreso valide antes de
// avanzar. No existía ninguna prueba de onboarding antes de este archivo.

// PageView recibe `children:` (no `.builder`), así que las 7 páginas están
// todas construidas a la vez — el campo de ingreso no es el único
// TextField del árbol (SelectorMeta trae el suyo en el paso de meta), de
// ahí el finder por hintText en vez de find.byType(TextField).
final _campoIngreso = find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Ej. \$20,000',
);

Widget _app({required VoidCallback alTerminar}) {
  return MaterialApp(
    home: PantallaOnboarding(
      perfilRepositorio: PerfilRepositorioMemoria(null),
      categoriaRepositorio: CategoriaRepositorioMemoria([]),
      movimientoRepositorio: MovimientoRepositorioMemoria(const []),
      alTerminar: alTerminar,
    ),
  );
}

Future<void> _avanzarHastaGuia(WidgetTester tester) async {
  await tester.tap(find.text('Empezar')); // paso 0 — bienvenida
  await tester.pumpAndSettle();

  await tester.tap(find.text('Siguiente')); // paso 1 — ciclo (valores por defecto)
  await tester.pumpAndSettle();

  await tester.enterText(_campoIngreso, '87000'); // paso 2 — ingreso
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Siguiente')); // paso 3 — meta (valor por defecto)
  await tester.pumpAndSettle();

  await tester.tap(find.text('Siguiente')); // paso 4 — categorías sugeridas
  await tester.pumpAndSettle();

  await tester.tap(find.text('Siguiente')); // paso 5 — marca de ritmo
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca en la bienvenida con el titular correcto', (tester) async {
    await tester.pumpWidget(_app(alTerminar: () {}));
    await tester.pumpAndSettle();

    expect(find.text('¡Te ayudaré a lograr tu meta de ahorro!'), findsOneWidget);
  });

  testWidgets('el indicador dibuja 7 puntos', (tester) async {
    await tester.pumpWidget(_app(alTerminar: () {}));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedContainer), findsNWidgets(7));
  });

  testWidgets('recorrido feliz hasta el paso final muestra Omitir y Ver la guía', (tester) async {
    await tester.pumpWidget(_app(alTerminar: () {}));
    await tester.pumpAndSettle();

    await _avanzarHastaGuia(tester);

    expect(find.text('Lo que nadie lee... el instructivo'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Ver la guía'), findsOneWidget);
  });

  testWidgets('Omitir invoca alTerminar y muestra el SnackBar de recordatorio', (tester) async {
    var terminado = false;
    await tester.pumpWidget(_app(alTerminar: () => terminado = true));
    await tester.pumpAndSettle();

    await _avanzarHastaGuia(tester);
    await tester.tap(find.text('Omitir'));
    await tester.pump();

    expect(terminado, isTrue);
    expect(
      find.text('Cuando quieras, la guía está en Ajustes → "Cómo funciona la app".'),
      findsOneWidget,
    );
  });

  testWidgets('Ver la guía invoca alTerminar y deja PantallaGuia en pantalla', (tester) async {
    var terminado = false;
    await tester.pumpWidget(_app(alTerminar: () => terminado = true));
    await tester.pumpAndSettle();

    await _avanzarHastaGuia(tester);
    await tester.tap(find.text('Ver la guía'));
    await tester.pumpAndSettle();

    expect(terminado, isTrue);
    expect(find.byType(PantallaGuia), findsOneWidget);
  });

  testWidgets('el paso de ingreso no avanza sin monto y muestra el error', (tester) async {
    await tester.pumpWidget(_app(alTerminar: () {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    // Paso 2 — ingreso, sin escribir nada.
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Registra tu ingreso base al mes'), findsOneWidget);
    expect(find.textContaining('Escribe cuánto entra'), findsOneWidget);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets('paso 0 y paso final no desbordan a ${escala}x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(_app(alTerminar: () {}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _avanzarHastaGuia(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
