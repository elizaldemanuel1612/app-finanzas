import 'package:app_finanzas/domain/rollups/estado_ritmo.dart';
import 'package:app_finanzas/ui/comun/aviso.dart';
import 'package:app_finanzas/ui/comun/barra_ritmo.dart';
import 'package:app_finanzas/ui/comun/chip_estado.dart';
import 'package:app_finanzas/ui/comun/renglon_app.dart';
import 'package:app_finanzas/ui/comun/tarjeta_app.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Componentes base del rediseño (docs/rediseno/plan-rediseno.md, Etapa 1).

Widget _app(Widget hijo, {double escala = 1}) => MaterialApp(
      theme: construirTema(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(escala)),
        child: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: hijo)),
      ),
    );

Iterable<Color> _coloresDeRelleno(WidgetTester tester) =>
    tester.widgetList<ColoredBox>(find.descendant(of: find.byType(BarraRitmo), matching: find.byType(ColoredBox))).map((c) => c.color);

void main() {
  testWidgets('la barra rebasada se re-escala: corte y exceso en peligro, nunca toda roja', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 300,
      child: BarraRitmo(porcentajeUsado: 1.25, avanceCiclo: 0.5, descripcion: 'Salidas'),
    )));
    final p = ColoresApp.actual;
    final colores = _coloresDeRelleno(tester).toList();
    expect(colores, containsAll([p.grafPista, p.atencion, p.superficie, p.peligro]));
    // Lo presupuestado ocupa 1/1.25 del ancho: 240 de 300.
    final dentro = tester.getSize(find.descendant(of: find.byType(BarraRitmo), matching: find.byType(SizedBox)).at(1));
    expect(dentro.width, closeTo(240, 0.5));
  });

  testWidgets('la barra y el chip dicen lo mismo', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      const SizedBox(width: 300, child: BarraRitmo(porcentajeUsado: 0.3, avanceCiclo: 0.5, descripcion: 'Súper')),
      ChipEstado.ritmo(TonoRitmo.vasBien),
      ChipEstado.ritmo(TonoRitmo.tePasaste, enHeroe: true),
    ])));
    expect(_coloresDeRelleno(tester), contains(ColoresApp.actual.exito));
    expect(find.text('Vas bien'), findsOneWidget);
    expect(find.text('Te pasaste'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('tarjetas, renglón y aviso se arman sin desbordar a 2×', (tester) async {
    var tocado = 0;
    await tester.pumpWidget(_app(
      SingleChildScrollView(
        child: Column(children: [
          const TarjetaApp.heroe(child: Text('Hoy puedes gastar')),
          TarjetaApp.lista(renglones: [
            RenglonApp(emoji: '🛒', titulo: 'Súper', subtitulo: r'$3,290 de $7,700', monto: r'Quedan $4,410', onTap: () => tocado++),
            const RenglonApp(icono: Icons.home_outlined, titulo: 'Fijos', monto: 'Al día'),
          ]),
          Aviso(tono: TonoEstado.peligro, titulo: r'Te pasaste en Salidas por $620', accion: 'Cubrir con Auto', onAccion: () {}),
          const Aviso.info(titulo: 'Ciclo cerrado'),
        ]),
      ),
      escala: 2,
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Súper'));
    expect(tocado, 1);
    expect(find.text('Cubrir con Auto'), findsOneWidget);
  });
}
