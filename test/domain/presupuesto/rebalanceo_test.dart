import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/rebalanceo.dart';
import 'package:app_finanzas/domain/pronostico/nivel_madurez.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_categoria.dart';
import 'package:app_finanzas/domain/pronostico/subcaptura.dart';
import 'package:test/test.dart';

CategoriaVariable _cat(String id, String nombre, {required Dinero presupuesto}) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🏷️',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: presupuesto,
    );

PronosticoCategoria _pron(String categoriaId, {required Dinero observado, required Dinero p50}) =>
    PronosticoCategoria(
      categoriaId: categoriaId,
      cicloId: '2026-07',
      tipo: TipoMpc.variableFrecuente,
      observado: observado,
      base: observado,
      atipico: const Dinero.cero(),
      comprometido: const Dinero.cero(),
      avanceEfectivo: 0.6,
      pronosticoP50: p50,
      pronosticoP10: p50,
      pronosticoP90: p50,
      confianza: ConfianzaMpc.media,
      senalSubcaptura: SenalSubcaptura.normal,
      nivelMadurez: NivelMadurezMpc.atipicosYCredibilidad,
      explicacion: const [],
    );

void main() {
  group('calcularRebalanceo — cuándo se dispara (§2.5)', () {
    test('no se dispara si la categoría objetivo no se ha pasado del presupuesto', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final r = calcularRebalanceo(
        categoriaObjetivo: objetivo,
        pronosticoObjetivo: _pron('salidas', observado: const Dinero.pesos(1500), p50: const Dinero.pesos(1900)),
        otrasCategorias: const [],
        otrosPronosticos: const [],
      );
      expect(r, isNull);
    });

    test('se dispara cuando ya se gastó más del presupuesto', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final r = calcularRebalanceo(
        categoriaObjetivo: objetivo,
        pronosticoObjetivo: _pron('salidas', observado: const Dinero.pesos(2300), p50: const Dinero.pesos(2600)),
        otrasCategorias: const [],
        otrosPronosticos: const [],
      );
      expect(r, isNotNull);
      expect(r!.categoriaObjetivoId, 'salidas');
      expect(r.faltante, const Dinero.pesos(600)); // 2600 - 2000
    });
  });

  group('calcularRebalanceo — holguras y top 3 (§2.5)', () {
    final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
    final pronosticoObjetivo =
        _pron('salidas', observado: const Dinero.pesos(2300), p50: const Dinero.pesos(2600));

    test('ordena las candidatas de mayor a menor holgura y se queda con las 3 mayores', () {
      final categorias = [
        _cat('super', 'Súper/Comida', presupuesto: const Dinero.pesos(6000)),
        _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800)),
        _cat('terapia', 'Terapia', presupuesto: const Dinero.pesos(500)),
        _cat('limpieza', 'Limpieza', presupuesto: const Dinero.pesos(800)),
      ];
      final pronosticos = [
        _pron('super', observado: const Dinero.pesos(4000), p50: const Dinero.pesos(5000)), // holgura 1000
        _pron('auto', observado: const Dinero.pesos(3000), p50: const Dinero.pesos(3200)), // holgura 1600
        _pron('terapia', observado: const Dinero.pesos(400), p50: const Dinero.pesos(450)), // holgura 50
        _pron('limpieza', observado: const Dinero.pesos(800), p50: const Dinero.pesos(800)), // holgura 0, excluida
      ];

      final r = calcularRebalanceo(
        categoriaObjetivo: objetivo,
        pronosticoObjetivo: pronosticoObjetivo,
        otrasCategorias: categorias,
        otrosPronosticos: pronosticos,
      );

      expect(r, isNotNull);
      expect(r!.candidatas, hasLength(3));
      expect(r.candidatas[0].categoria.id, 'auto'); // 1600
      expect(r.candidatas[1].categoria.id, 'super'); // 1000
      expect(r.candidatas[2].categoria.id, 'terapia'); // 50
    });

    test('con más de 3 candidatas con holgura, solo regresa las 3 mayores', () {
      final categorias = List.generate(
        5,
        (i) => _cat('c$i', 'Cat $i', presupuesto: const Dinero.pesos(1000)),
      );
      final pronosticos = [
        for (var i = 0; i < 5; i++)
          _pron('c$i', observado: const Dinero.pesos(100), p50: Dinero.pesos(100 * (i + 1))),
      ];
      final r = calcularRebalanceo(
        categoriaObjetivo: objetivo,
        pronosticoObjetivo: pronosticoObjetivo,
        otrasCategorias: categorias,
        otrosPronosticos: pronosticos,
      );
      expect(r!.candidatas, hasLength(3));
    });

    test('una categoría sin pronóstico calculado no entra como candidata', () {
      final categorias = [_cat('sin_pronostico', 'Otros', presupuesto: const Dinero.pesos(1000))];
      final r = calcularRebalanceo(
        categoriaObjetivo: objetivo,
        pronosticoObjetivo: pronosticoObjetivo,
        otrasCategorias: categorias,
        otrosPronosticos: const [], // sin match para 'sin_pronostico'
      );
      expect(r!.candidatas, isEmpty);
    });
  });

  group('aplicarRebalanceo — mueve presupuesto y deja auditoría (§2.5)', () {
    test('resta del origen, suma al objetivo, y registra dos entradas de auditoría', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final origen = _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800));
      final cuando = DateTime(2026, 7, 20, 10, 30);

      final resultado = aplicarRebalanceo(
        objetivo: objetivo,
        origenes: [origen],
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(600))],
        cuando: cuando,
        dispositivo: 'Pixel 7 (prueba)',
      );

      expect(resultado.esExito, isTrue);
      final r = resultado.valorOLanza;
      expect(r.objetivoActualizada.presupuestoMensualCentavos, const Dinero.pesos(2600));
      expect(r.origenesActualizadas.single.presupuestoMensualCentavos, const Dinero.pesos(4200));
      expect(r.auditoria, hasLength(2));
      expect(r.auditoria.every((a) => a.cuando == cuando), isTrue);
    });

    test('mover desde dos orígenes a la vez suma correctamente al objetivo', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final origenes = [
        _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800)),
        _cat('super', 'Súper/Comida', presupuesto: const Dinero.pesos(6000)),
      ];
      final resultado = aplicarRebalanceo(
        objetivo: objetivo,
        origenes: origenes,
        movimientos: const [
          MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(400)),
          MovimientoRebalanceo(categoriaOrigenId: 'super', monto: Dinero.pesos(200)),
        ],
        cuando: DateTime(2026, 7, 20),
        dispositivo: 'prueba',
      );
      expect(resultado.valorOLanza.objetivoActualizada.presupuestoMensualCentavos, const Dinero.pesos(2600));
      expect(resultado.valorOLanza.auditoria, hasLength(3)); // 2 orígenes + 1 objetivo
    });

    test('falla si el monto a mover no es positivo', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final origen = _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800));
      final resultado = aplicarRebalanceo(
        objetivo: objetivo,
        origenes: [origen],
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.cero())],
        cuando: DateTime(2026, 7, 20),
        dispositivo: 'prueba',
      );
      expect(resultado.esFalla, isTrue);
    });

    test('falla si el movimiento dejaría al origen con presupuesto en cero o negativo', () {
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final origen = _cat('terapia', 'Terapia', presupuesto: const Dinero.pesos(500));
      final resultado = aplicarRebalanceo(
        objetivo: objetivo,
        origenes: [origen],
        // Intenta mover más de lo que Terapia tiene de presupuesto.
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'terapia', monto: Dinero.pesos(500))],
        cuando: DateTime(2026, 7, 20),
        dispositivo: 'prueba',
      );
      expect(resultado.esFalla, isTrue);
    });

    test('nunca toca movimientos ya registrados — solo produce categorías y auditoría', () {
      // Prueba de forma: el tipo de retorno de aplicarRebalanceo no
      // incluye ningún Movimiento, por construcción — solo categorías y
      // auditoría (regla dura de §2.5).
      final objetivo = _cat('salidas', 'Salidas/Diversión', presupuesto: const Dinero.pesos(2000));
      final origen = _cat('auto', 'Auto operación', presupuesto: const Dinero.pesos(4800));
      final resultado = aplicarRebalanceo(
        objetivo: objetivo,
        origenes: [origen],
        movimientos: const [MovimientoRebalanceo(categoriaOrigenId: 'auto', monto: Dinero.pesos(100))],
        cuando: DateTime(2026, 7, 20),
        dispositivo: 'prueba',
      );
      expect(resultado.valorOLanza, isA<ResultadoRebalanceo>());
    });
  });
}
