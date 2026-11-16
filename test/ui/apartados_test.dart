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

  testWidgets('eliminar un apartado regresa su dinero a la cuenta y lo quita de la lista', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final movs = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final bbva = _cuenta('bbva', 'BBVA', TipoCuenta.debito, 10000);
    final viaje = Cuenta(
      id: 'viaje',
      nombre: 'Viaje',
      emoji: '✈️',
      tipo: TipoCuenta.ahorro,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 1, 1),
      cuentaPadreId: 'bbva',
    );
    await cuentas.guardar(bbva);
    await cuentas.guardar(viaje);
    await movs.guardar(MovimientoCuenta(
      clientId: 't1',
      cuentaId: 'bbva',
      cuentaDestinoId: 'viaje',
      fecha: DateTime(2026, 2, 1),
      monto: const Dinero.pesos(3000),
      tipo: TipoMovimientoCuenta.transferencia,
      entra: false,
    ));

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
    expect(find.text(r'$7,000.00'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Viaje'), 200);
    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Archivar'), findsNothing, reason: 'un apartado se elimina, no se archiva suelto');
    await tester.tap(find.text('Eliminar apartado'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'Los $3,000.00 que tiene regresan a BBVA'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    // De vuelta en BBVA: el dinero regresó y el apartado ya no está.
    expect(find.text(r'$10,000.00'), findsOneWidget);
    expect(find.text('Viaje'), findsNothing);
    expect(find.text('De Viaje'), findsOneWidget, reason: 'el historial dice de dónde vino');
    final archivado = (await cuentas.listarTodas()).singleWhere((c) => c.id == 'viaje');
    expect(archivado.activa, isFalse);
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
