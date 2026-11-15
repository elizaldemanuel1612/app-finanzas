import 'package:app_finanzas/domain/ia/proveedor_ia.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §6.5: de los modelos que dice tener cada
// proveedor, uno rápido y barato; a igual versión, el alias sin fecha.

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

  test('ChatGPT: el mini más nuevo y, a igual versión, el alias sin fecha', () {
    expect(
      elegirModelo(ProveedorIA.chatgpt, [
        'gpt-4o-mini',
        'gpt-4.1-mini-2025-04-14',
        'gpt-4.1-mini',
        'gpt-4o-mini-audio-preview',
        'gpt-4o-mini-realtime-preview',
        'gpt-5',
        'dall-e-3',
      ]),
      'gpt-4.1-mini',
    );
    expect(elegirModelo(ProveedorIA.chatgpt, ['gpt-4o-mini', 'gpt-4.1-mini-2025-04-14', 'gpt-4.1-mini', 'gpt-4.1']),
        'gpt-4.1-mini');
    expect(elegirModelo(ProveedorIA.chatgpt, ['gpt-4o', 'gpt-4.1']), 'gpt-4.1');
    expect(elegirModelo(ProveedorIA.chatgpt, ['whisper-1']), isNull);
  });

  test('Claude: haiku, luego sonnet, luego el que haya', () {
    expect(
      elegirModelo(ProveedorIA.claude, [
        'claude-sonnet-4-5-20250929',
        'claude-haiku-4-5-20251001',
        'claude-haiku-4-5',
        'claude-3-5-haiku-20241022',
      ]),
      'claude-haiku-4-5',
    );
    expect(elegirModelo(ProveedorIA.claude, ['claude-opus-4-1', 'claude-sonnet-4-5']), 'claude-sonnet-4-5');
    expect(elegirModelo(ProveedorIA.claude, ['claude-opus-4-1']), 'claude-opus-4-1');
    expect(elegirModelo(ProveedorIA.claude, const []), isNull);
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
