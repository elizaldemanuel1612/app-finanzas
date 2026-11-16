import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/cuentas/pantalla_detalle_cuenta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// "Eliminar cuenta" (spec-app-finanzas-v2.md §7.3.1).

final _nu = Cuenta(
  id: 'nu',
  nombre: 'Nu',
  emoji: '💳',
  tipo: TipoCuenta.debito,
  llevaSaldo: true,
  saldoInicial: const Dinero.pesos(500),
  fechaSaldoInicial: DateTime(2026, 1, 1),
);

Future<void> _abrirDetalle(
  WidgetTester tester,
  CuentaRepositorioArchivo cuentas,
  MovimientoCuentaRepositorioArchivo movs,
) async {
  await tester.pumpWidget(MaterialApp(
    theme: construirTema(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PantallaDetalleCuenta(
              cuenta: _nu,
              perfil: const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000)),
              cuentaRepositorio: cuentas,
              movimientoRepositorio: MovimientoRepositorioMemoria([]),
              movimientoCuentaRepositorio: movs,
              ingresoExtraRepositorio: IngresoExtraRepositorioMemoria([]),
            ),
          )),
          child: const Text('Abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Eliminar cuenta'), 200);
  await tester.ensureVisible(find.text('Eliminar cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Eliminar cuenta'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una cuenta que nunca se usó se borra por completo', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final movs = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    await cuentas.guardar(_nu);

    await _abrirDetalle(tester, cuentas, movs);
    expect(find.textContaining('se borra por completo'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir'), findsOneWidget, reason: 'regresa a la lista');
    expect((await cuentas.listarTodas()).where((c) => c.id == 'nu'), isEmpty);
  });

  testWidgets('con movimientos se archiva y conserva su historial', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final movs = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    await cuentas.guardar(_nu);
    await movs.guardar(MovimientoCuenta(
      clientId: 'a1',
      cuentaId: 'nu',
      fecha: DateTime(2026, 2, 1),
      monto: const Dinero.pesos(100),
      tipo: TipoMovimientoCuenta.abono,
      entra: true,
    ));

    await _abrirDetalle(tester, cuentas, movs);
    expect(find.textContaining('se archiva'), findsOneWidget);
    expect(find.textContaining(r'hoy marca $600.00'), findsOneWidget);
    await tester.tap(find.text('Archivar'));
    await tester.pumpAndSettle();

    final nu = (await cuentas.listarTodas()).singleWhere((c) => c.id == 'nu');
    expect(nu.activa, isFalse);
    expect(await movs.listarTodos(), hasLength(1));
  });
}
