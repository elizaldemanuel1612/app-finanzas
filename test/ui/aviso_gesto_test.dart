import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/comun/aviso_gesto.dart';
import 'package:app_finanzas/ui/gastos/pantalla_gastos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

void main() {
  setUp(reiniciarAvisosDeGesto);

  testWidgets('cada gesto se explica solo la primera vez', (tester) async {
    late BuildContext contexto;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        contexto = c;
        return const SizedBox();
      })),
    ));

    final primera = await tester.runAsync(() => avisarGestoPrimeraVez(contexto, GestoApp.recargar));
    await tester.pump();
    expect(primera, isTrue);
    expect(find.text(GestoApp.recargar.explicacion), findsOneWidget);

    final segunda = await tester.runAsync(() => avisarGestoPrimeraVez(contexto, GestoApp.recargar));
    expect(segunda, isFalse);

    final otro = await tester.runAsync(() => avisarGestoPrimeraVez(contexto, GestoApp.duplicarGasto));
    expect(otro, isTrue);
  });

  testWidgets('duplicar deslizando: la primera vez explica, la segunda avisa normal', (tester) async {
    const perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(30000));
    final hoy = DateTime.now();
    final movimientos = MovimientoRepositorioMemoria([
      Movimiento(
        id: 'm1',
        clientId: 'm1',
        fecha: hoy,
        cicloId: perfil.calculadoraCiclo.calcularPara(hoy).id,
        periodoNatural: periodoNatural(hoy),
        monto: const Dinero.pesos(50),
        categoriaId: 'super',
        medio: MedioPago.tarjeta,
        descripcion: 'Compra',
        estado: EstadoMovimiento.activo,
        origenCaptura: OrigenCaptura.manual,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: PantallaGastos(
        cicloId: perfil.calculadoraCiclo.calcularPara(hoy).id,
        perfil: perfil,
        categoriaRepositorio: CategoriaRepositorioMemoria(<Categoria>[
          const CategoriaVariable(
            id: 'super',
            nombre: 'Súper',
            emoji: '🛒',
            activa: true,
            esNecesaria: false,
            presupuestoMensualCentavos: Dinero.pesos(100),
          ),
        ]),
        movimientoRepositorio: movimientos,
        reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
        cicloRepositorio: CicloRepositorioMemoria(),
        documentos: Directory.systemTemp,
      ),
    ));
    await tester.pumpAndSettle();

    Future<void> deslizar() async {
      await tester.drag(find.text('Compra').first, const Offset(600, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    await deslizar();
    expect(movimientos.items, hasLength(2));
    expect(find.text(GestoApp.duplicarGasto.explicacion), findsOneWidget);

    // Termina de entrar, y luego corre sus 6 segundos en pantalla.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await deslizar();
    expect(movimientos.items, hasLength(3));
    expect(find.text(GestoApp.duplicarGasto.explicacion), findsNothing);
    expect(find.textContaining('Gasto duplicado:'), findsOneWidget);
  });
}
