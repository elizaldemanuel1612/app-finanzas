import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/firebase/servicio_auth.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/analisis/pantalla_analisis.dart';
import 'package:app_finanzas/ui/gastos/pantalla_gastos.dart';
import 'package:app_finanzas/ui/inicio/pantalla_inicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Auditoría de escalado de texto (Fase 6, Bloque 4.2): monta las pantallas
// de más riesgo — más texto y cifras por área, según
// docs/tiendas/checklist-publicacion.md — a 1.0x, 1.5x y 2.0x, y falla si
// `RenderFlex` desborda. No fija ningún `textScaler` global (eso anularía
// la accesibilidad); solo verifica que el layout aguanta el tamaño de
// fuente del sistema al máximo, incluida la cifra héroe acotada con
// `clamp(maxScaleFactor: 1.6)` en pantalla_inicio.dart.

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));

final _renta = const CategoriaFija(
  id: 'renta',
  nombre: 'Renta del departamento',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: Dinero.pesos(5000),
  diaDelCiclo: 1,
);

final _super = const CategoriaVariable(
  id: 'super',
  nombre: 'Súper, comida y restaurantes',
  emoji: '🛒',
  activa: true,
  esNecesaria: true,
  presupuestoMensualCentavos: Dinero.pesos(6000),
);

final _transporte = const CategoriaVariable(
  id: 'transporte',
  nombre: 'Transporte y gasolina',
  emoji: '🚌',
  activa: true,
  esNecesaria: false,
  presupuestoMensualCentavos: Dinero.pesos(2000),
);

List<Movimiento> _movimientosDeHoy() {
  final hoy = DateTime.now();
  final cicloId = CalculadoraCiclo(_perfil.diaCorte).calcularPara(hoy).id;
  Movimiento mov(String clientId, String categoriaId, int pesos, String descripcion) => conId(
        Movimiento(
          clientId: clientId,
          fecha: hoy,
          cicloId: cicloId,
          periodoNatural: periodoNatural(hoy),
          monto: Dinero.pesos(pesos),
          categoriaId: categoriaId,
          medio: MedioPago.tarjeta,
          descripcion: descripcion,
          estado: EstadoMovimiento.activo,
          origenCaptura: OrigenCaptura.manual,
        ),
      );
  return [
    mov('renta', 'renta', 5000, 'Renta'),
    mov('super-1', 'super', 850, 'Supermercado del fin de semana con todo y despensa'),
    mov('super-2', 'super', 320, 'Café'),
    mov('transporte-1', 'transporte', 450, 'Gasolina'),
  ];
}

Future<void> _pumpEscalado(
  WidgetTester tester, {
  required Widget home,
  required double escala,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  for (final escala in [1.0, 1.5, 2.0]) {
    testWidgets('PantallaInicio no desborda a ${escala}x', (tester) async {
      final categorias = [_renta, _super, _transporte];
      final movimientos = _movimientosDeHoy();

      await _pumpEscalado(
        tester,
        escala: escala,
        home: PantallaInicio(
          perfil: _perfil,
          categoriaRepositorio: CategoriaRepositorioMemoria(categorias),
          movimientoRepositorio: MovimientoRepositorioMemoria(movimientos),
          reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
          cicloRepositorio: CicloRepositorioMemoria(),
          ingresoExtraRepositorio: IngresoExtraRepositorioMemoria(const []),
          ajustePresupuestoCicloRepositorio: AjustePresupuestoCicloRepositorioMemoria(),
          perfilRepositorio: PerfilRepositorioMemoria(_perfil),
          servicioAuth: ServicioAuth(),
          almacenLocal: AlmacenLocal(Directory.systemTemp),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('PantallaGastos no desborda a ${escala}x', (tester) async {
      final categorias = [_renta, _super, _transporte];
      final movimientos = _movimientosDeHoy();
      final cicloId = movimientos.first.cicloId;

      await _pumpEscalado(
        tester,
        escala: escala,
        home: PantallaGastos(
          cicloId: cicloId,
          perfil: _perfil,
          categoriaRepositorio: CategoriaRepositorioMemoria(categorias),
          movimientoRepositorio: MovimientoRepositorioMemoria(movimientos),
          reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
          cicloRepositorio: CicloRepositorioMemoria(),
          documentos: Directory.systemTemp,
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('PantallaAnalisis no desborda a ${escala}x', (tester) async {
      final categorias = [_renta, _super, _transporte];
      final movimientos = _movimientosDeHoy();

      await _pumpEscalado(
        tester,
        escala: escala,
        home: PantallaAnalisis(
          perfil: _perfil,
          ciclo: _perfil.calculadoraCiclo.calcularPara(DateTime.now()),
          categoriaRepositorio: CategoriaRepositorioMemoria(categorias),
          movimientoRepositorio: MovimientoRepositorioMemoria(movimientos),
          ajustePresupuestoCicloRepositorio: AjustePresupuestoCicloRepositorioMemoria(),
          ingresoExtraRepositorio: IngresoExtraRepositorioMemoria(const []),
          alVerCategoria: (_) {},
          alVerGastos: () {},
          alVerMeta: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Llevas gastado'), findsOneWidget);
      // Recorre la pantalla completa para que cada bloque se construya.
      await tester.scrollUntilVisible(find.text('Tarjeta y efectivo'), 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
