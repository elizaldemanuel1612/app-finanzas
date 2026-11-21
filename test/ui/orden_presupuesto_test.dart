import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/firebase/servicio_auth.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/inicio/pantalla_inicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Ordenar el presupuesto de Inicio (spec-app-finanzas-v2.md §5.6.4).

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));

CategoriaVariable _var(String id) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: const Dinero.pesos(1000),
    );

Movimiento _gasto(String categoria, int pesos) {
  final hoy = DateTime.now();
  return conId(Movimiento(
    clientId: 'movimiento-$categoria',
    fecha: hoy,
    cicloId: CalculadoraCiclo(_perfil.diaCorte).calcularPara(hoy).id,
    periodoNatural: periodoNatural(hoy),
    monto: Dinero.pesos(pesos),
    categoriaId: categoria,
    medio: MedioPago.tarjeta,
    descripcion: categoria,
    estado: EstadoMovimiento.activo,
    origenCaptura: OrigenCaptura.manual,
  ));
}

void main() {
  testWidgets('Ordenar: por nombre se aplica y se guarda; Mi orden se arrastra', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final perfiles = PerfilRepositorioMemoria(_perfil);
    await tester.pumpWidget(MaterialApp(
      home: PantallaInicio(
        perfil: _perfil,
        categoriaRepositorio: CategoriaRepositorioMemoria([_var('Auto'), _var('Café'), _var('Súper')]),
        movimientoRepositorio: MovimientoRepositorioMemoria([_gasto('Súper', 900), _gasto('Auto', 100)]),
        reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
        cicloRepositorio: CicloRepositorioMemoria(),
        ingresoExtraRepositorio: IngresoExtraRepositorioMemoria(const []),
        ajustePresupuestoCicloRepositorio: AjustePresupuestoCicloRepositorioMemoria(),
        perfilRepositorio: perfiles,
        servicioAuth: ServicioAuth(),
        almacenLocal: AlmacenLocal.sobre({for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()}),
      ),
    ));
    await tester.pumpAndSettle();

    double y(String nombre) => tester.getTopLeft(find.text(nombre).first).dy;
    // De fábrica: lo que necesita atención (Súper va al 90 %).
    expect(y('Súper'), lessThan(y('Auto')));

    await tester.tap(find.byTooltip('Ordenar'));
    await tester.pumpAndSettle();
    expect(find.text('Ordenar presupuesto'), findsOneWidget);
    await tester.tap(find.text('Por nombre'));
    await tester.pumpAndSettle();
    expect(y('Auto'), lessThan(y('Café')));
    expect(y('Café'), lessThan(y('Súper')));
    expect((await perfiles.obtener())!.ordenPresupuesto, 'nombre');

    await tester.tap(find.byTooltip('Ordenar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi orden'));
    await tester.pumpAndSettle();
    // Arranca con lo que se ve; Súper sube hasta arriba.
    final asa = find.byIcon(Icons.drag_handle).last;
    await tester.timedDrag(asa, const Offset(0, -200), const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar mi orden'));
    await tester.pumpAndSettle();
    final guardado = (await perfiles.obtener())!;
    expect(guardado.ordenPresupuesto, 'propio');
    expect(guardado.ordenPropio.first, 'Súper');
    expect(y('Súper'), lessThan(y('Auto')));
  });
}
