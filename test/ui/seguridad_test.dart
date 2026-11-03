import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/firebase/servicio_auth.dart';
import 'package:app_finanzas/data/seguridad/candado.dart';
import 'package:app_finanzas/domain/seguridad/politica_bloqueo.dart';
import 'package:app_finanzas/ui/seguridad/pantalla_crear_pin.dart';
import 'package:app_finanzas/ui/seguridad/pantalla_desbloqueo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _teclear(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late Candado candado;

  setUp(() => candado = Candado(ArchivoTextoMemoria(), iteraciones: 10));

  testWidgets('crear PIN: rechaza uno fácil, pide confirmarlo y lo guarda', (tester) async {
    var termino = false;
    await tester.pumpWidget(MaterialApp(
      home: PantallaCrearPin(candado: candado, alTerminar: () => termino = true),
    ));

    await _teclear(tester, '123456');
    expect(find.textContaining('fácil de adivinar'), findsOneWidget);

    await _teclear(tester, '482915');
    expect(find.text('Confírmalo'), findsOneWidget);
    await _teclear(tester, '482916');
    expect(find.textContaining('No coinciden'), findsOneWidget);

    await _teclear(tester, '482915');
    await _teclear(tester, '482915');
    expect(termino, isTrue);
    expect(await candado.probarPin('482915'), isTrue);
  });

  testWidgets('desbloquear con PIN: error y luego entra', (tester) async {
    await candado.definirPin('482915');
    var entro = false;
    await tester.pumpWidget(MaterialApp(
      home: PantallaDesbloqueo(
        candado: candado,
        servicioAuth: ServicioAuth(),
        alDesbloquear: () => entro = true,
        biometriaDisponible: () async => false,
      ),
    ));
    await tester.pumpAndSettle();

    await _teclear(tester, '000001');
    expect(find.text('PIN incorrecto.'), findsOneWidget);
    expect(entro, isFalse);
    await _teclear(tester, '482915');
    expect(entro, isTrue);
  });

  testWidgets('con Face ID elegido, lo intenta solo al abrir', (tester) async {
    await candado.definirPin('482915');
    await candado.elegirMetodo(MetodoDesbloqueo.biometria);
    var entro = false;
    await tester.pumpWidget(MaterialApp(
      home: PantallaDesbloqueo(
        candado: candado,
        servicioAuth: ServicioAuth(),
        alDesbloquear: () => entro = true,
        biometriaDisponible: () async => true,
        autenticarBiometria: () async => true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(entro, isTrue);
  });

  testWidgets('si Face ID falla, ofrece el PIN', (tester) async {
    await candado.definirPin('482915');
    await candado.elegirMetodo(MetodoDesbloqueo.biometria);
    var entro = false;
    await tester.pumpWidget(MaterialApp(
      home: PantallaDesbloqueo(
        candado: candado,
        servicioAuth: ServicioAuth(),
        alDesbloquear: () => entro = true,
        biometriaDisponible: () async => true,
        autenticarBiometria: () async => false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No te reconocí'), findsOneWidget);
    await tester.tap(find.text('Usar mi PIN'));
    await tester.pumpAndSettle();
    await _teclear(tester, '482915');
    expect(entro, isTrue);
  });

  testWidgets('contraseña elegida: se escribe y entra', (tester) async {
    await candado.definirPin('482915');
    await candado.definirContrasena('casa12');
    await candado.elegirMetodo(MetodoDesbloqueo.contrasena);
    var entro = false;
    await tester.pumpWidget(MaterialApp(
      home: PantallaDesbloqueo(
        candado: candado,
        servicioAuth: ServicioAuth(),
        alDesbloquear: () => entro = true,
        biometriaDisponible: () async => false,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'casa12');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(entro, isTrue);
  });

  testWidgets('a la semana pide el PIN aunque el método sea contraseña', (tester) async {
    final antes = DateTime.now().subtract(const Duration(days: 8));
    final viejo = Candado(ArchivoTextoMemoria(), iteraciones: 10, reloj: () => antes);
    await viejo.definirPin('482915');
    await viejo.definirContrasena('casa12');
    await viejo.elegirMetodo(MetodoDesbloqueo.contrasena);
    final hoy = Candado(viejo.archivo, iteraciones: 10);
    await tester.pumpWidget(MaterialApp(
      home: PantallaDesbloqueo(
        candado: hoy,
        servicioAuth: ServicioAuth(),
        alDesbloquear: () {},
        biometriaDisponible: () async => false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu PIN'), findsOneWidget);
    expect(find.textContaining('Una vez por semana'), findsOneWidget);
  });
}
