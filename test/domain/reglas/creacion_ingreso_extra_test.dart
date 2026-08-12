import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/reglas/creacion_ingreso_extra.dart';
import 'package:test/test.dart';

void main() {
  const calculadora = CalculadoraCiclo(12);

  test('captura válida nace activo, con cicloId calculado de la fecha', () {
    final r = crearIngresoExtra(
      id: 'ing-1',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(15000),
      etiqueta: 'Bono',
      destino: DestinoExtra.apartado,
    );

    expect(r.esExito, isTrue);
    final ingreso = (r as Exito<IngresoExtra>).valor;
    expect(ingreso.estado, EstadoIngreso.activo);
    expect(ingreso.cicloId, '2026-07');
    expect(ingreso.destino, DestinoExtra.apartado);
  });

  test('el cicloId coincide con el que calcularía la CalculadoraCiclo por su cuenta', () {
    final fecha = DateTime(2026, 7, 5); // antes del corte -> ciclo de junio
    final r = crearIngresoExtra(
      id: 'ing-1',
      fecha: fecha,
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(100),
      etiqueta: 'Bono',
      destino: DestinoExtra.gasto,
    );
    final esperado = calculadora.calcularPara(fecha);
    expect((r as Exito<IngresoExtra>).valor.cicloId, esperado.id);
  });

  test('monto cero propaga la falla de monto positivo', () {
    final r = crearIngresoExtra(
      id: 'ing-1',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.cero(),
      etiqueta: 'Bono',
      destino: DestinoExtra.apartado,
    );
    expect(r.esFalla, isTrue);
  });

  test('monto negativo propaga la falla de monto positivo', () {
    final r = crearIngresoExtra(
      id: 'ing-1',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero(-100),
      etiqueta: 'Bono',
      destino: DestinoExtra.apartado,
    );
    expect(r.esFalla, isTrue);
  });

  test('etiqueta vacía falla', () {
    final r = crearIngresoExtra(
      id: 'ing-1',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(100),
      etiqueta: '',
      destino: DestinoExtra.apartado,
    );
    expect(r.esFalla, isTrue);
  });

  test('etiqueta solo con espacios falla', () {
    final r = crearIngresoExtra(
      id: 'ing-1',
      fecha: DateTime(2026, 7, 15),
      calculadoraCiclo: calculadora,
      monto: const Dinero.pesos(100),
      etiqueta: '   ',
      destino: DestinoExtra.apartado,
    );
    expect(r.esFalla, isTrue);
  });
}
