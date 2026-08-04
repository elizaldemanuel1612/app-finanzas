import 'package:app_finanzas/domain/pronostico/avance_efectivo.dart';
import 'package:test/test.dart';

void main() {
  final perfilNeutro = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0};

  test('con perfil neutro, el avance efectivo coincide con el avance de calendario', () {
    final fechaInicio = DateTime(2026, 7, 1);
    final fechaFin = DateTime(2026, 7, 31); // 31 días
    final hoy = DateTime(2026, 7, 10); // día 10 de 31

    final avance = avanceEfectivoCiclo(
      perfilDiaSemana: perfilNeutro,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      hoy: hoy,
    );

    expect(avance, closeTo(10 / 31, 0.001));
  });

  test('días fuertes ya pasados adelantan el avance efectivo por encima del calendario', () {
    // Ciclo lunes-domingo (7 días). El sábado (día 6) pesa el doble.
    final perfil = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 2.0, 7: 1.0};
    final fechaInicio = DateTime(2026, 7, 6); // lunes
    final fechaFin = DateTime(2026, 7, 12); // domingo
    final hastaElSabado = DateTime(2026, 7, 11); // sábado (día 6 de 7 calendario)

    final avanceCalendario = 6 / 7;
    final avanceEfectivo = avanceEfectivoCiclo(
      perfilDiaSemana: perfil,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      hoy: hastaElSabado,
    );

    // El peso total de la semana es 8 (6 días normales + sábado doble);
    // hasta el sábado inclusive ya pasó peso 7 de 8 -> 0.875, por encima
    // del avance de calendario (6/7 ≈ 0.857).
    expect(avanceEfectivo, greaterThan(avanceCalendario));
    expect(avanceEfectivo, closeTo(7 / 8, 0.001));
  });

  test('hoy antes del inicio del ciclo da avance 0', () {
    final avance = avanceEfectivoCiclo(
      perfilDiaSemana: perfilNeutro,
      fechaInicio: DateTime(2026, 7, 1),
      fechaFin: DateTime(2026, 7, 31),
      hoy: DateTime(2026, 6, 15),
    );
    expect(avance, 0);
  });

  test('hoy después del fin del ciclo da avance 1', () {
    final avance = avanceEfectivoCiclo(
      perfilDiaSemana: perfilNeutro,
      fechaInicio: DateTime(2026, 7, 1),
      fechaFin: DateTime(2026, 7, 31),
      hoy: DateTime(2026, 8, 15),
    );
    expect(avance, 1);
  });

  test('el último día del ciclo da avance 1', () {
    final avance = avanceEfectivoCiclo(
      perfilDiaSemana: perfilNeutro,
      fechaInicio: DateTime(2026, 7, 1),
      fechaFin: DateTime(2026, 7, 31),
      hoy: DateTime(2026, 7, 31),
    );
    expect(avance, 1);
  });
}
