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

    test('un ciclo con registros pero sin gasto en la categoría entra vacío (2026-11-24)', () {
      final todos = [
        _mov(fecha: DateTime(2026, 2, 5), cicloId: '2026-02', categoriaId: 'otra'), // antes del primero: no
        _mov(fecha: DateTime(2026, 3, 5), cicloId: '2026-03', monto: const Dinero.pesos(900)),
        _mov(fecha: DateTime(2026, 4, 5), cicloId: '2026-04', categoriaId: 'otra'),
        // 2026-05 sin ningún registro: no cuenta.
        _mov(fecha: DateTime(2026, 6, 5), cicloId: '2026-06', categoriaId: 'otra'),
        _mov(fecha: DateTime(2026, 6, 6), cicloId: '2026-06', estado: EstadoMovimiento.anulado),
      ];

      final resultado = ciclosCerradosDeCategoria(todos: todos, categoriaId: 'super', cicloActualId: '2026-07');

      expect(resultado.map((c) => c.length), [0, 0, 1]);
    });

    test('con un ciclo de cada tres, el cierre esperado ya no es el de los ciclos con gasto', () {
      final todos = [
        for (final mes in [1, 2, 3, 4, 5, 6])
          _mov(fecha: DateTime(2026, mes, 3), cicloId: '2026-0$mes', categoriaId: 'otra'),
        for (final mes in [1, 4])
          _mov(fecha: DateTime(2026, mes, 20), cicloId: '2026-0$mes', monto: const Dinero.pesos(3000)),
      ];
      final p = pronosticoDeCategoria(
        categoria: _variable(),
        todos: todos,
        ciclo: CalculadoraCiclo(1).calcularPara(DateTime(2026, 7, 10)),
        hoy: DateTime(2026, 7, 10),
      );
      expect(p.pronosticoP50 < const Dinero.pesos(3000), isTrue, reason: '${p.pronosticoP50}');
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

  group('posición dentro del ciclo (modelo-pronostico-ciclo.md §3.2)', () {
    Ciclo ciclo(String id, DateTime inicio, DateTime fin) =>
        Ciclo(id: id, fechaInicio: inicio, fechaFin: fin, etiqueta: id, estado: EstadoCiclo.abierto);
    final actual = ciclo('2026-11', DateTime(2026, 11, 12), DateTime(2026, 12, 11));

    test('el inicio de un ciclo pasado sale de su id y del día de inicio del actual', () {
      expect(inicioEstimadoDeCiclo('2026-10', actual), DateTime(2026, 10, 12));
      // En meses cortos, el último día.
      final fin = ciclo('2026-03', DateTime(2026, 3, 31), DateTime(2026, 4, 29));
      expect(inicioEstimadoDeCiclo('2026-02', fin), DateTime(2026, 2, 28));
      for (final malo in ['2026', 'x-y', '2026-13', '2026-00', '2026-1-1', 'aaaa-11']) {
        expect(inicioEstimadoDeCiclo(malo, actual), isNull, reason: malo);
      }
    });

    test('las mensualidades que aún no llegan no son historia (spec §7.3.1)', () {
      final todos = [
        _mov(fecha: DateTime(2026, 10, 15), cicloId: '2026-10'),
        _mov(fecha: DateTime(2026, 12, 15), cicloId: '2026-12'),
        _mov(fecha: DateTime(2027, 1, 15), cicloId: '2027-01'),
      ];
      expect(ciclosCerradosDeCategoria(todos: todos, categoriaId: 'super', cicloActualId: '2026-11'), hasLength(1));
    });

    test('un pago al inicio ya hecho no se vuelve a esperar', () {
      final todos = [
        for (final mes in [8, 9, 10])
          _mov(fecha: DateTime(2026, mes, 13), cicloId: '2026-${mes.toString().padLeft(2, '0')}', monto: const Dinero.pesos(2980)),
        _mov(fecha: DateTime(2026, 11, 13), cicloId: '2026-11', monto: const Dinero.pesos(2980)),
      ];
      final p = pronosticoDeCategoria(categoria: _variable(), todos: todos, ciclo: actual, hoy: DateTime(2026, 11, 21, 17));
      expect(p.pronosticoP50, const Dinero.pesos(2980));
    });

    test('con un id de ciclo que no se sabe leer se usa el avance de calendario', () {
      final todos = [
        _mov(fecha: DateTime(2026, 10, 13), cicloId: '0-raro', monto: const Dinero.pesos(2980)),
        _mov(fecha: DateTime(2026, 11, 13), cicloId: '2026-11', monto: const Dinero.pesos(2980)),
      ];
      final p = pronosticoDeCategoria(categoria: _variable(), todos: todos, ciclo: actual, hoy: DateTime(2026, 11, 21, 17));
      // 2,980 + 1 × (1 − 10/30) × 2,980.
      expect(p.pronosticoP50, const Dinero(496667));
    });
  });
}
