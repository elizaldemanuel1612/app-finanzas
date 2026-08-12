import 'package:app_finanzas/domain/rollups/estado_ritmo.dart';
import 'package:test/test.dart';

void main() {
  group('calcularEstadoRitmo', () {
    test('sin presupuesto (null) siempre va bien, no aplica juicio', () {
      expect(calcularEstadoRitmo(porcentajeUsado: null), EstadoRitmo.vaBien);
    });

    test('gastar más del 100% del presupuesto es "excedido"', () {
      expect(calcularEstadoRitmo(porcentajeUsado: 1.01), EstadoRitmo.excedido);
    });

    test('gastar cerca del 100% (entre 85% y 100%) es "justo"', () {
      expect(calcularEstadoRitmo(porcentajeUsado: 0.9), EstadoRitmo.justo);
    });

    test('gastar bastante menos del presupuesto es "va bien"', () {
      expect(calcularEstadoRitmo(porcentajeUsado: 0.5), EstadoRitmo.vaBien);
    });

    test('el 50% del presupuesto el primer día del ciclo ya no es "excedido" '
        '(regresión: antes se comparaba contra el avance del ciclo, no '
        'contra el 100% del presupuesto)', () {
      expect(calcularEstadoRitmo(porcentajeUsado: 0.5), EstadoRitmo.vaBien);
    });

    test('en el límite exacto de cada umbral', () {
      expect(calcularEstadoRitmo(porcentajeUsado: 0.85), EstadoRitmo.vaBien);
      expect(calcularEstadoRitmo(porcentajeUsado: 0.86), EstadoRitmo.justo);
      expect(calcularEstadoRitmo(porcentajeUsado: 1.0), EstadoRitmo.justo);
      expect(calcularEstadoRitmo(porcentajeUsado: 1.001), EstadoRitmo.excedido);
    });
  });

  group('vaMuyRapido', () {
    test('sin presupuesto (null) nunca proyecta', () {
      expect(
        vaMuyRapido(porcentajeUsado: null, avanceCiclo: 0.5),
        isFalse,
      );
    });

    test('con muy poco avance del ciclo, no proyecta aunque el gasto sea alto '
        '(el caso que antes disparaba "pasado" el primer día del ciclo)', () {
      expect(
        vaMuyRapido(porcentajeUsado: 0.5, avanceCiclo: 0.03),
        isFalse,
      );
    });

    test('con avance suficiente, gastar muy por encima del avance sí proyecta', () {
      expect(
        vaMuyRapido(porcentajeUsado: 0.8, avanceCiclo: 0.3),
        isTrue,
      );
    });

    test('con avance suficiente, gastar cerca del avance no proyecta', () {
      expect(
        vaMuyRapido(porcentajeUsado: 0.45, avanceCiclo: 0.5),
        isFalse,
      );
    });

    test('justo en el piso mínimo de avance, ya evalúa la proyección', () {
      expect(
        vaMuyRapido(
          porcentajeUsado: 0.5,
          avanceCiclo: avanceMinimoParaProyectarRitmo,
        ),
        isTrue, // 0.5 > 0.15 * 1.15
      );
    });

    test('justo debajo del piso mínimo de avance, no proyecta', () {
      expect(
        vaMuyRapido(
          porcentajeUsado: 0.5,
          avanceCiclo: avanceMinimoParaProyectarRitmo - 0.01,
        ),
        isFalse,
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
