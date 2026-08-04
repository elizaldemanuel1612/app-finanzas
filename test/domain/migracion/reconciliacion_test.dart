import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/migracion/movimiento_migrado.dart';
import 'package:app_finanzas/domain/migracion/reconciliacion.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

Movimiento _mov(String id, String categoria, int pesos, DateTime fecha) =>
    (crearMovimientoMigrado(
      idOrigen: id,
      fecha: fecha,
      calculadoraCiclo: const CalculadoraCiclo(12),
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: MedioPago.efectivo,
      descripcion: id,
    ) as Exito<Movimiento>)
        .valor;

void main() {
  group('encontrarDiferencias', () {
    test('lista vacía cuando todo cuadra al centavo', () {
      final movimientos = [
        _mov('HIST-1', 'super', 300, DateTime(2026, 5, 15)),
        _mov('HIST-2', 'super', 200, DateTime(2026, 5, 20)),
      ];
      final cicloId = const CalculadoraCiclo(12)
          .calcularPara(DateTime(2026, 5, 15))
          .id;

      final diffs = encontrarDiferencias(
        movimientosImportados: movimientos,
        totalesDeclarados: [
          TotalDeclarado(
            categoriaId: 'super',
            cicloId: cicloId,
            totalCentavos: const Dinero.pesos(500),
          ),
        ],
      );
      expect(diffs, isEmpty);
    });

    test('detecta cuando la app calcula menos de lo declarado', () {
      final movimientos = [_mov('HIST-1', 'super', 300, DateTime(2026, 5, 15))];
      final cicloId = const CalculadoraCiclo(12)
          .calcularPara(DateTime(2026, 5, 15))
          .id;

      final diffs = encontrarDiferencias(
        movimientosImportados: movimientos,
        totalesDeclarados: [
          TotalDeclarado(
            categoriaId: 'super',
            cicloId: cicloId,
            totalCentavos: const Dinero.pesos(500),
          ),
        ],
      );
      expect(diffs, hasLength(1));
      expect(diffs.single.totalDeclarado, const Dinero.pesos(500));
      expect(diffs.single.totalCalculado, const Dinero.pesos(300));
      expect(diffs.single.diferencia, const Dinero.pesos(-200));
    });

    test('los movimientos anulados no cuentan', () {
      final activo = _mov('HIST-1', 'super', 300, DateTime(2026, 5, 15));
      final anulado = activo.copyWith(estado: EstadoMovimiento.anulado);
      final cicloId = const CalculadoraCiclo(12)
          .calcularPara(DateTime(2026, 5, 15))
          .id;

      final diffs = encontrarDiferencias(
        movimientosImportados: [activo, anulado],
        totalesDeclarados: [
          TotalDeclarado(
            categoriaId: 'super',
            cicloId: cicloId,
            totalCentavos: const Dinero.pesos(300),
          ),
        ],
      );
      expect(diffs, isEmpty);
    });

    test('movimientos importados sin total declarado se marcan como diferencia', () {
      final movimientos = [_mov('HIST-1', 'salud', 100, DateTime(2026, 5, 15))];
      final diffs = encontrarDiferencias(
        movimientosImportados: movimientos,
        totalesDeclarados: const [],
      );
      expect(diffs, hasLength(1));
      expect(diffs.single.categoriaId, 'salud');
      expect(diffs.single.totalDeclarado, const Dinero.cero());
      expect(diffs.single.totalCalculado, const Dinero.pesos(100));
    });

    test('total declarado sin movimientos importados también es diferencia', () {
      final diffs = encontrarDiferencias(
        movimientosImportados: const [],
        totalesDeclarados: const [
          TotalDeclarado(
            categoriaId: 'super',
            cicloId: '2026-05',
            totalCentavos: Dinero.pesos(500),
          ),
        ],
      );
      expect(diffs, hasLength(1));
      expect(diffs.single.totalCalculado, const Dinero.cero());
    });

    test('varias categorías se agrupan por separado, sin mezclarse', () {
      final cicloId = const CalculadoraCiclo(12)
          .calcularPara(DateTime(2026, 5, 15))
          .id;
      final movimientos = [
        _mov('HIST-1', 'super', 300, DateTime(2026, 5, 15)),
        _mov('HIST-2', 'auto', 150, DateTime(2026, 5, 16)),
      ];
      final diffs = encontrarDiferencias(
        movimientosImportados: movimientos,
        totalesDeclarados: [
          TotalDeclarado(
              categoriaId: 'super',
              cicloId: cicloId,
              totalCentavos: const Dinero.pesos(300)),
          TotalDeclarado(
              categoriaId: 'auto',
              cicloId: cicloId,
              totalCentavos: const Dinero.pesos(150)),
        ],
      );
      expect(diffs, isEmpty);
    });
  });

  group('validarReconciliacion — la compuerta de la migración', () {
    test('cuadra al centavo: la migración continúa', () {
      final cicloId = const CalculadoraCiclo(12)
          .calcularPara(DateTime(2026, 6, 10))
          .id;
      // Cifra real documentada en modelo-pronostico-ciclo.md §12: junio $42,674.
      final movimientos = [
        _mov('HIST-1', 'gastos_junio', 42674, DateTime(2026, 6, 10)),
      ];
      final r = validarReconciliacion(
        movimientosImportados: movimientos,
        totalesDeclarados: [
          TotalDeclarado(
            categoriaId: 'gastos_junio',
            cicloId: cicloId,
            totalCentavos: const Dinero.pesos(42674),
          ),
        ],
      );
      expect(r.esExito, isTrue);
    });

    test('un solo peso de diferencia detiene la migración', () {
      final cicloId = const CalculadoraCiclo(12)
          .calcularPara(DateTime(2026, 6, 10))
          .id;
      final movimientos = [
        _mov('HIST-1', 'gastos_junio', 42673, DateTime(2026, 6, 10)),
      ];
      final r = validarReconciliacion(
        movimientosImportados: movimientos,
        totalesDeclarados: [
          TotalDeclarado(
            categoriaId: 'gastos_junio',
            cicloId: cicloId,
            totalCentavos: const Dinero.pesos(42674),
          ),
        ],
      );
      expect(r.esFalla, isTrue);
      expect((r as Falla<void>).mensaje, contains('1 renglón'));
    });

    test('el mensaje de falla incluye el detalle de cada renglón', () {
      final r = validarReconciliacion(
        movimientosImportados: const [],
        totalesDeclarados: const [
          TotalDeclarado(
            categoriaId: 'super',
            cicloId: '2026-05',
            totalCentavos: Dinero.pesos(500),
          ),
        ],
      );
      final mensaje = (r as Falla<void>).mensaje;
      expect(mensaje, contains('super/2026-05'));
    });
  });

  group('DiferenciaReconciliacion.toString', () {
    test('describe declarado, calculado y diferencia', () {
      const d = DiferenciaReconciliacion(
        categoriaId: 'super',
        cicloId: '2026-05',
        totalDeclarado: Dinero.pesos(500),
        totalCalculado: Dinero.pesos(300),
      );
      final texto = d.toString();
      expect(texto, contains('super/2026-05'));
      expect(texto, contains(r'$500.00'));
      expect(texto, contains(r'$300.00'));
    });
  });
}
