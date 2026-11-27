import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/data/repositorios/cuenta_repositorio.dart';
import 'package:app_finanzas/domain/cuentas/compra_a_meses.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/ui/analisis/vista_a_meses.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Análisis › A meses (spec-app-finanzas-v2.md §7.3.1, 2026-11-27).

final class _Cuentas implements CuentaRepositorio {
  final List<Cuenta> items;
  _Cuentas(this.items);
  @override
  Future<List<Cuenta>> listarTodas() async => items;
  @override
  Future<void> guardar(Cuenta cuenta) async => items.add(cuenta);
  @override
  Future<void> eliminar(String id) async => items.removeWhere((c) => c.id == id);
}

Cuenta _tarjeta(String id, String nombre) => Cuenta(
      id: id,
      nombre: nombre,
      emoji: '💳',
      tipo: TipoCuenta.credito,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026),
    );

List<Movimiento> _compra(String nombre, String cuenta, {required int pesos, required int meses, required DateTime fecha, int diferido = 0}) =>
    switch (crearCompraAMeses(
      compraId: 'compra-$nombre-0001',
      fecha: fecha,
      calculadoraCiclo: const CalculadoraCiclo(1),
      total: Dinero.pesos(pesos),
      meses: meses,
      categoriaId: 'casa',
      descripcion: nombre,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuenta,
      diferido: diferido,
    )) {
      Exito(:final valor) => valor,
      Falla(:final mensaje) => throw StateError(mensaje),
    };

Future<void> _montar(WidgetTester tester, List<Movimiento> gastos) async {
  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: VistaAMeses(
        cuentaRepositorio: _Cuentas([_tarjeta('bbva', 'BBVA'), _tarjeta('amex', 'Amex')]),
        movimientoRepositorio: MovimientoRepositorioMemoria(gastos),
        ingreso: const Dinero.pesos(20000),
        hoy: DateTime(2026, 11, 27),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cuánto se debe, lo de este mes, cada compra y el filtro por tarjeta', (tester) async {
    await _montar(tester, [
      ..._compra('Pantalla', 'bbva', pesos: 12000, meses: 12, fecha: DateTime(2026, 9, 10)),
      ..._compra('Sala', 'amex', pesos: 12000, meses: 6, fecha: DateTime(2026, 11, 20), diferido: 3),
    ]);
    expect(find.text(r'$21,000'), findsOneWidget);
    expect(find.text('Este mes pagas'), findsOneWidget);
    expect(find.textContaining(r'De cada $100 que ganas, $5 se van a meses'), findsOneWidget);
    expect(find.textContaining('Empiezas en febrero de 2027'), findsOneWidget);
    expect(find.textContaining('van 3 de 12'), findsOneWidget);
    expect(find.text('Debes más en 💳 Amex'), findsOneWidget);
    // La sala diferida empieza a cobrarse en febrero: eso se avisa primero.
    expect(find.text(r'En febrero de 2027 sube a $3,000'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilterChip, '💳 BBVA'));
    await tester.tap(find.widgetWithText(FilterChip, '💳 BBVA'));
    await tester.pumpAndSettle();
    expect(find.text(r'$9,000'), findsWidgets);
    expect(find.textContaining('Empiezas en'), findsNothing);
  });

  testWidgets('sin compras a meses lo dice', (tester) async {
    await _montar(tester, const []);
    expect(find.text('No debes nada a meses'), findsOneWidget);
  });
}
