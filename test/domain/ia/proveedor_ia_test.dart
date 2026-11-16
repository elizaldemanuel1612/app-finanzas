import 'package:app_finanzas/domain/ia/proveedor_ia.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §6.5: de los modelos que dice tener Gemini,
// uno rápido y barato; a igual versión, el alias sin fecha.

void main() {
  test('Gemini: el flash estable más nuevo, sin lite, ni vista previa, ni de imagen', () {
    expect(
      elegirModelo(ProveedorIA.gemini, [
        'models/gemini-2.0-flash',
        'models/gemini-2.5-flash',
        'models/gemini-2.5-flash-lite',
        'models/gemini-3.0-flash-preview',
        'models/gemini-2.5-flash-image',
        'models/gemini-2.5-pro',
        'models/text-embedding-004',
      ]),
      'gemini-2.5-flash',
    );
    // Si solo hay vista previa de flash, sirve; si no hay flash, el más nuevo.
    expect(elegirModelo(ProveedorIA.gemini, ['models/gemini-3.0-flash-preview', 'models/gemini-2.5-pro']),
        'gemini-3.0-flash-preview');
    expect(elegirModelo(ProveedorIA.gemini, ['models/gemini-2.5-pro', 'models/gemini-1.5-pro']), 'gemini-2.5-pro');
    expect(elegirModelo(ProveedorIA.gemini, ['models/gemini-exp-1206']), 'gemini-exp-1206');
    expect(elegirModelo(ProveedorIA.gemini, ['models/embedding-001']), isNull);
  });

  test('a igual versión gana el alias sin fecha; una revisión numerada es más nueva', () {
    expect(elegirModelo(ProveedorIA.gemini, ['models/gemini-2.5-flash-20250617', 'models/gemini-2.5-flash']), 'gemini-2.5-flash');
    expect(elegirModelo(ProveedorIA.gemini, ['models/gemini-2.5-flash', 'models/gemini-2.5-flash-002']), 'gemini-2.5-flash-002');
  });

  test('solo Apple y Gemini: ChatGPT y Claude se quitaron (cobran aparte)', () {
    expect(ProveedorIA.values, [ProveedorIA.apple, ProveedorIA.gemini]);
  });

  test('Apple no elige modelo; los demás traen dónde sacar la clave', () {
    expect(elegirModelo(ProveedorIA.apple, ['x']), isNull);
    expect(ProveedorIA.apple.requiereClave, isFalse);
    for (final p in ProveedorIA.values.where((p) => p.requiereClave)) {
      expect(p.urlClave, startsWith('https://'));
      expect(p.sitioClave, isNotEmpty);
    }
  });
}
