import 'package:app_finanzas/domain/pronostico/perfil_dia_semana.dart';
import 'package:app_finanzas/domain/pronostico/punto_monto.dart';
import 'package:test/test.dart';

DateTime _lunes(int semana) => DateTime(2026, 1, 5).add(Duration(days: 7 * semana));

void main() {
  test('historial vacío da perfil neutro (todos en 1.0)', () {
    final perfil = calcularPerfilDiaSemana([]);
    expect(perfil, {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0});
  });

  test('día sin historial regresa peso neutro 1.0 aunque otros días sí tengan datos', () {
    // Solo hay datos de lunes (weekday 1); el resto de la semana no aparece.
    final historial = List.generate(
      10,
      (i) => PuntoMonto(_lunes(i), 100),
    );
    final perfil = calcularPerfilDiaSemana(historial);
    expect(perfil[2], 1.0); // martes, sin datos
    expect(perfil[7], 1.0); // domingo, sin datos
  });

  test('credibilidad: con 4 sábados de historia, λ ≈ 0.33 (ejemplo del spec §3.1)', () {
    // 4 sábados con gasto alto (200) + 4 martes con gasto bajo (33.3),
    // para que el promedio general quede en un punto medio conocido.
    final sabado = DateTime(2026, 1, 3); // sábado
    final martes = DateTime(2026, 1, 6); // martes
    final historial = [
      for (var i = 0; i < 4; i++) PuntoMonto(sabado.add(Duration(days: 7 * i)), 200),
      for (var i = 0; i < 4; i++) PuntoMonto(martes.add(Duration(days: 7 * i)), 100 / 3),
    ];
    final perfil = calcularPerfilDiaSemana(historial);

    final promedioGeneral = (200 + 100 / 3) / 2;
    final wObservadoSabado = 200 / promedioGeneral;
    const lambdaEsperada = 4 / 12; // n=4 -> 4/(4+8) = 0.333...
    final esperado = lambdaEsperada * wObservadoSabado + (1 - lambdaEsperada) * 1.0;

    expect(perfil[6], closeTo(esperado, 0.0001)); // sábado = weekday 6
    expect(lambdaEsperada, closeTo(0.3333, 0.001));
  });

  test('más historial da más credibilidad (λ más alto, el perfil se aleja más de 1.0)', () {
    PuntoMonto puntoSabado(int semana, double monto) =>
        PuntoMonto(DateTime(2026, 1, 3).add(Duration(days: 7 * semana)), monto);
    PuntoMonto puntoMartes(int semana, double monto) =>
        PuntoMonto(DateTime(2026, 1, 6).add(Duration(days: 7 * semana)), monto);

    final pocos = [
      for (var i = 0; i < 3; i++) puntoSabado(i, 300),
      for (var i = 0; i < 3; i++) puntoMartes(i, 50),
    ];
    final muchos = [
      for (var i = 0; i < 30; i++) puntoSabado(i, 300),
      for (var i = 0; i < 30; i++) puntoMartes(i, 50),
    ];

    final perfilPocos = calcularPerfilDiaSemana(pocos);
    final perfilMuchos = calcularPerfilDiaSemana(muchos);

    // Con más datos, el peso de sábado (weekday 6) se aleja más de 1.0
    // hacia el valor observado (sábado gasta más que el promedio).
    expect(perfilMuchos[6]!, greaterThan(perfilPocos[6]!));
  });

  test('múltiples movimientos el mismo día cuentan como un solo dato, no varios', () {
    final dia = DateTime(2026, 1, 3); // sábado
    // 3 movimientos el mismo sábado deberían sumar, no triplicar el conteo.
    final historial = [
      PuntoMonto(dia, 100),
      PuntoMonto(dia, 50),
      PuntoMonto(dia, 30),
      PuntoMonto(DateTime(2026, 1, 6), 60), // un martes normal
    ];
    final perfil = calcularPerfilDiaSemana(historial);
    // n para sábado debe ser 1 día (no 3) -> lambda = 1/9, mucho más
    // conservador que si contara 3 movimientos.
    final lambdaEsperada = 1 / 9;
    final promedioGeneral = (180 + 60) / 2;
    final wObservado = 180 / promedioGeneral;
    final esperado = lambdaEsperada * wObservado + (1 - lambdaEsperada) * 1.0;
    expect(perfil[6], closeTo(esperado, 0.0001));
  });
}
