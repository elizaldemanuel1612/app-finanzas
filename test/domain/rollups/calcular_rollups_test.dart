import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:app_finanzas/domain/rollups/calcular_rollups.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);

CategoriaVariable _variable(String id, int presupuesto) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(presupuesto),
    );

CategoriaFija _fija(String id, int monto) => CategoriaFija(
      id: id,
      nombre: id,
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(monto),
      diaDelCiclo: 1,
    );

Movimiento _mov(
  String clientId,
  String categoriaId,
  int pesos, {
  DateTime? fecha,
  EstadoMovimiento estado = EstadoMovimiento.activo,
  OrigenCaptura origen = OrigenCaptura.manual,
}) {
  final r = crearMovimiento(
    clientId: clientId,
    fecha: fecha ?? DateTime(2026, 7, 15),
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(pesos),
    categoriaId: categoriaId,
    medio: MedioPago.tarjeta,
    descripcion: categoriaId,
    origenCaptura: origen,
  ) as Exito<Movimiento>;
  return r.valor.copyWith(estado: estado);
}

void main() {
  group('calcularRollups', () {
    test('suma solo los movimientos activos del ciclo pedido', () {
      final movimientos = [
        _mov('a12345678', 'super', 300),
        _mov('b12345678', 'super', 200),
        _mov('c12345678', 'super', 999, fecha: DateTime(2026, 6, 15)), // otro ciclo
      ];
      final rollups = calcularRollups(
        movimientos: movimientos,
        categorias: [_variable('super', 8000)],
        cicloId: '2026-07',
      );
      expect(rollups.single.totalCentavos, const Dinero.pesos(500));
      expect(rollups.single.conteoMovimientos, 2);
    });

    test('excluye movimientos anulados', () {
      final movimientos = [
        _mov('a12345678', 'super', 300),
        _mov('b12345678', 'super', 200, estado: EstadoMovimiento.anulado),
      ];
      final rollups = calcularRollups(
        movimientos: movimientos,
        categorias: [_variable('super', 8000)],
        cicloId: '2026-07',
      );
      expect(rollups.single.totalCentavos, const Dinero.pesos(300));
      expect(rollups.single.conteoMovimientos, 1);
    });

    test('excluye movimientos propuestos (regla no negociable #18)', () {
      final movimientos = [
        _mov('a12345678', 'vivienda', 9910, origen: OrigenCaptura.recurrente, estado: EstadoMovimiento.propuesto),
      ];
      final rollups = calcularRollups(
        movimientos: movimientos,
        categorias: [_fija('vivienda', 9910)],
        cicloId: '2026-07',
      );
      expect(rollups.single.totalCentavos, const Dinero.cero());
      expect(rollups.single.conteoMovimientos, 0);
    });

    test('una categoría sin movimientos da rollup en cero, no se omite', () {
      final rollups = calcularRollups(
        movimientos: const [],
        categorias: [_variable('salud', 1000)],
        cicloId: '2026-07',
      );
      expect(rollups.single.totalCentavos, const Dinero.cero());
      expect(rollups.single.conteoMovimientos, 0);
    });

    test('una fija lleva su monto fijo como presupuestoCentavos de referencia', () {
      final rollups = calcularRollups(
        movimientos: const [],
        categorias: [_fija('spotify', 239)],
        cicloId: '2026-07',
      );
      expect(rollups.single.presupuestoCentavos, const Dinero.pesos(239));
    });

    test('varias categorías se calculan por separado, sin mezclarse', () {
      final movimientos = [
        _mov('a12345678', 'super', 300),
        _mov('b12345678', 'auto', 150),
      ];
      final rollups = calcularRollups(
        movimientos: movimientos,
        categorias: [_variable('super', 8000), _variable('auto', 3800)],
        cicloId: '2026-07',
      );
      final porSuper = rollups.firstWhere((r) => r.categoriaId == 'super');
      final porAuto = rollups.firstWhere((r) => r.categoriaId == 'auto');
      expect(porSuper.totalCentavos, const Dinero.pesos(300));
      expect(porAuto.totalCentavos, const Dinero.pesos(150));
    });

    test('movimientos de una categoría que ya no existe no rompen el cálculo', () {
      final movimientos = [_mov('a12345678', 'categoria_borrada', 500)];
      final rollups = calcularRollups(
        movimientos: movimientos,
        categorias: [_variable('super', 8000)],
        cicloId: '2026-07',
      );
      expect(rollups.single.categoriaId, 'super');
      expect(rollups.single.totalCentavos, const Dinero.cero());
    });
  });

  group('rendimiento (criterio de aceptación de la Fase 2)', () {
    test('5,000 movimientos se procesan muy por debajo de 300ms', () {
      final categorias = List.generate(20, (i) => _variable('cat_$i', 5000));
      final movimientos = List.generate(5000, (i) {
        final cat = 'cat_${i % 20}';
        return _mov('mov-${i.toString().padLeft(6, '0')}', cat, 100 + (i % 50));
      });

      final cronometro = Stopwatch()..start();
      final rollups = calcularRollups(
        movimientos: movimientos,
        categorias: categorias,
        cicloId: '2026-07',
      );
      cronometro.stop();

      expect(rollups, hasLength(20));
      expect(
        cronometro.elapsedMilliseconds,
        lessThan(300),
        reason: 'calcularRollups tardó ${cronometro.elapsedMilliseconds}ms con 5,000 movimientos',
      );
    });
  });
}
