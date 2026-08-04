import 'package:app_finanzas/domain/pronostico/subcaptura.dart';
import 'package:test/test.dart';

void main() {
  test('densidad >= 0.75 es normal', () {
    expect(
      calcularSenalSubcaptura(movimientosObservados: 8, movimientosEsperados: 10),
      SenalSubcaptura.normal,
    );
    expect(
      calcularSenalSubcaptura(movimientosObservados: 10, movimientosEsperados: 10),
      SenalSubcaptura.normal,
    );
  });

  test('densidad entre 0.40 y 0.74 levanta bandera', () {
    expect(
      calcularSenalSubcaptura(movimientosObservados: 5, movimientosEsperados: 10),
      SenalSubcaptura.bandera,
    );
  });

  test('densidad < 0.40 se marca no confiable', () {
    expect(
      calcularSenalSubcaptura(movimientosObservados: 2, movimientosEsperados: 10),
      SenalSubcaptura.noConfiable,
    );
  });

  test('sin movimientos esperados (0), no hay señal — se asume normal', () {
    expect(
      calcularSenalSubcaptura(movimientosObservados: 0, movimientosEsperados: 0),
      SenalSubcaptura.normal,
    );
  });

  test('límites exactos de las bandas', () {
    expect(
      calcularSenalSubcaptura(movimientosObservados: 75, movimientosEsperados: 100),
      SenalSubcaptura.normal,
    );
    expect(
      calcularSenalSubcaptura(movimientosObservados: 40, movimientosEsperados: 100),
      SenalSubcaptura.bandera,
    );
    expect(
      calcularSenalSubcaptura(movimientosObservados: 39, movimientosEsperados: 100),
      SenalSubcaptura.noConfiable,
    );
  });
}
