import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/analisis/pantalla_analisis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// "¿Cuánto pesa cada parte?" → Variables: la línea del 80/20 va justo
// debajo de las categorías que juntas llegan al 80 % (spec §5.7).

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(40000));

CategoriaVariable _var(String id, int pesos) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );

void main() {
  testWidgets('la línea del 80/20 separa las que se llevan casi todo', (tester) async {
    // 8000+8000 = 70 %; con 5000 llega a 91 % → la línea va después de 3.
    final categorias = [_var('Súper', 8000), _var('Salidas', 8000), _var('Mamá', 5000), _var('Café', 1000), _var('Libros', 1000)];
    final hoy = DateTime.now();
    final ciclo = _perfil.calculadoraCiclo.calcularPara(hoy);
    final movimientos = [
      conId(Movimiento(
        clientId: 'movimiento-1',
        fecha: hoy,
        cicloId: ciclo.id,
        periodoNatural: periodoNatural(hoy),
        monto: const Dinero.pesos(100),
        categoriaId: 'Súper',
        medio: MedioPago.tarjeta,
        descripcion: 'Súper',
        estado: EstadoMovimiento.activo,
        origenCaptura: OrigenCaptura.manual,
      )),
    ];

    await tester.pumpWidget(MaterialApp(
      home: PantallaAnalisis(
        perfil: _perfil,
        ciclo: ciclo,
        categoriaRepositorio: CategoriaRepositorioMemoria(categorias),
        movimientoRepositorio: MovimientoRepositorioMemoria(movimientos),
        ajustePresupuestoCicloRepositorio: AjustePresupuestoCicloRepositorioMemoria(),
        ingresoExtraRepositorio: IngresoExtraRepositorioMemoria(const []),
        alVerCategoria: (_) {},
        alVerGastos: () {},
        alVerMeta: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detalle'));
    await tester.pumpAndSettle();
    // La fila de vistas también se desplaza (a lo ancho): se busca en la lista.
    await tester.scrollUntilVisible(find.text('Plan contra cierre'), 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Variables').first);
    await tester.pumpAndSettle();

    final linea = find.text('↑ Estas 3 suman el 91%');
    await tester.scrollUntilVisible(linea, 200, scrollable: find.byType(Scrollable).last);
    expect(linea, findsOneWidget);
    // Debajo de Mamá (la tercera) y arriba de Café.
    expect(tester.getTopLeft(linea).dy, greaterThan(tester.getTopLeft(find.text('Mamá')).dy));
    expect(tester.getTopLeft(linea).dy, lessThan(tester.getTopLeft(find.text('Café').first).dy));
  });
}
