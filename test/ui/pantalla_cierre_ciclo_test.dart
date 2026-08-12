import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/ciclo/pantalla_cierre_ciclo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Reproduce el bug reportado: un ciclo cuyo CicloGuardado quedó marcado
// "cerrado" en el repositorio sin un snapshot que lo respalde (estado
// inconsistente — el flujo normal de cierre/reapertura siempre empareja
// `cerrado` con un snapshot, pero datos viejos o corruptos pueden no
// hacerlo). Antes del fix, PantallaCierreCiclo delegaba en
// `calcularSnapshotCierre`, que llama `Ciclo.cerrar()` como guarda y falla
// con "ya está cerrado" — dejando la pantalla en un callejón sin salida
// (solo el mensaje de error, sin datos ni botón de recuperación), mientras
// que `PantallaCiclosAnteriores` (que no confía en la bandera sin
// snapshot) reconstruye el mismo ciclo como abierto.
void main() {
  testWidgets(
    'PantallaCierreCiclo recalcula en vivo un ciclo "cerrado" sin snapshot en vez de bloquearse',
    (tester) async {
      final ciclo = Ciclo(
        id: '2026-06',
        fechaInicio: DateTime(2026, 6, 1),
        fechaFin: DateTime(2026, 6, 30),
        etiqueta: 'Jun',
        estado: EstadoCiclo.cerrado,
      );

      final categoria = const CategoriaVariable(
        id: 'cat-comida',
        nombre: 'Comida',
        emoji: '🍔',
        activa: true,
        esNecesaria: true,
        presupuestoMensualCentavos: Dinero(500000),
      );

      final movimiento = Movimiento(
        id: 'm1',
        clientId: 'm1',
        fecha: DateTime(2026, 6, 15),
        cicloId: '2026-06',
        periodoNatural: '2026-06',
        monto: const Dinero(15000),
        categoriaId: 'cat-comida',
        medio: MedioPago.tarjeta,
        descripcion: 'Súper',
        estado: EstadoMovimiento.activo,
        origenCaptura: OrigenCaptura.manual,
      );

      final cicloGuardadoCorrupto = CicloGuardado(ciclo: ciclo, snapshot: null);

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaCierreCiclo(
            ciclo: ciclo,
            perfil: const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero(2000000)),
            categoriaRepositorio: CategoriaRepositorioMemoria([categoria]),
            movimientoRepositorio: MovimientoRepositorioMemoria([movimiento]),
            cicloRepositorio: CicloRepositorioMemoria([cicloGuardadoCorrupto]),
            ingresoExtraRepositorio: IngresoExtraRepositorioMemoria([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('ya está cerrado'),
        findsNothing,
        reason: 'No debe dejar la pantalla en el mensaje crudo de Ciclo.cerrar()',
      );
      // El gasto de junio sí debe reflejarse en el total recalculado.
      expect(find.textContaining('\$150.00'), findsWidgets);

      // El botón está más abajo en la lista (después de "Presupuesto vs.
      // real"): hay que desplazarse para que ListView lo construya.
      await tester.scrollUntilVisible(
        find.text('Cerrar ciclo'),
        300,
        scrollable: find.byType(Scrollable),
      );
      // Con datos recalculados en vivo, el botón debe ofrecer cerrar el
      // ciclo (no "Reabrir ciclo", que implicaría que hay algo congelado
      // que proteger).
      expect(find.text('Cerrar ciclo'), findsOneWidget);
      expect(find.text('Reabrir ciclo'), findsNothing);
    },
  );
}
