// Guarda WCAG AA (Fase 6, Bloque 4.1): fuerza a que las correcciones de
// contraste de lib/ui/comun/paleta.dart no se reviertan por accidente.
// `razonDeContraste` es aritmética pura (dart:math, no Flutter), así que
// esto corre bajo `dart test` sin árbol de widgets — mismo truco que
// arquitectura_test.dart.
import 'package:app_finanzas/ui/comun/paleta.dart';
import 'package:test/test.dart';

const _minimoTexto = 4.5; // WCAG AA, texto normal.
const _minimoGrafico = 3.0; // WCAG AA, elementos gráficos/UI.

void main() {
  group('razonDeContraste — casos de referencia', () {
    test('negro sobre blanco es 21:1', () {
      expect(razonDeContraste(0x000000, 0xFFFFFF), closeTo(21.0, 0.05));
    });

    test('un color contra sí mismo es 1:1', () {
      expect(razonDeContraste(PaletaHex.tinta, PaletaHex.tinta), closeTo(1.0, 0.001));
    });

    test('es simétrico sin importar el orden de los argumentos', () {
      final a = razonDeContraste(PaletaHex.medio, PaletaHex.fondo);
      final b = razonDeContraste(PaletaHex.fondo, PaletaHex.medio);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('paleta de texto — WCAG AA 4.5:1', () {
    test('medio sobre fondo marfil pasa', () {
      expect(razonDeContraste(PaletaHex.medio, PaletaHex.fondo), greaterThanOrEqualTo(_minimoTexto));
    });

    test('tinta sobre fondo pasa de sobra', () {
      expect(razonDeContraste(PaletaHex.tinta, PaletaHex.fondo), greaterThanOrEqualTo(_minimoTexto));
    });

    test('verdeTexto sobre blanco pasa (verde brillante no pasa: 3.30:1)', () {
      expect(razonDeContraste(PaletaHex.verde, PaletaHex.tarjeta), lessThan(_minimoTexto));
      expect(razonDeContraste(PaletaHex.verdeTexto, PaletaHex.tarjeta), greaterThanOrEqualTo(_minimoTexto));
    });

    test('ambarTexto sobre blanco pasa (ambar brillante no pasa: 2.15:1)', () {
      expect(razonDeContraste(PaletaHex.ambar, PaletaHex.tarjeta), lessThan(_minimoTexto));
      expect(razonDeContraste(PaletaHex.ambarTexto, PaletaHex.tarjeta), greaterThanOrEqualTo(_minimoTexto));
    });

    test('coralTexto sobre blanco pasa (coral brillante no pasa: 3.76:1)', () {
      expect(razonDeContraste(PaletaHex.coral, PaletaHex.tarjeta), lessThan(_minimoTexto));
      expect(razonDeContraste(PaletaHex.coralTexto, PaletaHex.tarjeta), greaterThanOrEqualTo(_minimoTexto));
    });

    test('las variantes Texto también pasan sobre su tinte Suave', () {
      expect(razonDeContraste(PaletaHex.verdeTexto, PaletaHex.verdeSuave), greaterThanOrEqualTo(_minimoTexto));
      expect(razonDeContraste(PaletaHex.ambarTexto, PaletaHex.ambarSuave), greaterThanOrEqualTo(_minimoTexto));
      expect(razonDeContraste(PaletaHex.coralTexto, PaletaHex.coralSuave), greaterThanOrEqualTo(_minimoTexto));
    });

    test('blanco sobre tinta (cifras en tarjeta oscura) pasa de sobra', () {
      expect(razonDeContraste(0xFFFFFF, PaletaHex.tinta), greaterThanOrEqualTo(_minimoTexto));
    });
  });

  group('paleta brillante — solo se usa donde aplica el umbral gráfico (3:1), nunca como texto', () {
    // El contraste es simétrico (no importa cuál color es "fondo" y cuál
    // "primer plano"), así que blanco-sobre-coral y coral-sobre-blanco dan
    // el mismo número. Ninguno de los tres brillantes llega a 4.5:1 —
    // exactamente por eso NUNCA se usan como color de texto directo (para
    // eso están verdeTexto/ambarTexto/coralTexto, probados arriba).
    //
    // Dónde sí aparecen en la app, y bajo qué umbral hay que juzgarlos:
    //   - Ícono blanco sobre relleno sólido (Dismissible, swipe-to-delete):
    //     umbral gráfico WCAG 1.4.11, 3:1. `verde` (2.62:1) queda por
    //     debajo incluso de ese umbral — gap real, documentado en
    //     docs/tiendas/checklist-publicacion.md como deuda de
    //     accesibilidad, no corregido en este bloque para no cambiar el
    //     color de marca sin acordarlo antes.
    //   - Tinte al 15% de alpha como fondo de chip, con su propia
    //     variante `Texto` para el texto (probado arriba).
    // Esta prueba fija los valores actuales como regresión: si alguien
    // cambia un hex y el número se mueve, hay que revisar a propósito
    // dónde se usa antes de actualizar el valor esperado aquí.
    test('coral sobre blanco pasa el umbral gráfico 3:1 (icono en Dismissible)', () {
      expect(razonDeContraste(PaletaHex.coral, PaletaHex.tarjeta), greaterThanOrEqualTo(_minimoGrafico));
    });

    test('valores actuales de los brillantes sobre blanco, fijados como regresión', () {
      // Paleta premium (2026-10-25): el verde ya pasa el umbral gráfico
      // 3:1 (antes 2.62:1), lo que cierra la deuda del ícono blanco sobre
      // verde en el Dismissible.
      expect(razonDeContraste(PaletaHex.verde, PaletaHex.tarjeta), closeTo(3.30, 0.02));
      expect(razonDeContraste(PaletaHex.ambar, PaletaHex.tarjeta), closeTo(2.15, 0.02));
      expect(razonDeContraste(PaletaHex.coral, PaletaHex.tarjeta), closeTo(3.76, 0.02));
    });

    test('verde también pasa ya el umbral gráfico 3:1', () {
      expect(razonDeContraste(PaletaHex.verde, PaletaHex.tarjeta), greaterThanOrEqualTo(_minimoGrafico));
    });
  });

  group('acentos de la dirección premium', () {
    test('el oro nunca es texto sobre blanco; su variante oroTexto sí pasa', () {
      expect(razonDeContraste(PaletaHex.oro, PaletaHex.tarjeta), lessThan(_minimoTexto));
      expect(razonDeContraste(PaletaHex.oroTexto, PaletaHex.tarjeta), greaterThanOrEqualTo(_minimoTexto));
      expect(razonDeContraste(PaletaHex.oroTexto, PaletaHex.oroSuave), greaterThanOrEqualTo(_minimoTexto));
    });

    test('azul noche sobre oro (botón de registrar) y blanco sobre azul pasan', () {
      expect(razonDeContraste(PaletaHex.azul, PaletaHex.oro), greaterThanOrEqualTo(_minimoTexto));
      expect(razonDeContraste(0xFFFFFF, PaletaHex.azul), greaterThanOrEqualTo(_minimoTexto));
      expect(razonDeContraste(PaletaHex.azul, PaletaHex.azulSuave), greaterThanOrEqualTo(_minimoTexto));
    });
  });

  group('modo oscuro — WCAG AA', () {
    final pares = <String, (int, int)>{
      'tinta sobre fondo': (PaletaHexOscura.tinta, PaletaHexOscura.fondo),
      'tinta sobre tarjeta': (PaletaHexOscura.tinta, PaletaHexOscura.tarjeta),
      'medio sobre fondo': (PaletaHexOscura.medio, PaletaHexOscura.fondo),
      'medio sobre tarjeta': (PaletaHexOscura.medio, PaletaHexOscura.tarjeta),
      'medio sobre azulSuave': (PaletaHexOscura.medio, PaletaHexOscura.azulSuave),
      'azul (texto) sobre fondo': (PaletaHexOscura.azul, PaletaHexOscura.fondo),
      'azul (texto) sobre tarjeta': (PaletaHexOscura.azul, PaletaHexOscura.tarjeta),
      'azul (texto) sobre azulSuave': (PaletaHexOscura.azul, PaletaHexOscura.azulSuave),
      'sobreAzul sobre azul (botón)': (PaletaHexOscura.sobreAzul, PaletaHexOscura.azul),
      'oroTexto sobre tarjeta': (PaletaHexOscura.oroTexto, PaletaHexOscura.tarjeta),
      'oroTexto sobre oroSuave': (PaletaHexOscura.oroTexto, PaletaHexOscura.oroSuave),
      'verdeTexto sobre tarjeta': (PaletaHexOscura.verdeTexto, PaletaHexOscura.tarjeta),
      'verdeTexto sobre verdeSuave': (PaletaHexOscura.verdeTexto, PaletaHexOscura.verdeSuave),
      'ambarTexto sobre tarjeta': (PaletaHexOscura.ambarTexto, PaletaHexOscura.tarjeta),
      'ambarTexto sobre ambarSuave': (PaletaHexOscura.ambarTexto, PaletaHexOscura.ambarSuave),
      'coralTexto sobre tarjeta': (PaletaHexOscura.coralTexto, PaletaHexOscura.tarjeta),
      'coralTexto sobre coralSuave': (PaletaHexOscura.coralTexto, PaletaHexOscura.coralSuave),
    };
    for (final MapEntry(key: nombre, value: (a, b)) in pares.entries) {
      test('$nombre pasa 4.5:1', () {
        expect(razonDeContraste(a, b), greaterThanOrEqualTo(_minimoTexto));
      });
    }

    test('los brillantes pasan el umbral gráfico sobre tarjeta', () {
      for (final c in [PaletaHexOscura.verde, PaletaHexOscura.ambar, PaletaHexOscura.coral, PaletaHexOscura.oro, PaletaHexOscura.azul]) {
        expect(razonDeContraste(c, PaletaHexOscura.tarjeta), greaterThanOrEqualTo(_minimoGrafico));
      }
    });

    test('el azul noche de marca lleva texto blanco en los dos modos', () {
      expect(razonDeContraste(0xFFFFFF, PaletaHex.noche), greaterThanOrEqualTo(_minimoTexto));
    });
  });
}

