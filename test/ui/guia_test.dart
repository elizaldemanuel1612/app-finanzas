import 'package:app_finanzas/ui/ayuda/contenido_guia.dart';
import 'package:app_finanzas/ui/ayuda/pantalla_guia.dart';
import 'package:app_finanzas/ui/ayuda/pantalla_tema_guia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Cubre la guía por temas nueva (Ajustes → "Cómo funciona la app"): que el
// índice liste sus 10 temas y 4 secciones, que navegar a un tema muestre su
// título, que los 10 temas — y con ellos los 7 renderers de BloqueGuiaWidget
// — se monten sin desbordar a 1.0x y 2.0x, y que el ejemplo vivo de la marca
// de ritmo exponga su semanticsLabel.

void main() {
  testWidgets('PantallaGuia lista los títulos de sección y de tema', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaGuia()));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    for (final seccion in guiaDeLaApp) {
      await tester.scrollUntilVisible(find.text(seccion.titulo), 300, scrollable: scrollable);
      expect(find.text(seccion.titulo), findsOneWidget);
      for (final tema in seccion.temas) {
        await tester.scrollUntilVisible(find.text(tema.titulo), 300, scrollable: scrollable);
        expect(find.text(tema.titulo), findsOneWidget);
      }
    }
  });

  testWidgets('tocar un renglón navega y PantallaTemaGuia muestra el título', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PantallaGuia()));
    await tester.pumpAndSettle();

    final primerTema = guiaDeLaApp.first.temas.first;
    await tester.tap(find.text(primerTema.titulo));
    await tester.pumpAndSettle();

    expect(find.byType(PantallaTemaGuia), findsOneWidget);
    expect(find.widgetWithText(AppBar, primerTema.titulo), findsOneWidget);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets('los 10 temas se montan sin desbordar a ${escala}x', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      for (final tema in temasEnOrden) {
        await tester.pumpWidget(MaterialApp(home: PantallaTemaGuia(tema: tema)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tema.id);
      }
    });
  }

  testWidgets('el ejemplo vivo de la marca de ritmo expone su semanticsLabel', (tester) async {
    final handle = tester.ensureSemantics();
    final temaRitmo = temasEnOrden.firstWhere((t) => t.id == 'ritmo');

    await tester.pumpWidget(MaterialApp(home: PantallaTemaGuia(tema: temaRitmo)));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Ritmo de este ejemplo')), findsWidgets);
    handle.dispose();
  });
}
