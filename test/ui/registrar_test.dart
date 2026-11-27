import 'dart:io';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/repositorios/cuenta_repositorio.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/captura/pantalla_captura.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Registrar en dos toques (docs/rediseno/plan-rediseno.md, Etapa 3): monto
// con el teclado propio y tocar la categoría guarda y cierra.

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));

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

void main() {
  testWidgets('monto en el teclado y una categoría: se guarda y regresa el gasto', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final movimientos = MovimientoRepositorioMemoria([]);
    Object? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<Object?>(MaterialPageRoute(
                builder: (_) => PantallaCaptura(
                  perfil: _perfil,
                  categoriaRepositorio: CategoriaRepositorioMemoria([
                    const CategoriaVariable(
                      id: 'salidas',
                      nombre: 'Salidas',
                      emoji: '🍿',
                      activa: true,
                      esNecesaria: false,
                      presupuestoMensualCentavos: Dinero.pesos(3850),
                    ),
                  ]),
                  movimientoRepositorio: movimientos,
                  reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
                  cicloRepositorio: CicloRepositorioMemoria(),
                  documentos: Directory.systemTemp,
                ),
              ));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe cuánto gastaste'), findsOneWidget);
    // Sin monto, la categoría no guarda nada.
    await tester.tap(find.text('Salidas'));
    await tester.pumpAndSettle();
    expect(resultado, isNull);

    for (final t in ['2', '8', '0', '.', '5']) {
      await tester.tap(find.bySemanticsLabel(t == '.' ? 'Punto' : t));
      await tester.pump();
    }
    await tester.tap(find.bySemanticsLabel('Borrar'));
    await tester.tap(find.bySemanticsLabel('5'));
    await tester.pump();
    expect(find.text('Toca la categoría y listo'), findsOneWidget);

    await tester.tap(find.text('Salidas'));
    await tester.pumpAndSettle();
    expect(resultado, isA<Movimiento>());
    expect((resultado! as Movimiento).monto, const Dinero(28050));
    expect(await movimientos.listarTodos(), hasLength(1));
  });

  testWidgets('con tarjeta de crédito, a meses: una mensualidad por mes', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final movimientos = MovimientoRepositorioMemoria([]);
    Object? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<Object?>(MaterialPageRoute(
                builder: (_) => PantallaCaptura(
                  perfil: _perfil,
                  categoriaRepositorio: CategoriaRepositorioMemoria([
                    const CategoriaVariable(
                      id: 'casa',
                      nombre: 'Casa',
                      emoji: '🏠',
                      activa: true,
                      esNecesaria: false,
                      presupuestoMensualCentavos: Dinero.pesos(3000),
                    ),
                  ]),
                  movimientoRepositorio: movimientos,
                  reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
                  cicloRepositorio: CicloRepositorioMemoria(),
                  documentos: Directory.systemTemp,
                  cuentaRepositorio: _Cuentas([
                    Cuenta(
                      id: 'platino',
                      nombre: 'Platino',
                      emoji: '💳',
                      tipo: TipoCuenta.credito,
                      llevaSaldo: false,
                      saldoInicial: const Dinero.cero(),
                      fechaSaldoInicial: DateTime(2026),
                    ),
                  ]),
                ),
              ));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    for (final t in ['1', '2', '0', '0', '0']) {
      await tester.tap(find.bySemanticsLabel(t));
      await tester.pump();
    }
    await tester.tap(find.text('Meses'));
    await tester.pumpAndSettle();
    expect(find.text(r'$1,000 al mes'), findsOneWidget);
    await tester.tap(find.text('12 meses'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'12 mensualidades de $1,000'), findsOneWidget);

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    final guardados = await movimientos.listarTodos();
    expect(guardados, hasLength(12));
    expect(guardados.every((m) => m.monto == const Dinero.pesos(1000) && m.cuentaId == 'platino'), isTrue);
    expect((resultado! as Movimiento).mensualidad, 1);
  });
  testWidgets('compra hoy y empieza a pagar en 3 meses: la primera mensualidad llega después', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final movimientos = MovimientoRepositorioMemoria([]);
    Object? resultado;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await Navigator.of(context).push<Object?>(MaterialPageRoute(
                builder: (_) => PantallaCaptura(
                  perfil: _perfil,
                  categoriaRepositorio: CategoriaRepositorioMemoria([
                    const CategoriaVariable(
                      id: 'casa',
                      nombre: 'Casa',
                      emoji: '🏠',
                      activa: true,
                      esNecesaria: false,
                      presupuestoMensualCentavos: Dinero.pesos(3000),
                    ),
                  ]),
                  movimientoRepositorio: movimientos,
                  reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
                  cicloRepositorio: CicloRepositorioMemoria(),
                  documentos: Directory.systemTemp,
                  cuentaRepositorio: _Cuentas([
                    Cuenta(
                      id: 'platino',
                      nombre: 'Platino',
                      emoji: '💳',
                      tipo: TipoCuenta.credito,
                      llevaSaldo: false,
                      saldoInicial: const Dinero.cero(),
                      fechaSaldoInicial: DateTime(2026),
                    ),
                  ]),
                ),
              ));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    for (final t in ['1', '2', '0', '0', '0']) {
      await tester.tap(find.bySemanticsLabel(t));
      await tester.pump();
    }
    await tester.tap(find.text('Meses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En 3 meses'));
    await tester.pumpAndSettle();
    expect(find.textContaining('el primer pago llega en'), findsOneWidget);
    await tester.tap(find.text('6 meses'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'6 mensualidades de $2,000 desde'), findsOneWidget);
    expect(find.textContaining('6 meses desde'), findsOneWidget);

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    final guardados = await movimientos.listarTodos()
      ..sort((a, b) => a.mensualidad!.compareTo(b.mensualidad!));
    expect(guardados, hasLength(6));
    expect(guardados.every((m) => m.diferido == 3 && m.monto == const Dinero.pesos(2000)), isTrue);
    final hoy = DateTime.now();
    expect(guardados.first.fecha.month, DateTime(hoy.year, hoy.month + 3).month);
    expect(resultado, isNotNull);
  });
}
