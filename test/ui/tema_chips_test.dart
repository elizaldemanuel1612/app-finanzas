import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El texto de un chip seleccionado (fondo azul noche) tiene que ser
/// blanco: con el color fijo de antes, los nombres de las categorías del
/// onboarding no se leían.
void main() {
  Color colorDe(WidgetTester tester, String texto) {
    // El chip le pasa su labelStyle al Text vía DefaultTextStyle.
    return DefaultTextStyle.of(tester.element(find.text(texto))).style.color!;
  }

  testWidgets('chip seleccionado en blanco, sin seleccionar en tinta', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: Scaffold(
        body: Wrap(children: [
          FilterChip(label: const Text('Vivienda'), selected: true, onSelected: (_) {}),
          FilterChip(label: const Text('Hijos'), selected: false, onSelected: (_) {}),
        ]),
      ),
    ));
    expect(colorDe(tester, 'Vivienda'), Colors.white);
    expect(colorDe(tester, 'Hijos'), ColoresApp.tinta);
  });
}
