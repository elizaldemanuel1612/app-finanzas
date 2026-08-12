import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/pronostico/historico_desde_movimientos.dart';
import 'package:test/test.dart';

CategoriaVariable _variable() => const CategoriaVariable(
      id: 'super',
      nombre: 'Súper/Comida',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(6000),
    );

Movimiento _mov({
  required DateTime fecha,
  required String cicloId,
  Dinero? monto,
  String categoriaId = 'super',
  EstadoMovimiento estado = EstadoMovimiento.activo,
}) =>
    Movimiento(
      clientId: 'c-${fecha.toIso8601String()}-$cicloId-$categoriaId-${estado.name}',
      fecha: fecha,
      cicloId: cicloId,
      periodoNatural: periodoNatural(fecha),
      monto: monto ?? const Dinero.pesos(100),
      categoriaId: categoriaId,
      medio: MedioPago.efectivo,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

void main() {
  group('ciclosCerradosDeCategoria', () {
    test('excluye el ciclo actual, otras categorías y movimientos no activos', () {
      final todos = [
        _mov(fecha: DateTime(2026, 7, 5), cicloId: '2026-07'), // ciclo actual
        _mov(fecha: DateTime(2026, 6, 5), cicloId: '2026-06', categoriaId: 'otra'),
        _mov(fecha: DateTime(2026, 6, 5), cicloId: '2026-06', estado: EstadoMovimiento.anulado),
        _mov(fecha: DateTime(2026, 6, 5), cicloId: '2026-06', monto: const Dinero.pesos(50)),
        _mov(fecha: DateTime(2026, 5, 5), cicloId: '2026-05', monto: const Dinero.pesos(70)),
      ];

      final resultado = ciclosCerradosDeCategoria(
        todos: todos,
        categoriaId: 'super',
        cicloActualId: '2026-07',
      );

      expect(resultado, hasLength(2));
      expect(resultado[0], hasLength(1));
      expect(resultado[0].single.monto, 5000);
      expect(resultado[1].single.monto, 7000);
    });

    test('ordena de ciclo más reciente a más antiguo', () {
      final todos = [
        _mov(fecha: DateTime(2026, 3, 5), cicloId: '2026-03', monto: const Dinero.pesos(3)),
        _mov(fecha: DateTime(2026, 5, 5), cicloId: '2026-05', monto: const Dinero.pesos(5)),
        _mov(fecha: DateTime(2026, 4, 5), cicloId: '2026-04', monto: const Dinero.pesos(4)),
      ];

      final resultado = ciclosCerradosDeCategoria(
        todos: todos,
        categoriaId: 'super',
        cicloActualId: '2026-07',
      );

      expect(resultado, hasLength(3));
      expect(resultado.map((c) => c.single.monto), [500.0, 400.0, 300.0]);
    });

    test('sin movimientos de la categoría: lista vacía', () {
      final resultado = ciclosCerradosDeCategoria(
        todos: const [],
        categoriaId: 'super',
        cicloActualId: '2026-07',
      );
      expect(resultado, isEmpty);
    });
  });

  group('pronosticoDeCategoria', () {
    test('usa solo movimientos activos del ciclo actual como observado', () {
      final ciclo = Ciclo(
        id: '2026-07',
        fechaInicio: DateTime(2026, 7, 1),
        fechaFin: DateTime(2026, 7, 31),
        etiqueta: 'Jul',
        estado: EstadoCiclo.abierto,
      );
      final todos = [
        _mov(fecha: DateTime(2026, 7, 3), cicloId: '2026-07', monto: const Dinero.pesos(40)),
        _mov(
          fecha: DateTime(2026, 7, 4),
          cicloId: '2026-07',
          monto: const Dinero.pesos(999),
          estado: EstadoMovimiento.anulado,
        ),
        _mov(fecha: DateTime(2026, 6, 3), cicloId: '2026-06', monto: const Dinero.pesos(60)),
      ];

      final pronostico = pronosticoDeCategoria(
        categoria: _variable(),
        todos: todos,
        ciclo: ciclo,
        hoy: DateTime(2026, 7, 15),
      );

      expect(pronostico.observado, const Dinero.pesos(40));
      expect(pronostico.categoriaId, 'super');
      expect(pronostico.cicloId, '2026-07');
    });
  });
}
