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

// Navegación nueva (docs/rediseno/plan-rediseno.md, Etapa 2): cuatro raíces
// sin flecha ←, Patrimonio en la barra y el banner de "te pasaste" en Inicio.

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));

CategoriaVariable _var(String id, int presupuesto) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(presupuesto),
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
  testWidgets('pestañas raíz, banner de exceso y Patrimonio en la barra', (tester) async {
    // Pantalla de iPhone: el presupuesto entra sin desplazar.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final almacen = AlmacenLocal.sobre({for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()});
    await tester.pumpWidget(MaterialApp(
      home: PantallaInicio(
        perfil: _perfil,
        categoriaRepositorio: CategoriaRepositorioMemoria([_var('Salidas', 1000), _var('Auto', 5000)]),
        movimientoRepositorio: MovimientoRepositorioMemoria([_gasto('Salidas', 1600)]),
        reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
        cicloRepositorio: CicloRepositorioMemoria(),
        ingresoExtraRepositorio: IngresoExtraRepositorioMemoria(const []),
        ajustePresupuestoCicloRepositorio: AjustePresupuestoCicloRepositorioMemoria(),
        perfilRepositorio: PerfilRepositorioMemoria(_perfil),
        servicioAuth: ServicioAuth(),
        almacenLocal: almacen,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Llevas gastado'), findsOneWidget);
    expect(find.text(r'Te pasaste en Salidas por $600'), findsOneWidget);
    // Sin historial, el MPC estima que Auto usará todo su presupuesto: no
    // hay de dónde cubrir y la salida es ver la categoría.
    expect(find.text('Ver Salidas'), findsOneWidget);
    // Lo que necesita atención va primero.
    expect(tester.getTopLeft(find.text('Salidas').first).dy, lessThan(tester.getTopLeft(find.text('Auto').last).dy));
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.text('Patrimonio'));
    await tester.pumpAndSettle();
    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('Objetivos'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.text('Gastos').last);
    await tester.pumpAndSettle();
    expect(find.text('Buscar gasto o monto'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });
}
