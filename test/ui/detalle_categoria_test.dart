import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/categorias/pantalla_detalle_categoria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Detalle de categoría (docs/rediseno/plan-rediseno.md, Etapa 6): una sola
// acción primaria cuando la categoría se pasó — mover desde la que propone
// calcularCoberturas, la misma de Inicio y Análisis.

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));
final _calculadora = CalculadoraCiclo(_perfil.diaCorte);

CategoriaVariable _var(String id, int presupuesto) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(presupuesto),
    );

var _n = 0;
Movimiento _gasto(String categoria, int pesos, DateTime fecha) => conId(Movimiento(
      clientId: 'm-${_n++}',
      fecha: fecha,
      cicloId: _calculadora.calcularPara(fecha).id,
      periodoNatural: periodoNatural(fecha),
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: MedioPago.tarjeta,
      descripcion: '$categoria $pesos',
      estado: EstadoMovimiento.activo,
      origenCaptura: OrigenCaptura.manual,
    ));

void main() {
  testWidgets('si se pasó, ofrece mover desde la que tiene espacio y lo aplica al confirmar', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final hoy = DateTime.now();
    final ciclo = _calculadora.calcularPara(hoy);
    final salidas = _var('Salidas', 1000);
    final auto = _var('Auto', 5000);
    final ajustes = AjustePresupuestoCicloRepositorioMemoria();
    await tester.pumpWidget(MaterialApp(
      home: PantallaDetalleCategoria(
        categoria: salidas,
        ciclo: ciclo,
        avanceCiclo: 0.5,
        categoriaRepositorio: CategoriaRepositorioMemoria([salidas, auto]),
        movimientoRepositorio: MovimientoRepositorioMemoria([
          _gasto('Salidas', 1600, hoy),
          // Auto gasta poco ciclo tras ciclo: el MPC le estima sobrante.
          for (final dias in [35, 65, 95, 125]) _gasto('Auto', 500, hoy.subtract(Duration(days: dias))),
        ]),
        reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
        ajustePresupuestoCicloRepositorio: ajustes,
        cicloRepositorio: CicloRepositorioMemoria(),
        perfil: _perfil,
        documentos: Directory.systemTemp,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Te pasaste por'), findsOneWidget);
    expect(find.text('Cúbrelo con Auto'), findsOneWidget);
    final mover = find.textContaining(r'Mover $600');
    expect(mover, findsOneWidget);
    expect(find.text('Elegir otra categoría'), findsOneWidget);

    await tester.tap(mover);
    await tester.pumpAndSettle();
    expect(find.textContaining('Solo para este ciclo'), findsOneWidget);
    await tester.tap(find.text(r'Mover $600').last);
    await tester.pumpAndSettle();

    expect(ajustes.items, isNotEmpty);
    expect(find.text('Cúbrelo con Auto'), findsNothing, reason: 'ya quedó cubierto');
    expect(find.textContaining('Listo, moviste'), findsOneWidget);
  });
}
