import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/cuentas/pantalla_detalle_cuenta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

void main() {
  testWidgets('abono que también es ingreso, y ajuste para cuadrar con el banco', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final abonos = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final ingresos = IngresoExtraRepositorioMemoria([]);
    final bbva = Cuenta(
      id: 'bbva',
      nombre: 'BBVA',
      emoji: '🏦',
      tipo: TipoCuenta.debito,
      llevaSaldo: true,
      saldoInicial: const Dinero.pesos(1000),
      fechaSaldoInicial: DateTime(2026, 1, 1),
    );
    await cuentas.guardar(bbva);

    await tester.pumpWidget(MaterialApp(
      home: PantallaDetalleCuenta(
        cuenta: bbva,
        perfil: const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000)),
        cuentaRepositorio: cuentas,
        movimientoRepositorio: MovimientoRepositorioMemoria([]),
        movimientoCuentaRepositorio: abonos,
        ingresoExtraRepositorio: ingresos,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,000.00'), findsOneWidget);

    await tester.tap(find.text('Registrar abono'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '¿Cuánto entró?'), '500');
    await tester.enterText(find.widgetWithText(TextField, 'Nota (opcional)'), 'Quincena');
    await tester.tap(find.text('También es ingreso de este ciclo'));
    await tester.tap(find.text('Guardar abono'));
    await tester.pumpAndSettle();

    expect(find.text(r'$1,500.00'), findsOneWidget);
    expect(ingresos.items.single.monto, const Dinero.pesos(500));
    expect(ingresos.items.single.etiqueta, 'Quincena');

    await tester.tap(find.text('Ajustar saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1450');
    await tester.tap(find.text('Ajustar'));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,450.00'), findsOneWidget);
    expect(find.text('Ajuste de saldo'), findsOneWidget);

    // Eliminar el abono quita también el ingreso del ciclo.
    await tester.tap(find.text('Abono · Quincena'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text(r'$950.00'), findsOneWidget);
    expect(ingresos.items.single.estado, EstadoIngreso.anulado);
  });

  testWidgets('transferir a efectivo baja el saldo; en crédito se ofrece pagarla', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final movimientosCuenta = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final bbva = Cuenta(
      id: 'bbva',
      nombre: 'BBVA',
      emoji: '🏦',
      tipo: TipoCuenta.debito,
      llevaSaldo: true,
      saldoInicial: const Dinero.pesos(1000),
      fechaSaldoInicial: DateTime(2026, 1, 1),
    );
    await cuentas.guardar(bbva);
    Widget detalle(Cuenta c) => MaterialApp(
          home: PantallaDetalleCuenta(
            key: ValueKey(c.id),
            cuenta: c,
            perfil: const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000)),
            cuentaRepositorio: cuentas,
            movimientoRepositorio: MovimientoRepositorioMemoria([]),
            movimientoCuentaRepositorio: movimientosCuenta,
            ingresoExtraRepositorio: IngresoExtraRepositorioMemoria([]),
          ),
        );

    await tester.pumpWidget(detalle(bbva));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferir a otra cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('💵 Efectivo').last); // la fila "A"
    await tester.enterText(find.widgetWithText(TextField, '¿Cuánto?'), '200');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Transferir'));
    await tester.pumpAndSettle();
    expect(find.text(r'$800.00'), findsOneWidget);
    expect(find.text('A Efectivo'), findsOneWidget);

    final tarjeta = (await cuentas.listarTodas()).firstWhere((c) => c.id == idCuentaTarjeta);
    await tester.pumpWidget(detalle(tarjeta));
    await tester.pumpAndSettle();
    expect(find.text('Pagar esta tarjeta'), findsOneWidget);
  });
}
