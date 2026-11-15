import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/cobertura_excesos.dart';
import 'package:app_finanzas/domain/presupuesto/rebalanceo.dart';
import 'package:test/test.dart';

CategoriaVariable _cat(String id, String nombre, {required Dinero presupuesto}) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🏷️',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: presupuesto,
    );

EstadoVariable _e(CategoriaVariable c, {required Dinero observado, required Dinero p50}) =>
    EstadoVariable(categoria: c, gastado: observado, proyeccion: p50);

void main() {
  group('calcularRebalanceo — cuándo se dispara (§2.5)', () {
    test('no se dispara si la categoría objetivo no se ha pasado del presupuesto', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final r = calcularRebalanceo(
        objetivo: _e(objetivo, observado: const Dinero.pesos(1500), p50: const Dinero.pesos(1900)),
        otras: const [],
      );
      expect(r, isNull);
    });

    test('se dispara cuando ya se gastó más del presupuesto', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final r = calcularRebalanceo(
        objetivo: _e(objetivo, observado: const Dinero.pesos(2300), p50: const Dinero.pesos(2600)),
        otras: const [],
      );
      expect(r, isNotNull);
      expect(r!.categoriaObjetivoId, 'salidas');
      expect(r.faltante, const Dinero.pesos(300), reason: 'lo que ya se pasó: 2300 − 2000, no el proyectado');
    });
  });

  group('calcularRebalanceo — holguras y top 3 (§2.5)', () {
    final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
    final estadoObjetivo = _e(objetivo, observado: const Dinero.pesos(2300), p50: const Dinero.pesos(2600));

    test('ordena las candidatas de mayor a menor holgura y se queda con las 3 mayores', () {
      final categorias = [
        _cat('super', 'Súper/Comida', presupuesto: const Dinero.pesos(6000)),
        _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800)),
        _cat('terapia', 'Terapia', presupuesto: const Dinero.pesos(500)),
        _cat('limpieza', 'Limpieza', presupuesto: const Dinero.pesos(800)),
      ];
      final otras = [
        _e(categorias[0], observado: const Dinero.pesos(4000), p50: const Dinero.pesos(5000)), // holgura 1000
        _e(categorias[1], observado: const Dinero.pesos(3000), p50: const Dinero.pesos(3200)), // holgura 1600
        _e(categorias[2], observado: const Dinero.pesos(400), p50: const Dinero.pesos(450)), // holgura 50
        _e(categorias[3], observado: const Dinero.pesos(800), p50: const Dinero.pesos(800)), // holgura 0, excluida
        estadoObjetivo, // la propia categoría nunca se presta a sí misma
      ];

      final r = calcularRebalanceo(objetivo: estadoObjetivo, otras: otras);

      expect(r, isNotNull);
      expect(r!.candidatas, hasLength(3));
      expect(r.candidatas[0].categoria.id, 'auto'); // 1600
      expect(r.candidatas[1].categoria.id, 'super'); // 1000
      expect(r.candidatas[2].categoria.id, 'terapia'); // 50
      // Lo disponible es presupuesto − gastado, no − pronóstico.
      expect(r.candidatas[0].disponible, const Dinero.pesos(1800)); // 4800 - 3000
      expect(r.candidatas[2].disponible, const Dinero.pesos(100)); // 500 - 400
    });

    test('con más de 3 candidatas con holgura, solo regresa las 3 mayores', () {
      final categorias = List.generate(
        5,
        (i) => _cat('c$i', 'Cat $i', presupuesto: const Dinero.pesos(1000)),
      );
      final otras = [
        for (var i = 0; i < 5; i++)
          _e(categorias[i], observado: const Dinero.pesos(100), p50: Dinero.pesos(100 * (i + 1))),
      ];
      final r = calcularRebalanceo(objetivo: estadoObjetivo, otras: otras);
      expect(r!.candidatas, hasLength(3));
    });
  });

  group('construirAjustesDeRebalanceo — deltas temporales (§2.5)', () {
    final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
    final candidataAuto = CandidataRebalanceo(
      categoria: _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800)),
      holgura: const Dinero.pesos(600),
      disponible: const Dinero.pesos(900),
    );
    final candidataSuper = CandidataRebalanceo(
      categoria: _cat('super', 'Súper/Comida', presupuesto: const Dinero.pesos(6000)),
      holgura: const Dinero.pesos(1000),
      disponible: const Dinero.pesos(1500),
    );
    final rebalanceo = Rebalanceo(
      categoriaObjetivoId: objetivo.id,
      faltante: const Dinero.pesos(600),
      candidatas: [candidataAuto, candidataSuper],
    );
    final cuando = DateTime(2026, 7, 20, 10, 30);

    test('camino feliz con 1 origen: delta negativo al origen, positivo al objetivo', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(600))],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'Pixel 7 (prueba)',
      );

      expect(resultado.esExito, isTrue);
      final ajustes = resultado.valorOLanza;
      expect(ajustes, hasLength(2));
      final deltaAuto = ajustes.firstWhere((a) => a.categoriaId == 'auto');
      final deltaObjetivo = ajustes.firstWhere((a) => a.categoriaId == 'salidas');
      expect(deltaAuto.deltaCentavos, const Dinero.pesos(-600));
      expect(deltaObjetivo.deltaCentavos, const Dinero.pesos(600));
      expect(ajustes.every((a) => a.cicloId == '2026-07' && a.cuando == cuando), isTrue);
    });

    test('camino feliz con 2 orígenes: un delta negativo por origen y uno positivo acumulado', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [
          MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(400)),
          MovimientoRebalanceo(categoriaOrigenId: 'super', monto: Dinero.pesos(200)),
        ],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );

      expect(resultado.esExito, isTrue);
      final ajustes = resultado.valorOLanza;
      expect(ajustes, hasLength(3));
      final deltaObjetivo = ajustes.firstWhere((a) => a.categoriaId == 'salidas');
      expect(deltaObjetivo.deltaCentavos, const Dinero.pesos(600));
    });

    test('falla si el monto a mover no es positivo', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.cero())],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );
      expect(resultado.esFalla, isTrue);
    });

    test('permite mover más de la holgura sugerida mientras quede disponible', () {
      // 'auto' sugiere 600 pero le quedan 900 sin gastar.
      expect(candidataAuto.excedeSugerencia(const Dinero.pesos(700)), isTrue);
      expect(candidataAuto.excedeSugerencia(const Dinero.pesos(600)), isFalse);
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(900))],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );
      expect(resultado.esExito, isTrue);
    });

    test('falla si el monto excede lo disponible (sin gastar) de la candidata', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(901))],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );
      expect(resultado.esFalla, isTrue);
    });

    test('falla si la categoría origen no está entre las candidatas', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'inexistente', monto: Dinero.pesos(100))],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );
      expect(resultado.esFalla, isTrue);
    });

    test('falla si no se ingresó ningún movimiento (todos los montos en 0)', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        movimientos: const [],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );
      expect(resultado.esFalla, isTrue);
    });

    test('permite sobre-cubrir el total: el límite es por candidata, no por suma', () {
      final resultado = construirAjustesDeRebalanceo(
        rebalanceo: rebalanceo,
        // 600 (auto) + 1000 (super) = 1600, más que el faltante de 600.
        movimientos: const [
          MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(600)),
          MovimientoRebalanceo(categoriaOrigenId: 'super', monto: Dinero.pesos(1000)),
        ],
        cicloId: '2026-07',
        cuando: cuando,
        dispositivo: 'prueba',
      );
      expect(resultado.esExito, isTrue);
      final deltaObjetivo = resultado.valorOLanza.firstWhere((a) => a.categoriaId == 'salidas');
      expect(deltaObjetivo.deltaCentavos, const Dinero.pesos(1600));
    });
  });
}
