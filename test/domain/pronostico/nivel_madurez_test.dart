import 'package:app_finanzas/domain/pronostico/nivel_madurez.dart';
import 'package:test/test.dart';

void main() {
  test('mapea el número de ciclos cerrados al nivel correcto (tabla §7)', () {
    expect(nivelMadurezMpc(0), NivelMadurezMpc.sinHistorial);
    expect(nivelMadurezMpc(1), NivelMadurezMpc.historicoSimple);
    expect(nivelMadurezMpc(2), NivelMadurezMpc.atipicosYCredibilidad);
    expect(nivelMadurezMpc(3), NivelMadurezMpc.atipicosYCredibilidad);
    expect(nivelMadurezMpc(4), NivelMadurezMpc.conEstacionalidad);
    expect(nivelMadurezMpc(6), NivelMadurezMpc.conEstacionalidad);
    expect(nivelMadurezMpc(7), NivelMadurezMpc.completo);
    expect(nivelMadurezMpc(20), NivelMadurezMpc.completo);
  });

  test('ciclos negativos se tratan como sin historial', () {
    expect(nivelMadurezMpc(-1), NivelMadurezMpc.sinHistorial);
  });

  test('el nivel completo no trae mensaje de advertencia', () {
    expect(mensajeNivelMadurez(NivelMadurezMpc.completo), isEmpty);
  });

  test('cada nivel intermedio trae su mensaje exacto de §7', () {
    expect(mensajeNivelMadurez(NivelMadurezMpc.sinHistorial), 'Sin historial. Mostrando tu presupuesto.');
    expect(mensajeNivelMadurez(NivelMadurezMpc.historicoSimple),
        'Pronóstico preliminar, 1 ciclo de historial.');
    expect(mensajeNivelMadurez(NivelMadurezMpc.atipicosYCredibilidad), 'Precisión limitada, mejora cada ciclo.');
    expect(mensajeNivelMadurez(NivelMadurezMpc.conEstacionalidad), 'Pronóstico con estacionalidad.');
  });
}
