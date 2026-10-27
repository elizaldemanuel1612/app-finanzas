import 'package:app_finanzas/ui/comun/apariencia.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cambiar entre claro y oscuro con la app abierta: lo que pinta con
/// `ColoresApp` (no con `Theme.of`) también cambia, y el estado de la
/// pantalla se conserva.
class _Muestra extends StatefulWidget {
  const _Muestra();

  @override
  State<_Muestra> createState() => _MuestraState();
}

class _MuestraState extends State<_Muestra> {
  int toques = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => toques++),
        child: Container(key: const Key('caja'), color: ColoresApp.fondo, child: Text('$toques')),
      );
}

void main() {
  tearDown(() {
    AparienciaApp.actual.value = Apariencia.sistema;
    ColoresApp.usar(Paleta.clara);
  });

  testWidgets('pasar a oscuro repinta lo que usa ColoresApp y conserva el estado', (tester) async {
    AparienciaApp.actual.value = Apariencia.claro;
    await tester.pumpWidget(ValueListenableBuilder<Apariencia>(
      valueListenable: AparienciaApp.actual,
      builder: (context, apariencia, _) => MaterialApp(
        theme: construirTema(Paleta.clara),
        darkTheme: construirTema(Paleta.oscura),
        themeMode: apariencia.modo,
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => SincronizarPaleta(child: child!),
        home: const _Muestra(),
      ),
    ));
    Color colorCaja() => (tester.widget<Container>(find.byKey(const Key('caja'))).color)!;

    await tester.tap(find.text('0'));
    await tester.pump();
    expect(colorCaja(), Paleta.clara.fondo);

    AparienciaApp.actual.value = Apariencia.oscuro;
    await tester.pump(); // cambia el tema y la paleta global
    await tester.pump(); // reconstrucción completa del cuadro siguiente
    expect(ColoresApp.oscuro, isTrue);
    expect(colorCaja(), Paleta.oscura.fondo);
    expect(find.text('1'), findsOneWidget, reason: 'el estado no se pierde');

    AparienciaApp.actual.value = Apariencia.claro;
    await tester.pump();
    await tester.pump();
    expect(colorCaja(), Paleta.clara.fondo);
  });
}
