import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/ia/clientes_ia.dart';
import 'package:app_finanzas/data/ia/configuracion_ia.dart';
import 'package:app_finanzas/data/ia/servicio_ia.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/ia/pantalla_asistente.dart';
import 'package:app_finanzas/ui/ia/pantalla_complementos_ia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// spec §6.5: el asistente contesta con la IA conectada y la guía como
// instructivo; sin IA, ofrece conectarla.

final class _IAFalsa implements ClienteIA {
  String? sistema;
  List<MensajeIA> mensajes = const [];
  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) async {
    this.sistema = sistema;
    this.mensajes = mensajes;
    return 'Toca el **+** dorado.';
  }
}

Widget _app(Widget pantalla) => MaterialApp(theme: construirTema(), home: pantalla);

void main() {
  testWidgets('sin IA conectada ofrece conectarla', (tester) async {
    final servicio = ServicioIA(AlmacenConfiguracionIA(ArchivoTextoMemoria()));
    await tester.pumpWidget(_app(PantallaAsistente(servicio: servicio)));
    await tester.pumpAndSettle();
    expect(find.text('Conectar mi IA'), findsOneWidget);
  });

  testWidgets('pregunta con una sugerencia y muestra la respuesta', (tester) async {
    final ia = _IAFalsa();
    final archivo = ArchivoTextoMemoria();
    final servicio = ServicioIA(AlmacenConfiguracionIA(archivo), apple: ia);
    await servicio.conectarApple();
    await tester.pumpWidget(_app(PantallaAsistente(servicio: servicio)));
    await tester.pumpAndSettle();
    expect(find.text('Con Apple Intelligence'), findsOneWidget);

    await tester.tap(find.text('¿Cómo registro un gasto?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dorado'), findsOneWidget);
    expect(ia.sistema, contains('GUÍA'));
    expect(ia.mensajes.single.texto, '¿Cómo registro un gasto?');
  });

  testWidgets('Complementos lista los de clave y el interruptor se enciende al conectar', (tester) async {
    final archivo = ArchivoTextoMemoria();
    final servicio = ServicioIA(AlmacenConfiguracionIA(archivo));
    await tester.pumpWidget(_app(PantallaComplementosIA(servicio: servicio)));
    await tester.pumpAndSettle();
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('ChatGPT'), findsNothing);
    expect(find.text('Claude'), findsNothing);
    expect(find.text('Conecta una IA para encenderlo.'), findsOneWidget);

    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    expect(find.text('Conectar Gemini'), findsOneWidget);
    expect(find.text('Abrir Google AI Studio'), findsOneWidget);
  });
}
