import 'package:app_finanzas/core/ciclo.dart';
import 'package:test/test.dart';

void main() {
  group('CalculadoraCiclo — caso base, corte el 12', () {
    const calc = CalculadoraCiclo(12);

    test('una fecha dentro del ciclo (mitad de mes)', () {
      final ciclo = calc.calcularPara(DateTime(2026, 7, 15));
      expect(ciclo.id, '2026-07');
      expect(ciclo.fechaInicio, DateTime(2026, 7, 12));
      expect(ciclo.fechaFin, DateTime(2026, 8, 11));
      expect(ciclo.etiqueta, 'Jul');
      expect(ciclo.estado, EstadoCiclo.abierto);
    });

    test('una fecha antes del corte cae en el ciclo anterior', () {
      final ciclo = calc.calcularPara(DateTime(2026, 7, 5));
      expect(ciclo.id, '2026-06');
      expect(ciclo.fechaInicio, DateTime(2026, 6, 12));
      expect(ciclo.fechaFin, DateTime(2026, 7, 11));
    });

    test('el día exacto del corte pertenece al ciclo que empieza', () {
      final ciclo = calc.calcularPara(DateTime(2026, 7, 12));
      expect(ciclo.id, '2026-07');
      expect(ciclo.fechaInicio, DateTime(2026, 7, 12));
    });

    test('el último día del ciclo (día antes del corte siguiente)', () {
      final ciclo = calc.calcularPara(DateTime(2026, 8, 11));
      expect(ciclo.id, '2026-07');
      expect(ciclo.fechaFin, DateTime(2026, 8, 11));
    });

    test('cruce de año: diciembre a enero', () {
      final ciclo = calc.calcularPara(DateTime(2026, 12, 20));
      expect(ciclo.id, '2026-12');
      expect(ciclo.fechaInicio, DateTime(2026, 12, 12));
      expect(ciclo.fechaFin, DateTime(2027, 1, 11));
    });

    test('cruce de año: principios de enero cae en el ciclo de diciembre', () {
      final ciclo = calc.calcularPara(DateTime(2027, 1, 5));
      expect(ciclo.id, '2026-12');
      expect(ciclo.fechaInicio, DateTime(2026, 12, 12));
      expect(ciclo.fechaFin, DateTime(2027, 1, 11));
    });
  });

  group('CalculadoraCiclo — día de corte que no existe en meses cortos', () {
    test('corte 31 en febrero (no bisiesto) se clampea a 28', () {
      const calc = CalculadoraCiclo(31);
      final ciclo = calc.calcularPara(DateTime(2026, 2, 15));
      expect(ciclo.id, '2026-01');
      expect(ciclo.fechaInicio, DateTime(2026, 1, 31));
      // Febrero 2026 tiene 28 días -> el corte cae el 28, el ciclo termina un día antes.
      expect(ciclo.fechaFin, DateTime(2026, 2, 27));
    });

    test('corte 31 en febrero bisiesto se clampea a 29', () {
      const calc = CalculadoraCiclo(31);
      // 2028 es bisiesto: febrero tiene 29 días.
      final ciclo = calc.calcularPara(DateTime(2028, 2, 15));
      expect(ciclo.id, '2028-01');
      expect(ciclo.fechaInicio, DateTime(2028, 1, 31));
      expect(ciclo.fechaFin, DateTime(2028, 2, 28));
    });
  });

  group('Ciclo.contiene', () {
    final ciclo = const CalculadoraCiclo(12).calcularPara(DateTime(2026, 7, 15));

    test('fecha dentro del rango', () {
      expect(ciclo.contiene(DateTime(2026, 7, 20)), isTrue);
    });

    test('límites inclusive', () {
      expect(ciclo.contiene(DateTime(2026, 7, 12)), isTrue);
      expect(ciclo.contiene(DateTime(2026, 8, 11)), isTrue);
    });

    test('fecha fuera del rango', () {
      expect(ciclo.contiene(DateTime(2026, 7, 11)), isFalse);
      expect(ciclo.contiene(DateTime(2026, 8, 12)), isFalse);
    });
  });

  group('Ciclo — cerrar y reabrir (regla no negociable #6)', () {
    final abierto = const CalculadoraCiclo(12).calcularPara(DateTime(2026, 7, 15));

    test('cerrar un ciclo abierto tiene éxito', () {
      final resultado = abierto.cerrar();
      expect(resultado.esExito, isTrue);
      expect(resultado.valorOLanza.estado, EstadoCiclo.cerrado);
    });

    test('cerrar un ciclo ya cerrado falla', () {
      final cerrado = abierto.cerrar().valorOLanza;
      expect(cerrado.cerrar().esFalla, isTrue);
    });

    test('reabrir un ciclo cerrado tiene éxito', () {
      final cerrado = abierto.cerrar().valorOLanza;
      final resultado = cerrado.reabrir();
      expect(resultado.esExito, isTrue);
      expect(resultado.valorOLanza.estado, EstadoCiclo.abierto);
    });

    test('reabrir un ciclo ya abierto falla', () {
      expect(abierto.reabrir().esFalla, isTrue);
    });

    test('cerrar/reabrir no muta el original (inmutable)', () {
      abierto.cerrar();
      expect(abierto.estado, EstadoCiclo.abierto);
    });
  });

  group('Ciclo — igualdad', () {
    test('dos ciclos calculados iguales son ==', () {
      const calc = CalculadoraCiclo(12);
      expect(
        calc.calcularPara(DateTime(2026, 7, 15)),
        calc.calcularPara(DateTime(2026, 7, 20)),
      );
    });

    test('dos ciclos iguales tienen el mismo hashCode', () {
      const calc = CalculadoraCiclo(12);
      expect(
        calc.calcularPara(DateTime(2026, 7, 15)).hashCode,
        calc.calcularPara(DateTime(2026, 7, 20)).hashCode,
      );
    });

    test('toString incluye el id y el rango', () {
      final ciclo = const CalculadoraCiclo(12).calcularPara(DateTime(2026, 7, 15));
      expect(ciclo.toString(), contains('2026-07'));
    });
  });

  group('periodoNatural', () {
    test('formatea año-mes con ceros a la izquierda', () {
      expect(periodoNatural(DateTime(2026, 7, 15)), '2026-07');
      expect(periodoNatural(DateTime(2026, 1, 1)), '2026-01');
    });
  });
}
