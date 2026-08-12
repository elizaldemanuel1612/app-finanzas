import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/presupuesto/eliminacion_categoria.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);

CategoriaFija _fija(String id, int monto) => CategoriaFija(
      id: id,
      nombre: id,
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(monto),
      diaDelCiclo: 1,
    );

CategoriaVariable _variable(String id, int presupuesto) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(presupuesto),
    );

Movimiento _mov(
  String clientId,
  String categoriaId, {
  EstadoMovimiento estado = EstadoMovimiento.activo,
}) {
  final r = crearMovimiento(
    clientId: clientId,
    fecha: DateTime(2026, 7, 15),
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(100),
    categoriaId: categoriaId,
    medio: MedioPago.tarjeta,
    descripcion: categoriaId,
    origenCaptura: OrigenCaptura.manual,
  ) as Exito<Movimiento>;
  return r.valor.copyWith(estado: estado);
}

void main() {
  group('evaluarEliminacionCategoria', () {
    test('sin movimientos: PuedeEliminarse con el presupuesto liberado de una fija', () {
      final efecto = evaluarEliminacionCategoria(
        categoria: _fija('renta', 5000),
        movimientosDeLaCategoria: const [],
        reglasAprendidas: const [],
      );
      expect(efecto, isA<PuedeEliminarse>());
      final puede = efecto as PuedeEliminarse;
      expect(puede.presupuestoLiberado, const Dinero.pesos(5000));
      expect(puede.reglasAprendidasQueSePierden, 0);
    });

    test('sin movimientos: PuedeEliminarse con el presupuesto liberado de una variable', () {
      final efecto = evaluarEliminacionCategoria(
        categoria: _variable('super', 1200),
        movimientosDeLaCategoria: const [],
        reglasAprendidas: const [],
      );
      final puede = efecto as PuedeEliminarse;
      expect(puede.presupuestoLiberado, const Dinero.pesos(1200));
    });

    test('cuenta solo las reglas aprendidas que apuntan a esa categoría', () {
      final reglas = [
        const ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 3),
        const ReglaAprendida(patron: '7 eleven', categoriaId: 'super', contador: 1),
        const ReglaAprendida(patron: 'uber', categoriaId: 'transporte', contador: 5),
      ];
      final efecto = evaluarEliminacionCategoria(
        categoria: _variable('super', 1200),
        movimientosDeLaCategoria: const [],
        reglasAprendidas: reglas,
      );
      final puede = efecto as PuedeEliminarse;
      expect(puede.reglasAprendidasQueSePierden, 2);
    });

    test('con movimientos activos: SoloPuedeDesactivarse con conteo y total', () {
      final movimientos = [_mov('a12345678', 'super'), _mov('b12345678', 'super')];
      final efecto = evaluarEliminacionCategoria(
        categoria: _variable('super', 1200),
        movimientosDeLaCategoria: movimientos,
        reglasAprendidas: const [],
      );
      expect(efecto, isA<SoloPuedeDesactivarse>());
      final solo = efecto as SoloPuedeDesactivarse;
      expect(solo.movimientos, 2);
      expect(solo.totalHistorico, const Dinero.pesos(200));
    });

    test('un movimiento anulado también impide el borrado (regla no negociable #3)', () {
      final movimientos = [_mov('a12345678', 'super', estado: EstadoMovimiento.anulado)];
      final efecto = evaluarEliminacionCategoria(
        categoria: _variable('super', 1200),
        movimientosDeLaCategoria: movimientos,
        reglasAprendidas: const [],
      );
      expect(efecto, isA<SoloPuedeDesactivarse>());
      expect((efecto as SoloPuedeDesactivarse).movimientos, 1);
    });
  });
}
