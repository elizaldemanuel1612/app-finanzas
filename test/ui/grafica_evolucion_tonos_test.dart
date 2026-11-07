import 'package:app_finanzas/ui/comun/grafica_evolucion.dart';
import 'package:app_finanzas/ui/comun/paleta.dart';
import 'package:flutter_test/flutter_test.dart';

/// Escala de alcance de «Cuánto has apartado por ciclo» (2026-11-06): el
/// rojo fuerte solo en negativo y el texto legible en los dos modos.
void main() {
  test('umbrales de la escala', () {
    expect(tonoDeAlcance(null), isNull);
    expect(tonoDeAlcance(-0.08), TonoAlcance.negativo);
    expect(tonoDeAlcance(0), TonoAlcance.lejos);
    expect(tonoDeAlcance(0.39), TonoAlcance.lejos);
    expect(tonoDeAlcance(0.42), TonoAlcance.abajo);
    expect(tonoDeAlcance(0.73), TonoAlcance.cerca);
    expect(tonoDeAlcance(0.91), TonoAlcance.casi);
    expect(tonoDeAlcance(1.0), TonoAlcance.logrado);
    expect(tonoDeAlcance(1.4), TonoAlcance.logrado);
  });

  test('el texto de cada tono pasa AA sobre la tarjeta, en claro y en oscuro', () {
    for (final tono in TonoAlcance.values) {
      expect(razonDeContraste(tono.textoClaro, PaletaHex.tarjeta), greaterThanOrEqualTo(4.5), reason: '$tono claro');
      expect(razonDeContraste(tono.textoOscuro, PaletaHexOscura.tarjeta), greaterThanOrEqualTo(4.5), reason: '$tono oscuro');
    }
  });
}
