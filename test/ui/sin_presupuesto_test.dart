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

// Categorías sin presupuesto: solo registrar (spec-app-finanzas-v2.md §7.3.6).

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

Future<void> _montar(WidgetTester tester, List<Categoria> categorias, List<Movimiento> gastos) async {
  await tester.pumpWidget(MaterialApp(
    home: PantallaInicio(
      perfil: _perfil,
      categoriaRepositorio: CategoriaRepositorioMemoria(categorias),
      movimientoRepositorio: MovimientoRepositorioMemoria(gastos),
      reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
      cicloRepositorio: CicloRepositorioMemoria(),
      ingresoExtraRepositorio: IngresoExtraRepositorioMemoria(const []),
      ajustePresupuestoCicloRepositorio: AjustePresupuestoCicloRepositorioMemoria(),
      perfilRepositorio: PerfilRepositorioMemoria(_perfil),
      servicioAuth: ServicioAuth(),
      almacenLocal: AlmacenLocal.sobre({for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()}),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('solo registro: lo gastado y lo que entró, sin barras ni "te pasaste"', (tester) async {
    await _montar(tester, [_var('Súper', 0), _var('Salidas', 0)], [_gasto('Súper', 1500), _gasto('Salidas', 600)]);

    expect(find.text('Llevas gastado'), findsOneWidget);
    expect(find.textContaining(r'Entró $20,000'), findsOneWidget);
    expect(find.textContaining('Te pasaste'), findsNothing);
    expect(find.textContaining(r'de $0'), findsNothing);
    expect(find.text('En qué se va'), findsOneWidget);
    expect(find.text(r'Llevas $1,500'), findsOneWidget);
    expect(find.text('Sin presupuesto'), findsNWidgets(2));
  });

  testWidgets('mixto: solo se compara lo que tiene presupuesto; lo demás va aparte', (tester) async {
    await _montar(tester, [_var('Súper', 1000), _var('Café', 0)], [_gasto('Súper', 400), _gasto('Café', 900)]);

    expect(find.text('Presupuesto'), findsOneWidget);
    expect(find.text(r'Quedan $600'), findsWidgets);
    expect(find.text(r'Además, $900 en categorías sin presupuesto'), findsOneWidget);
    expect(find.textContaining('Te pasaste'), findsNothing, reason: r'los $900 sin presupuesto no son exceso');
  });
}
