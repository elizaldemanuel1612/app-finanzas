// Complementos de IA (spec-app-finanzas-v2.md §6.5, 2026-11-15): cada
// usuario conecta la suya; la app no paga ni guarda ninguna.

enum ProveedorIA {
  apple(
    nombre: 'Apple Intelligence',
    descripcion: 'En tu iPhone. Gratis y privado: no sale del teléfono.',
    requiereClave: false,
  ),
  gemini(
    nombre: 'Gemini',
    descripcion: 'De Google. Tiene uso gratuito.',
    urlClave: 'https://aistudio.google.com/apikey',
    sitioClave: 'Google AI Studio',
  ),
  chatgpt(
    nombre: 'ChatGPT',
    descripcion: 'De OpenAI. Se cobra en tu cuenta de API, aparte de ChatGPT Plus.',
    urlClave: 'https://platform.openai.com/api-keys',
    sitioClave: 'la plataforma de OpenAI',
  ),
  claude(
    nombre: 'Claude',
    descripcion: 'De Anthropic. Se cobra en tu cuenta de API, aparte de Claude Pro.',
    urlClave: 'https://console.anthropic.com/settings/keys',
    sitioClave: 'la consola de Anthropic',
  );

  final String nombre;
  final String descripcion;
  final bool requiereClave;
  final String? urlClave;
  final String? sitioClave;

  const ProveedorIA({
    required this.nombre,
    required this.descripcion,
    this.requiereClave = true,
    this.urlClave,
    this.sitioClave,
  });
}

/// Fechas en los ids: "20251001" o "2025-04-14".
final _fecha = RegExp(r'\d{4}-\d{2}-\d{2}|\d{6,}');

/// Los números de versión de un id de modelo ("gpt-4.1-mini" → [4, 1];
/// "claude-haiku-4-5-20251001" → [4, 5]); las fechas no cuentan.
List<int> _version(String id) =>
    [for (final m in RegExp(r'\d+').allMatches(id.replaceAll(_fecha, ''))) int.parse(m.group(0)!)];

bool _tieneFecha(String id) => _fecha.hasMatch(id);

int _compararVersion(String a, String b) {
  final va = _version(a);
  final vb = _version(b);
  for (var i = 0; i < va.length && i < vb.length; i++) {
    if (va[i] != vb[i]) return va[i].compareTo(vb[i]);
  }
  return va.length.compareTo(vb.length);
}

/// El mejor de [candidatos]: la versión más nueva y, a igual versión, el
/// alias sin fecha (que sigue al modelo al día).
String? _mejor(Iterable<String> candidatos) {
  final lista = candidatos.toList();
  if (lista.isEmpty) return null;
  lista.sort((a, b) {
    final porVersion = _compararVersion(b, a);
    if (porVersion != 0) return porVersion;
    return (_tieneFecha(a) ? 1 : 0).compareTo(_tieneFecha(b) ? 1 : 0);
  });
  return lista.first;
}

bool _contieneAlguna(String id, List<String> palabras) => palabras.any(id.contains);

const _noTexto = ['image', 'tts', 'audio', 'realtime', 'transcribe', 'embedding', 'live', 'search', 'vision', 'moderation'];

/// El modelo rápido y barato que usa la app, de entre los que el proveedor
/// dice tener ([ids], como los lista su API); `null` si ninguno sirve.
/// Para Apple no hay que elegir: es el modelo del sistema.
String? elegirModelo(ProveedorIA proveedor, List<String> ids) {
  final limpios = [for (final id in ids) id.replaceFirst('models/', '').toLowerCase()];
  bool util(String id) => !_contieneAlguna(id, _noTexto);
  switch (proveedor) {
    case ProveedorIA.apple:
      return null;
    case ProveedorIA.gemini:
      final gemini = limpios.where((id) => id.startsWith('gemini') && util(id));
      final estables = gemini.where((id) => !_contieneAlguna(id, ['preview', 'exp']));
      return _mejor(estables.where((id) => id.contains('flash') && !id.contains('lite'))) ??
          _mejor(gemini.where((id) => id.contains('flash') && !id.contains('lite'))) ??
          _mejor(estables) ??
          _mejor(gemini);
    case ProveedorIA.chatgpt:
      final gpt = limpios.where((id) => id.startsWith('gpt-') && util(id));
      return _mejor(gpt.where((id) => id.contains('mini'))) ?? _mejor(gpt);
    case ProveedorIA.claude:
      final claude = limpios.where((id) => id.startsWith('claude') && util(id));
      return _mejor(claude.where((id) => id.contains('haiku'))) ??
          _mejor(claude.where((id) => id.contains('sonnet'))) ??
          _mejor(claude);
  }
}
