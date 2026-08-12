import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/evolucion_ciclos.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/historial_ciclos.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:test/test.dart';

const _calc = CalculadoraCiclo(1); // cortes de mes natural

Ciclo _ciclo(int mes, {int anio = 2026}) => _calc.calcularPara(DateTime(anio, mes, 15));

const _gastadoDefault = Dinero.pesos(50000);

SnapshotCiclo _snap({
  required String cicloId,
  required Dinero meta,
  required Dinero apartado,
  Dinero totalGastado = _gastadoDefault,
  Dinero extraAApartado = const Dinero.cero(),
}) =>
    SnapshotCiclo(
      cicloId: cicloId,
      fechaCierre: DateTime(2026, 1, 1),
      ingresoTotal: totalGastado + apartado,
      metaApartado: meta,
      totalGastado: totalGastado,
      renglones: const [],
      extraAApartado: extraAApartado,
    );

CicloResumen _cerrado(
  int mes, {
  required Dinero meta,
  required Dinero apartado,
  Dinero totalGastado = _gastadoDefault,
  Dinero ingresoExtra = const Dinero.cero(),
}) {
  final ciclo = _ciclo(mes);
  return CicloResumen(
    ciclo: ciclo,
    snapshot: _snap(
      cicloId: ciclo.id,
      meta: meta,
      apartado: apartado,
      totalGastado: totalGastado,
      extraAApartado: ingresoExtra,
    ),
    totalGastado: totalGastado,
    ingresoExtra: ingresoExtra,
  );
}

CicloResumen _sinCierre(
  int mes, {
  Dinero totalGastado = const Dinero.pesos(300),
  Dinero ingresoExtra = const Dinero.cero(),
}) {
  final ciclo = _ciclo(mes);
  return CicloResumen(
    ciclo: ciclo,
    snapshot: null,
    totalGastado: totalGastado,
    ingresoExtra: ingresoExtra,
  );
}

InsumosCicloEnCurso _enCurso(
  int mes, {
  required Dinero meta,
  required Dinero apartado,
  Dinero totalGastado = _gastadoDefault,
  Dinero extraAApartado = const Dinero.cero(),
  Dinero extraAGasto = const Dinero.cero(),
}) =>
    InsumosCicloEnCurso(
      ciclo: _ciclo(mes),
      ingresoTotal: totalGastado + apartado,
      totalGastado: totalGastado,
      meta: meta,
      extraAApartado: extraAApartado,
      extraAGasto: extraAGasto,
    );

void main() {
  group('calcularEvolucionCiclos', () {
    test('la barra se escala por monto ahorrado, no por % de alcance — metas distintas no distorsionan', () {
      // El caso reportado: una meta chica hace que un ahorro modesto
      // marque un % altísimo. Mayo ahorró menos en pesos (32,700) que
      // Junio (40,000), pero su meta (5,000) es tan chica que su alcance
      // (654%) sería, con la escala vieja, muchísimo más alto que el de
      // Junio (80%) — exactamente al revés de la realidad en pesos.
      final historial = [
        _cerrado(5, meta: const Dinero.pesos(5000), apartado: const Dinero.pesos(32700)), // 654%
        _cerrado(6, meta: const Dinero.pesos(50000), apartado: const Dinero.pesos(40000)), // 80%
      ];

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null);

      expect(evolucion.puntos.map((p) => p.etiqueta).toList(), ['May', 'Jun'],
          reason: 'orden ascendente por fechaInicio');

      final mayo = evolucion.puntos[0];
      final junio = evolucion.puntos[1];
      expect((mayo.metricas!.alcance! * 100).round(), 654);
      expect((junio.metricas!.alcance! * 100).round(), 80);

      // maxMonto = max(32700, 40000, meta de referencia 50000) = 50000.
      expect(mayo.alturaRelativa, closeTo(32700 / 50000, 0.0001));
      expect(junio.alturaRelativa, closeTo(40000 / 50000, 0.0001));
      expect(junio.alturaRelativa, greaterThan(mayo.alturaRelativa),
          reason: 'Junio ahorró más dinero (40,000 vs 32,700) aunque su alcance % (80%) '
              'sea mucho menor que el de Mayo (654%) — la barra debe reflejar los pesos, no el %');

      expect(evolucion.metaReferencia, const Dinero.pesos(50000), reason: 'meta del último ciclo cerrado');
      expect(evolucion.alturaMeta, closeTo(1.0, 0.0001), reason: 'la meta de referencia es el monto más alto');

      expect(evolucion.ciclosAcumulados, 2);
      expect(evolucion.acumulado, const Dinero.pesos(32700) + const Dinero.pesos(40000));
      expect(evolucion.hayDatos, isTrue);
    });

    test('la barra más alta —entre lo ahorrado y la meta— llega al techo del carril', () {
      const meta = Dinero.pesos(1000);
      final historial = [_cerrado(1, meta: meta, apartado: const Dinero.pesos(2500))]; // ahorró 2.5x la meta

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null);

      expect(evolucion.alturaMeta, closeTo(0.4, 0.0001), reason: 'meta 1000 / máximo 2500');
      expect(evolucion.puntos.single.alturaRelativa, closeTo(1.0, 0.0001),
          reason: 'lo ahorrado es el monto más alto, así que llega exacto al techo del carril');
    });

    test('un ciclo en curso que ahorró mucho también reescala los cerrados', () {
      const meta = Dinero.pesos(1000);
      final historial = [_cerrado(1, meta: meta, apartado: const Dinero.pesos(500))];
      final enCurso = _enCurso(2, meta: meta, apartado: const Dinero.pesos(3000));

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: enCurso);

      expect(evolucion.alturaMeta, closeTo(1 / 3, 0.0001));
      expect(evolucion.puntos.first.alturaRelativa, closeTo(500 / 3000, 0.0001));
      expect(evolucion.puntos.last.estado, EstadoPunto.enCurso);
      expect(evolucion.puntos.last.alturaRelativa, closeTo(1.0, 0.0001));
      // Divergencia deliberada: el ciclo en curso no se agrega.
      expect(evolucion.ciclosAcumulados, 1);
      expect(evolucion.acumulado, const Dinero.pesos(500));
      expect(evolucion.metaReferencia, meta, reason: 'con ciclo en curso, su meta manda sobre la del último cerrado');
    });

    test('puntos sinCierre quedan excluidos de acumulado y promedio, pero se marcan si tuvieron extra', () {
      final historial = [
        _sinCierre(4, ingresoExtra: const Dinero.pesos(500)),
        _cerrado(5, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)), // 50%
      ];

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null);

      final sinCierre = evolucion.puntos.firstWhere((p) => p.estado == EstadoPunto.sinCierre);
      expect(sinCierre.metricas, isNull);
      expect(sinCierre.meta, isNull);
      expect(sinCierre.tuvoIngresoExtra, isTrue, reason: 'regla no negociable #14');
      expect(sinCierre.alturaRelativa, closeTo(evolucion.alturaMeta, 0.0001),
          reason: 'barra hueca a la altura de la meta');

      expect(evolucion.ciclosAcumulados, 1);
      expect(evolucion.acumulado, const Dinero.pesos(500));
      expect(evolucion.promedioAhorroPorMes, const Dinero.pesos(500));
    });

    test('meta en cero: el cerrado cuenta para el acumulado y para el promedio de ahorro', () {
      final historial = [
        _cerrado(1, meta: const Dinero.cero(), apartado: const Dinero.pesos(500)),
        _cerrado(2, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(800)), // 80%
      ];

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null);

      final metaCero = evolucion.puntos.first;
      expect(metaCero.metricas!.alcance, isNull, reason: 'sin meta no hay % contra qué medir');
      expect(metaCero.alturaRelativa, closeTo(500 / 1000, 0.0001),
          reason: 'la barra sigue siendo el monto ahorrado aunque no haya meta con qué compararlo');

      expect(evolucion.ciclosAcumulados, 2, reason: 'ambos son cerrado, meta cero no los excluye del conteo');
      expect(evolucion.acumulado, const Dinero.pesos(500) + const Dinero.pesos(800));
      expect(evolucion.promedioAhorroPorMes, const Dinero.pesos(650),
          reason: 'promedio de monto, no de %: meta cero ya no excluye el ciclo del promedio');
    });

    test('monto ahorrado negativo (se gastó más de lo que entró) se dibuja en cero', () {
      final historial = [_cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(-500))];

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null);

      expect(evolucion.alturaMeta, closeTo(1.0, 0.0001),
          reason: 'sin ahorros positivos, la meta de referencia es el único monto y marca el techo');
      expect(evolucion.puntos.single.alturaRelativa, 0);
    });

    test('histórico vacío y sin ciclo en curso regresa una evolución sin datos, no lanza', () {
      final evolucion = calcularEvolucionCiclos(historial: const [], enCurso: null);

      expect(evolucion.puntos, isEmpty);
      expect(evolucion.acumulado, const Dinero.cero());
      expect(evolucion.ciclosAcumulados, 0);
      expect(evolucion.promedioAhorroPorMes, isNull);
      expect(evolucion.metaReferencia, isNull);
      expect(evolucion.alturaMeta, 0.0, reason: 'sin meta de referencia no hay contra qué escalar');
      expect(evolucion.hayDatos, isFalse);
    });

    test('recorte a maximoPuntos se queda con los más recientes', () {
      final historial = [
        for (var mes = 1; mes <= 5; mes++)
          _cerrado(mes, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)),
      ];

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null, maximoPuntos: 3);

      expect(evolucion.puntos, hasLength(3));
      expect(evolucion.puntos.map((p) => p.etiqueta).toList(), ['Mar', 'Abr', 'May']);
    });

    test('orden ascendente aunque el historial llegue desordenado', () {
      final historial = [
        _cerrado(7, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)),
        _cerrado(5, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)),
        _cerrado(6, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)),
      ];

      final evolucion = calcularEvolucionCiclos(historial: historial, enCurso: null);

      expect(evolucion.puntos.map((p) => p.etiqueta).toList(), ['May', 'Jun', 'Jul']);
    });
  });

  group('fraseEvolucion', () {
    test('sin cerrados regresa null', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [_sinCierre(1)],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), isNull);
    });

    test('un solo cerrado regresa null — no hay con qué comparar', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [_cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500))],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), isNull);
    });

    test('dos cerrados seguidos en meta', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [
          _cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(1000)), // 100%
          _cerrado(2, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(1200)), // 120%
        ],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), 'Dos ciclos seguidos en meta.');
    });

    test('el último cerrado mejor que el previo', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [
          _cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)), // 50%
          _cerrado(2, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(800)), // 80%
        ],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), 'Mejoraste 30 puntos respecto a Ene.');
    });

    test('el último cerrado peor que el previo', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [
          _cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(900)), // 90%
          _cerrado(2, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(600)), // 60%
        ],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), 'Feb costó más que Ene.');
    });

    test('meta en cero en alguno de los dos últimos cerrados no arma frase', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [
          _cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)),
          _cerrado(2, meta: const Dinero.cero(), apartado: const Dinero.pesos(500)),
        ],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), isNull);
    });

    test('empate entre el último y el previo no arma frase', () {
      final evolucion = calcularEvolucionCiclos(
        historial: [
          _cerrado(1, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)), // 50%
          _cerrado(2, meta: const Dinero.pesos(1000), apartado: const Dinero.pesos(500)), // 50%
        ],
        enCurso: null,
      );
      expect(fraseEvolucion(evolucion), isNull);
    });
  });
}
