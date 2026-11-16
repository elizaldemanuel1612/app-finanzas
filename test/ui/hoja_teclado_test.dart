import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/cuentas/hoja_transferencia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Con el teclado abierto, el campo que se escribe queda arriba de él
// (lib/ui/comun/hoja.dart): en "Aportar a tu ahorro" con siete cuentas, la
// nota quedaba tapada en el iPhone.

Cuenta _cuenta(String id, TipoCuenta tipo) => Cuenta(
      id: id,
      nombre: 'Cuenta $id',
      emoji: '🏦',
      tipo: tipo,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('el campo enfocado no queda bajo el teclado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cuentas = [
      for (var i = 0; i < 6; i++) _cuenta('d$i', TipoCuenta.debito),
      _cuenta('cetes', TipoCuenta.ahorro),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarHojaTransferencia(
              context,
              cuentas: cuentas,
              repositorio: MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria()),
              origenId: 'd0',
              destinoId: 'cetes',
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final nota = find.widgetWithText(TextField, 'Nota (opcional)');
    await tester.ensureVisible(nota);
    await tester.pumpAndSettle();
    await tester.tap(nota);
    await tester.pumpAndSettle();

    // Sale el teclado: 340 px de abajo.
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();

    expect(tester.getRect(nota).bottom, lessThanOrEqualTo(844 - 340));
    expect(tester.takeException(), isNull);
  });
}
