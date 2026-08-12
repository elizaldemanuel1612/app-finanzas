import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/alcance.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/evolucion_ciclos.dart';
import 'package:app_finanzas/domain/rollups/estado_ritmo.dart';
import 'package:app_finanzas/ui/comun/barra_ritmo.dart';
import 'package:app_finanzas/ui/comun/grafica_evolucion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Verifica los `semanticsLabel` clave de accesibilidad (Fase 6, Bloque 4.3):
// BarraRitmo y GraficaEvolucion no tenían ningún `Semantics` antes de este
// bloque — un lector de pantalla se topaba con un `Container` sin nombre.

PuntoEvolucion _puntoCerrado({
  required String cicloId,
  required String etiqueta,
  required int apartadoPesos,
  required double alcance,
}) =>
    PuntoEvolucion(
      cicloId: cicloId,
      etiqueta: etiqueta,
      estado: EstadoPunto.cerrado,
      metricas: MetricasApartado(
        apartado: Dinero.pesos(apartadoPesos),
        alcance: alcance,
        alcanceSinExtra: null,
        tasaDeAhorro: null,
      ),
      meta: const Dinero.pesos(1200),
      tuvoIngresoExtra: false,
      alturaRelativa: 0.5,
    );

void main() {
  testWidgets('BarraRitmo expone la categoría, el estado y los porcentajes', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BarraRitmo(
            porcentajeUsado: 0.8,
            avanceCiclo: 0.5,
            estado: EstadoRitmo.excedido,
            descripcion: 'Súper/Comida',
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Ritmo de Súper/Comida: Excedido. Llevas 80% del presupuesto; '
        'a estas alturas del ciclo deberías ir en 50%.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('GraficaEvolucion resume el ciclo con más y con menos apartado', (tester) async {
    final handle = tester.ensureSemantics();

    final evolucion = EvolucionCiclos(
      puntos: [
        _puntoCerrado(cicloId: '2026-01', etiqueta: 'Ene', apartadoPesos: 1000, alcance: 0.8),
        _puntoCerrado(cicloId: '2026-02', etiqueta: 'Feb', apartadoPesos: 2000, alcance: 1.2),
      ],
      acumulado: const Dinero.pesos(3000),
      ciclosAcumulados: 2,
      promedioAhorroPorMes: const Dinero.pesos(1500),
      metaReferencia: const Dinero.pesos(1200),
      alturaMeta: 0.7,
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GraficaEvolucion(evolucion: evolucion))),
    );

    expect(
      find.bySemanticsLabel(
        'Gráfica de cuánto has apartado por ciclo: 2 ciclos cerrados; '
        'apartaste más en Feb con \$2,000.00, menos en Ene con \$1,000.00; '
        'promedio de ahorro por mes \$1,500.00.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('GraficaEvolucion sin ciclos cerrados avisa que todavía no hay datos', (tester) async {
    final handle = tester.ensureSemantics();

    const evolucion = EvolucionCiclos(
      puntos: [],
      acumulado: Dinero.cero(),
      ciclosAcumulados: 0,
      promedioAhorroPorMes: null,
      metaReferencia: null,
      alturaMeta: 0.7,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GraficaEvolucion(evolucion: evolucion))),
    );

    expect(
      find.bySemanticsLabel('Gráfica de cuánto has apartado por ciclo, todavía sin ciclos cerrados.'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
