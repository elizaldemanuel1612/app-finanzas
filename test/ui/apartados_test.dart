import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/categoria_ingreso_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/domain/cuentas/saldos.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/analisis/vista_ingresos.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/cuentas/pantalla_detalle_cuenta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Apartados dentro de una cuenta (spec-app-finanzas-v2.md §7.3.5) y filtro
// por cuenta en Análisis → Ingresos (§7.3.4).

Cuenta _cuenta(String id, String nombre, TipoCuenta tipo, int pesos) => Cuenta(
      id: id,
      nombre: nombre,
      emoji: '🏦',
      tipo: tipo,
      llevaSaldo: true,
      saldoInicial: Dinero.pesos(pesos),
      fechaSaldoInicial: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('crear un apartado pasa dinero de la cuenta y se guarda o saca desde él', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final movs = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final bbva = _cuenta('bbva', 'BBVA', TipoCuenta.debito, 10000);
    await cuentas.guardar(bbva);

    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: PantallaDetalleCuenta(
        cuenta: bbva,
        perfil: const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000)),
        cuentaRepositorio: cuentas,
        movimientoRepositorio: MovimientoRepositorioMemoria([]),
        movimientoCuentaRepositorio: movs,
        ingresoExtraRepositorio: IngresoExtraRepositorioMemoria([]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Apartados'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Nuevo apartado'), 200);
    await tester.tap(find.text('Nuevo apartado'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo apartado en BBVA'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Viaje');
    await tester.enterText(find.widgetWithText(TextField, '¿Cuánto guardas ahora? (opcional)'), '3000');
    await tester.tap(find.text('Crear apartado'));
    await tester.pumpAndSettle();

    final todas = await cuentas.listarTodas();
    final viaje = todas.singleWhere((c) => c.nombre == 'Viaje');
    expect(viaje.cuentaPadreId, 'bbva');
    expect(viaje.tipo, TipoCuenta.ahorro);
    final lista = await movs.listarTodos();
    expect(saldoDe(bbva, const [], lista), const Dinero.pesos(7000));
    expect(saldoDe(viaje, const [], lista), const Dinero.pesos(3000));
    expect(find.text(r'$7,000.00'), findsOneWidget, reason: 'lo disponible en BBVA');
    expect(find.text(r'Con tus apartados: $10,000.00'), findsOneWidget);

    // El apartado: guardar y sacar contra su cuenta.
    await tester.scrollUntilVisible(find.text('Viaje'), 200);
    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apartado en BBVA'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Sacar'), findsOneWidget);
    expect(find.text('Nuevo apartado'), findsNothing, reason: 'no hay apartados de apartados');
    await tester.tap(find.text('Sacar'));
    await tester.pumpAndSettle();
    final transferencia = (await movs.listarTodos()).length;
    expect(transferencia, 1, reason: 'abrir la hoja no guarda nada');
  });

  testWidgets('Ingresos se filtra por una o varias cuentas', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final movs = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    await cuentas.guardar(_cuenta('bbva', 'BBVA', TipoCuenta.debito, 0));
    await cuentas.guardar(_cuenta('cetes', 'Cetes', TipoCuenta.ahorro, 0));
    final hoy = DateTime.now();
    for (final (id, cuenta, pesos) in [('a', 'bbva', 1000), ('b', 'cetes', 400)]) {
      await movs.guardar(MovimientoCuenta(
        clientId: id,
        cuentaId: cuenta,
        fecha: hoy,
        monto: Dinero.pesos(pesos),
        tipo: TipoMovimientoCuenta.abono,
        entra: true,
      ));
    }

    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: Scaffold(
        body: VistaIngresos(
          ciclo: const CalculadoraCiclo(1).calcularPara(hoy),
          categoriaIngresoRepositorio: CategoriaIngresoRepositorioArchivo.sobre(ArchivoTextoMemoria()),
          cuentaRepositorio: cuentas,
          movimientoCuentaRepositorio: movs,
          movimientoRepositorio: MovimientoRepositorioMemoria([]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,400'), findsWidgets);

    await tester.tap(find.text('🏦 Cetes'));
    await tester.pumpAndSettle();
    expect(find.text(r'$400'), findsWidgets);
    expect(find.text(r'$1,400'), findsNothing);

    await tester.tap(find.text('🏦 BBVA'));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,400'), findsWidgets, reason: 'las dos elegidas');

    await tester.tap(find.text('Todas las cuentas'));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,400'), findsWidgets);
  });
}
