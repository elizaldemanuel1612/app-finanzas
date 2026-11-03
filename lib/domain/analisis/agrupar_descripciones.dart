import '../clasificacion/normalizacion_texto.dart';

/// Palabras que no dicen en qué se gastó.
const _vacias = {
  'un', 'una', 'unos', 'unas', 'el', 'la', 'los', 'las', 'de', 'del', 'y', 'e', 'en', 'con',
  'para', 'por', 'al', 'a', 'mi', 'mis', 'su', 'sus', 'lo',
};

/// Palabras normalizadas: sin acentos, sin signos, en singular y sin
/// palabras vacías ("Un café" → `cafe`; "Pan y cafés" → `pan`, `cafe`).
List<String> _palabras(String texto) => [
      for (final p in normalizarTexto(texto).split(RegExp(r'[^a-zñ0-9]+')))
        if (p.isNotEmpty && !_vacias.contains(p)) _singular(p),
    ];

/// "panes" → pan y "papeles" → papel (vocal + consonante + es), pero
/// "chicles" → chicle y "postres" → postre (solo se quita la s).
String _singular(String p) {
  if (p.length > 4 &&
      p.endsWith('es') &&
      'lnrdj'.contains(p[p.length - 3]) &&
      'aeiou'.contains(p[p.length - 4])) {
    return p.substring(0, p.length - 2);
  }
  if (p.length > 3 && p.endsWith('s') && !p.endsWith('ss')) return p.substring(0, p.length - 1);
  return p;
}

/// A qué grupo va cada descripción de "Dónde más gastas"
/// (spec-app-finanzas-v2.md §5.7), y con qué nombre se muestra.
///
/// Un **concepto** es lo que alguna vez se escribió solo ("café", "Cafés",
/// "un café"). Una descripción que es un concepto va a su grupo; una más
/// larga ("pan y café") va al concepto más frecuente que contenga, y si no
/// contiene ninguno se queda como está. Así "cena con amigos" y "comida con
/// amigos" no se juntan por compartir "amigos".
///
/// [frecuencia] dice cuántas veces aparece cada descripción (las repetidas
/// pesan más al elegir concepto y nombre).
({String Function(String) grupo, String Function(String) nombre}) agruparDescripciones(
  Map<String, int> frecuencia,
) {
  String clave(String texto) => _palabras(texto).join(' ');

  final pesoConcepto = <String, int>{};
  // Cómo se escribió cada concepto, para mostrarlo bonito.
  final formas = <String, Map<String, int>>{};
  for (final MapEntry(key: texto, value: veces) in frecuencia.entries) {
    final palabras = _palabras(texto);
    if (palabras.length != 1) continue;
    final concepto = palabras.single;
    pesoConcepto[concepto] = (pesoConcepto[concepto] ?? 0) + veces;
    for (final original in texto.trim().split(RegExp(r'\s+'))) {
      final limpia = original.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
      if (_palabras(limpia).join() != concepto) continue;
      final porForma = formas.putIfAbsent(concepto, () => {});
      porForma[limpia] = (porForma[limpia] ?? 0) + veces;
    }
  }

  String grupo(String texto) {
    final palabras = _palabras(texto);
    if (palabras.isEmpty) return normalizarTexto(texto);
    String? mejor;
    for (final p in palabras) {
      final peso = pesoConcepto[p];
      if (peso != null && (mejor == null || peso > pesoConcepto[mejor]!)) mejor = p;
    }
    return mejor ?? clave(texto);
  }

  String nombre(String grupoClave) {
    final porForma = formas[grupoClave];
    if (porForma == null || porForma.isEmpty) {
      // Sin concepto: el texto más frecuente de ese grupo.
      String? elegido;
      var veces = 0;
      for (final e in frecuencia.entries) {
        if (grupo(e.key) == grupoClave && e.value > veces) {
          elegido = e.key.trim();
          veces = e.value;
        }
      }
      return _capital(elegido ?? grupoClave);
    }
    // La forma en singular primero, luego la más usada, luego la que trae
    // acento ("café" antes que "cafe").
    final candidatas = porForma.entries.toList()
      ..sort((a, b) {
        final singular = (_esSingular(b.key, grupoClave) ? 1 : 0) - (_esSingular(a.key, grupoClave) ? 1 : 0);
        if (singular != 0) return singular;
        final usos = b.value.compareTo(a.value);
        if (usos != 0) return usos;
        return _acentos(b.key).compareTo(_acentos(a.key));
      });
    return _capital(candidatas.first.key);
  }

  return (grupo: grupo, nombre: nombre);
}

bool _esSingular(String forma, String concepto) => normalizarTexto(forma) == concepto;

int _acentos(String texto) => texto.runes.where((r) => r > 0x7F).length;

String _capital(String texto) => texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
