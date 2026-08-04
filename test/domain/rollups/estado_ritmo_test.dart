import 'package:app_finanzas/domain/rollups/estado_ritmo.dart';
import 'package:test/test.dart';

void main() {
  group('calcularEstadoRitmo', () {
    test('sin presupuesto (null) siempre va bien, no aplica juicio', () {
      expect(
        calcularEstadoRitmo(porcentajeUsado: null, avanceCiclo: 0.9),
        EstadoRitmo.vaBien,
      );
    });

    test('gastar muy por encima del avance del ciclo es "pasado"', () {
      expect(
        calcularEstadoRitmo(porcentajeUsado: 0.8, avanceCiclo: 0.3),
        EstadoRitmo.pasado,
      );
    });

    test('gastar cerca del avance del ciclo es "justo"', () {
      expect(
        calcularEstadoRitmo(porcentajeUsado: 0.45, avanceCiclo: 0.5),
        EstadoRitmo.justo,
      );
    });

    test('gastar bastante menos que el avance del ciclo es "va bien"', () {
      expect(
        calcularEstadoRitmo(porcentajeUsado: 0.1, avanceCiclo: 0.5),
        EstadoRitmo.vaBien,
      );
    });

    test('en el límite exacto del umbral "pasado" (1.15x)', () {
      expect(
        calcularEstadoRitmo(porcentajeUsado: 0.575, avanceCiclo: 0.5),
        EstadoRitmo.justo,
      );
      expect(
        calcularEstadoRitmo(porcentajeUsado: 0.58, avanceCiclo: 0.5),
        EstadoRitmo.pasado,
      );
    });
  });

  group('avanceDelCiclo', () {
    test('a la mitad del ciclo da 0.5 aproximado', () {
      final avance = avanceDelCiclo(
        fechaInicio: DateTime(2026, 7, 12),
        fechaFin: DateTime(2026, 8, 11),
        ahora: DateTime(2026, 7, 27), // día 16 de 31
      );
      expect(avance, closeTo(16 / 31, 0.001));
    });

    test('el primer día del ciclo no da cero', () {
      final avance = avanceDelCiclo(
        fechaInicio: DateTime(2026, 7, 12),
        fechaFin: DateTime(2026, 8, 11),
        ahora: DateTime(2026, 7, 12),
      );
      expect(avance, closeTo(1 / 31, 0.001));
    });

    test('el último día del ciclo da 1.0 exacto', () {
      final avance = avanceDelCiclo(
        fechaInicio: DateTime(2026, 7, 12),
        fechaFin: DateTime(2026, 8, 11),
        ahora: DateTime(2026, 8, 11),
      );
      expect(avance, 1.0);
    });

    test('una fecha después del fin del ciclo se acota a 1.0', () {
      final avance = avanceDelCiclo(
        fechaInicio: DateTime(2026, 7, 12),
        fechaFin: DateTime(2026, 8, 11),
        ahora: DateTime(2026, 9, 1),
      );
      expect(avance, 1.0);
    });

    test('una fecha antes del inicio del ciclo se acota a 0', () {
      final avance = avanceDelCiclo(
        fechaInicio: DateTime(2026, 7, 12),
        fechaFin: DateTime(2026, 8, 11),
        ahora: DateTime(2026, 7, 1),
      );
      expect(avance, 0.0);
    });
  });
}
