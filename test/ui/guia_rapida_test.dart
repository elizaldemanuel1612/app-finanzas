import 'package:app_finanzas/ui/comun/guia_rapida.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> _abrir(WidgetTester tester, GuiaRapida guia, {bool obligatoria = false, String? accionFinal}) async {
  bool? resultado;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => resultado = await mostrarGuiaRapidaPrimeraVez(
              context,
              guia,
              obligatoria: obligatoria,
              accionFinal: accionFinal,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

void main() {
  setUp(() async {
    guiasRapidasActivas = true;
    await reiniciarGuiasRapidas();
  });
  tearDown(() => guiasRapidasActivas = false);

  testWidgets('la de registrar un gasto no se puede omitir y lleva a registrar', (tester) async {
    bool? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => resultado = await mostrarGuiaRapidaPrimeraVez(
              context,
              GuiaRapida.registrarGasto,
              obligatoria: true,
              accionFinal: 'Registrar mi primer gasto',
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Toca el + dorado'), findsOneWidget);
    expect(find.text('Omitir'), findsNothing);
    // Tocar fuera no la cierra.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Toca el + dorado'), findsOneWidget);

    for (var i = 1; i < GuiaRapida.registrarGasto.pasos.length; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Guarda y listo'), findsOneWidget);
    await tester.tap(find.text('Registrar mi primer gasto'));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);

    // Solo la primera vez.
    resultado = null;
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Toca el + dorado'), findsNothing);
    expect(resultado, isFalse);
  });

  testWidgets('las demás se pueden omitir', (tester) async {
    await _abrir(tester, GuiaRapida.cuentas);
    expect(find.text('Agrega tus tarjetas'), findsOneWidget);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.text('Agrega tus tarjetas'), findsNothing);
  });
}
