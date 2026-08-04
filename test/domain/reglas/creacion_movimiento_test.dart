import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

void main() {
  const calculadora = CalculadoraCiclo(12);

  test('captura manual nace activo, con cicloId y periodoNatural calculados', () {
    final r = crearMovimiento(
      clientId: 'dispositivo-1-uuid',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero(48000),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'Despensa',
      origenCaptura: OrigenCaptura.manual,
    );

    expect(r.esExito, isTrue);
    final m = (r as Exito<Movimiento>).valor;
    expect(m.estado, EstadoMovimiento.activo);
    expect(m.cicloId, '2026-07');
    expect(m.periodoNatural, '2026-07');
  });

  test('una recurrencia del sistema nace propuesto', () {
    final r = crearMovimiento(
      clientId: 'sistema-recurrencia-uuid',
      fecha: DateTime(2026, 7, 12),
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(9910),
      categoriaId: 'vivienda',
      medio: MedioPago.tarjeta,
      descripcion: 'Vivienda',
      origenCaptura: OrigenCaptura.recurrente,
    );

    expect((r as Exito<Movimiento>).valor.estado, EstadoMovimiento.propuesto);
  });

  test('clientId inválido propaga la falla de idempotencia', () {
    final r = crearMovimiento(
      clientId: '',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero(100),
      categoriaId: 'super',
      medio: MedioPago.efectivo,
      descripcion: 'Algo',
      origenCaptura: OrigenCaptura.manual,
    );
    expect(r.esFalla, isTrue);
  });

  test('monto cero propaga la falla de monto positivo', () {
    final r = crearMovimiento(
      clientId: 'dispositivo-1-uuid',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.cero(),
      categoriaId: 'super',
      medio: MedioPago.efectivo,
      descripcion: 'Algo',
      origenCaptura: OrigenCaptura.manual,
    );
    expect(r.esFalla, isTrue);
  });

  test('el cicloId coincide con el que calcularía la CalculadoraCiclo por su cuenta', () {
    final fecha = DateTime(2026, 7, 5); // antes del corte -> ciclo de junio
    final r = crearMovimiento(
      clientId: 'dispositivo-1-uuid',
      fecha: fecha,
      calculadoraCiclo: calculadora,
      monto: const Dinero(100),
      categoriaId: 'super',
      medio: MedioPago.efectivo,
      descripcion: 'Algo',
      origenCaptura: OrigenCaptura.manual,
    );
    final esperado = calculadora.calcularPara(fecha);
    expect((r as Exito<Movimiento>).valor.cicloId, esperado.id);
  });

  test('esReembolsable se conserva', () {
    final r = crearMovimiento(
      clientId: 'dispositivo-1-uuid',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero(100),
      categoriaId: 'salidas',
      medio: MedioPago.tarjeta,
      descripcion: 'Cena de trabajo',
      origenCaptura: OrigenCaptura.manual,
      esReembolsable: true,
    );
    expect((r as Exito<Movimiento>).valor.esReembolsable, isTrue);
  });
}
