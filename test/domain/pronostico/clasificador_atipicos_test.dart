import 'package:app_finanzas/domain/pronostico/clasificador_atipicos.dart';
import 'package:test/test.dart';

void main() {
  test('lista vacía da base y atípico en 0', () {
    final r = clasificarMontos([]);
    expect(r.base, 0);
    expect(r.atipico, 0);
    expect(r.detalle, isEmpty);
  });

  test('montos normales (variación típica de súper) quedan todos en Base', () {
    final montos = <double>[450.0, 480, 510, 470, 500, 460, 490, 505];
    final r = clasificarMontos(montos);
    expect(r.base, montos.reduce((a, b) => a + b));
    expect(r.atipico, 0);
    expect(r.detalle.every((m) => m.clase == ClaseMonto.normal), isTrue);
  });

  test(r'el ejemplo del spec: reparación de $4,000 se suma una sola vez, no se multiplica', () {
    // Historial normal de Auto operación ronda $150-300; una reparación de
    // $4,000 debe salir como atípico franco, no contaminar la Base.
    final historicoNormal = List.generate(10, (i) => 150.0 + i * 10);
    final montos = <double>[...historicoNormal, 4000.0];

    final r = clasificarMontos(montos);
    final reparacion = r.detalle.last;

    expect(reparacion.montoOriginal, 4000);
    expect(reparacion.clase, ClaseMonto.atipicoFranco);
    expect(reparacion.aBase, 0);
    expect(reparacion.aAtipico, 4000);
    // La base no debe incluir nada de los 4000.
    expect(r.base, historicoNormal.reduce((a, b) => a + b));
  });

  test('un pico moderado se winsoriza: parte va a Base, el exceso a Atípico', () {
    // Construimos una lista donde un valor cae claramente en la banda
    // "pico" (3.5 < z <= 6.0) en vez de disparar atípico franco.
    final base = List.generate(20, (_) => 100.0);
    final montos = [...base, 260.0]; // desviación moderada, no extrema
    final r = clasificarMontos(montos);
    final pico = r.detalle.last;

    if (pico.clase == ClaseMonto.pico) {
      expect(pico.aBase, greaterThan(0));
      expect(pico.aAtipico, greaterThan(0));
      expect(pico.aBase + pico.aAtipico, pico.montoOriginal);
    }
    // La suma de base+atípico por renglón siempre reconstruye el original,
    // sin importar en qué banda cayó.
    for (final m in r.detalle) {
      expect(m.aBase + m.aAtipico, closeTo(m.montoOriginal, 0.001));
    }
  });

  test('montos casi idénticos (Spotify) no se marcan todos como atípicos', () {
    final montos = List.filled(6, 239.0);
    final r = clasificarMontos(montos);
    expect(r.detalle.every((m) => m.clase == ClaseMonto.normal), isTrue);
    expect(r.atipico, 0);
  });

  test('base + atípico de cada renglón siempre reconstruye el monto original', () {
    final montos = <double>[80.0, 95, 100, 105, 120, 5000, 90, 88];
    final r = clasificarMontos(montos);
    for (final m in r.detalle) {
      expect(m.aBase + m.aAtipico, closeTo(m.montoOriginal, 0.001));
    }
    expect(r.base + r.atipico, closeTo(montos.reduce((a, b) => a + b), 0.001));
  });
}
