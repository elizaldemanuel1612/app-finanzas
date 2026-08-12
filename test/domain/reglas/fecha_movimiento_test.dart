import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/reglas/fecha_movimiento.dart';
import 'package:test/test.dart';

Movimiento _movimiento({required DateTime fecha, required String cicloId, required String periodoNatural}) {
  return Movimiento(
    clientId: 'cliente-uuid',
    fecha: fecha,
    cicloId: cicloId,
    periodoNatural: periodoNatural,
    monto: const Dinero(10000),
    categoriaId: 'super',
    medio: MedioPago.tarjeta,
    descripcion: 'Despensa',
    estado: EstadoMovimiento.activo,
    origenCaptura: OrigenCaptura.manual,
  );
}

void main() {
  group('validarFechaCaptura', () {
    test('hoy pasa', () {
      final ahora = DateTime(2026, 7, 15, 10, 0);
      final r = validarFechaCaptura(DateTime(2026, 7, 15), ahora: ahora);
      expect(r.esExito, isTrue);
    });

    test('ayer pasa', () {
      final ahora = DateTime(2026, 7, 15, 10, 0);
      final r = validarFechaCaptura(DateTime(2026, 7, 14), ahora: ahora);
      expect(r.esExito, isTrue);
    });

    test('una fecha vieja pasa', () {
      final ahora = DateTime(2026, 7, 15, 10, 0);
      final r = validarFechaCaptura(DateTime(2025, 1, 1), ahora: ahora);
      expect(r.esExito, isTrue);
    });

    test('mañana falla', () {
      final ahora = DateTime(2026, 7, 15, 10, 0);
      final r = validarFechaCaptura(DateTime(2026, 7, 16), ahora: ahora);
      expect(r.esFalla, isTrue);
    });

    test('futuro lejano falla', () {
      final ahora = DateTime(2026, 7, 15, 10, 0);
      final r = validarFechaCaptura(DateTime(2027, 1, 1), ahora: ahora);
      expect(r.esFalla, isTrue);
    });

    test('hoy más tarde en el día pasa: compara por día, no por instante', () {
      // "ahora" son las 10:00, pero se captura como si fueran las 23:00 del
      // mismo día — sigue siendo hoy.
      final ahora = DateTime(2026, 7, 15, 10, 0);
      final r = validarFechaCaptura(DateTime(2026, 7, 15, 23, 0), ahora: ahora);
      expect(r.esExito, isTrue);
    });
  });

  group('editarFechaMovimiento', () {
    const calculadora = CalculadoraCiclo(12); // ciclo: 12 de un mes a 11 del siguiente

    test('misma fecha tiene éxito sin cambios efectivos', () {
      final m = _movimiento(fecha: DateTime(2026, 7, 20), cicloId: '2026-07', periodoNatural: '2026-07');
      final r = editarFechaMovimiento(
        movimiento: m,
        nuevaFecha: DateTime(2026, 7, 20),
        calculadoraCiclo: calculadora,
      );
      expect(r.esExito, isTrue);
      final editado = (r as Exito<Movimiento>).valor;
      expect(editado.fecha, DateTime(2026, 7, 20));
      expect(editado.cicloId, '2026-07');
      expect(editado.periodoNatural, '2026-07');
    });

    test('otro día del mismo ciclo tiene éxito y conserva el cicloId', () {
      final m = _movimiento(fecha: DateTime(2026, 7, 20), cicloId: '2026-07', periodoNatural: '2026-07');
      final r = editarFechaMovimiento(
        movimiento: m,
        nuevaFecha: DateTime(2026, 7, 25),
        calculadoraCiclo: calculadora,
      );
      expect(r.esExito, isTrue);
      final editado = (r as Exito<Movimiento>).valor;
      expect(editado.fecha, DateTime(2026, 7, 25));
      expect(editado.cicloId, '2026-07');
    });

    test('cambio de periodoNatural dentro del mismo ciclo: 20 jul a 5 ago con corte 12', () {
      // Ciclo 2026-07 va del 12 jul al 11 ago: mover el gasto del 20 jul al
      // 5 ago no cambia de ciclo, pero sí de mes natural.
      final m = _movimiento(fecha: DateTime(2026, 7, 20), cicloId: '2026-07', periodoNatural: '2026-07');
      final r = editarFechaMovimiento(
        movimiento: m,
        nuevaFecha: DateTime(2026, 8, 5),
        calculadoraCiclo: calculadora,
      );
      expect(r.esExito, isTrue);
      final editado = (r as Exito<Movimiento>).valor;
      expect(editado.cicloId, '2026-07');
      expect(editado.periodoNatural, '2026-08');
    });

    test('fecha de otro ciclo falla', () {
      final m = _movimiento(fecha: DateTime(2026, 7, 20), cicloId: '2026-07', periodoNatural: '2026-07');
      final r = editarFechaMovimiento(
        movimiento: m,
        nuevaFecha: DateTime(2026, 9, 1),
        calculadoraCiclo: calculadora,
      );
      expect(r.esFalla, isTrue);
    });
  });
}
