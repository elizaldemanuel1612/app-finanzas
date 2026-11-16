import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/movimiento.dart';
import 'numero_hablado.dart';

/// Un gasto que el parser extrajo de una frase dictada. [monto] es `null`
/// cuando la frase tiene más de un número candidato y no hay forma segura
/// de saber cuál es el monto (spec-app-finanzas-v2.md §5.3, ej. "doce
/// tacos de treinta pesos" detecta 12 y 30) — en ese caso [montosAmbiguos]
/// trae los candidatos para que la persona elija, en vez de que la app
/// adivine y guarde algo mal.
final class GastoDictado {
  final Dinero? monto;
  final List<Dinero> montosAmbiguos;
  final String descripcion;
  final MedioPago medio;
  final String? categoriaId;
  final String textoOriginal;

  const GastoDictado({
    required this.monto,
    this.montosAmbiguos = const [],
    required this.descripcion,
    required this.medio,
    required this.categoriaId,
    required this.textoOriginal,
  });

  bool get esAmbiguo => monto == null;

  @override
  String toString() => 'GastoDictado("$textoOriginal" → '
      '${monto ?? "ambiguo:$montosAmbiguos"}, $descripcion, ${medio.name}, cat=$categoriaId)';
}

const _decenasQuePrecedenY = {
  'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa',
};

final _verbosDeApertura = RegExp(
  r'^\s*(gast[eé]|pagu[eé]|se me fue(?:ron)?)\s+',
  caseSensitive: false,
);

const _conectores = {'de', 'del', 'al', 'a', 'en', 'con', 'por', 'pesos', 'peso'};

/// Parsea una frase dictada (posiblemente con varios gastos separados por
/// comas o "y") en una lista de [GastoDictado]. No lanza excepciones: una
/// frase sin números reconocibles regresa una lista vacía.
List<GastoDictado> parsearDictado(String texto, {required List<Categoria> categorias}) {
  final limpio = texto.trim().replaceFirst(_verbosDeApertura, '');
  if (limpio.isEmpty) return [];

  final segmentos = _dividirEnSegmentos(limpio);
  final resultado = <GastoDictado>[];
  for (final segmento in segmentos) {
    final gasto = _parsearSegmento(segmento, categorias);
    if (gasto != null) resultado.add(gasto);
  }
  return resultado;
}

List<String> _dividirEnSegmentos(String texto) {
  // La coma de miles ("1,500") no separa gastos.
  final porComas = texto.split(RegExp(r'(?<!\d),|,(?!\d)'));
  final segmentos = <String>[];
  for (final chunk in porComas) {
    segmentos.addAll(_dividirPorY(chunk));
  }
  return segmentos.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// Divide por " y " salvo cuando la palabra justo antes es una decena
/// ("treinta y dos" no se separa en "treinta" / "dos").
List<String> _dividirPorY(String texto) {
  final tokens = texto.trim().split(RegExp(r'\s+'));
  final partes = <List<String>>[[]];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.toLowerCase() == 'y' &&
        i > 0 &&
        !_decenasQuePrecedenY.contains(tokens[i - 1].toLowerCase())) {
      partes.add([]);
      continue;
    }
    partes.last.add(token);
  }
  return partes.map((p) => p.join(' ')).toList();
}

GastoDictado? _parsearSegmento(String segmento, List<Categoria> categorias) {
  final tokensCrudos = segmento.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final tokensLimpios = tokensCrudos.map(_quitarPuntuacion).toList();

  // Agrupa corridas contiguas de tokens numéricos en candidatos de monto,
  // en centavos. Una cifra con decimales o signo ("\$1,250.50") es un monto
  // por sí sola; "230 pesos con 50 (centavos)" es uno solo.
  final montos = <int>[];
  final indicesUsados = <int>{};
  var i = 0;
  while (i < tokensLimpios.length) {
    final cifra = _cifraEscrita(tokensCrudos[i]);
    if (cifra != null) {
      if (cifra > 0) montos.add(cifra);
      indicesUsados.add(i);
      i++;
    } else if (esPalabraDeNumero(tokensLimpios[i]) && tokensLimpios[i] != 'y') {
      final inicio = i;
      final corrida = <String>[];
      while (i < tokensLimpios.length && esPalabraDeNumero(tokensLimpios[i]) && _cifraEscrita(tokensCrudos[i]) == null) {
        corrida.add(tokensLimpios[i]);
        i++;
      }
      final valor = valorDeTokensNumericos(corrida);
      if (valor != null && valor > 0) {
        var centavos = valor * 100;
        for (var j = inicio; j < i; j++) {
          indicesUsados.add(j);
        }
        // "… pesos con cincuenta (centavos)".
        final conCentavos = _centavosDespues(tokensLimpios, i);
        if (conCentavos != null) {
          centavos += conCentavos.centavos;
          for (var j = i; j < conCentavos.fin; j++) {
            indicesUsados.add(j);
          }
          i = conCentavos.fin;
        }
        montos.add(centavos);
      }
    } else {
      i++;
    }
  }

  if (montos.isEmpty) return null;

  final medio = RegExp(r'\befectivo\b', caseSensitive: false).hasMatch(segmento)
      ? MedioPago.efectivo
      : MedioPago.tarjeta;

  final categoriaId = _inferirCategoria(segmento, categorias);

  final palabrasDescripcion = <String>[];
  for (var k = 0; k < tokensCrudos.length; k++) {
    if (indicesUsados.contains(k)) continue;
    final palabra = tokensLimpios[k];
    if (palabra.isEmpty) continue;
    if (_conectores.contains(palabra)) continue;
    if (palabra == 'tarjeta' || palabra == 'efectivo') continue;
    palabrasDescripcion.add(tokensCrudos[k]);
  }
  var descripcion = palabrasDescripcion.join(' ').trim();
  if (descripcion.isEmpty) {
    String? nombreCategoria;
    for (final c in categorias) {
      if (c.id == categoriaId) {
        nombreCategoria = c.nombre;
        break;
      }
    }
    descripcion = nombreCategoria ?? segmento.trim();
  }
  descripcion = descripcion[0].toUpperCase() + descripcion.substring(1);

  if (montos.length > 1) {
    return GastoDictado(
      monto: null,
      montosAmbiguos: [for (final m in montos) Dinero(m)],
      descripcion: descripcion,
      medio: medio,
      categoriaId: categoriaId,
      textoOriginal: segmento,
    );
  }

  return GastoDictado(
    monto: Dinero(montos.single),
    descripcion: descripcion,
    medio: medio,
    categoriaId: categoriaId,
    textoOriginal: segmento,
  );
}

String? _inferirCategoria(String segmento, List<Categoria> categorias) {
  final normalizado = _quitarAcentos(segmento.toLowerCase());
  String? mejorId;
  var mejorLargo = 0;
  for (final categoria in categorias.where((c) => c.activa)) {
    for (final palabra in _quitarAcentos(categoria.nombre.toLowerCase()).split(RegExp(r'[\s/]+'))) {
      if (palabra.length < 4) continue;
      if (normalizado.contains(palabra) && palabra.length > mejorLargo) {
        mejorId = categoria.id;
        mejorLargo = palabra.length;
      }
    }
  }
  return mejorId;
}

/// Minúsculas y sin acentos ("veintidós" se reconoce como número).
String _quitarPuntuacion(String palabra) =>
    _quitarAcentos(palabra.replaceAll(RegExp(r'[^\wÁÉÍÓÚÜÑáéíóúüñ]'), '').toLowerCase());

final _cifra = RegExp(r'^\$?(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$');

/// Una cifra escrita con signo de pesos, comas de miles o decimales, en
/// centavos ("\$1,250.50" → 125050). `null` si no es una de esas: un "230"
/// a secas sigue el camino de las palabras ("230 mil" funciona).
int? _cifraEscrita(String crudo) {
  final limpio = crudo.replaceAll(RegExp(r'[.,;:!?)]+$'), '').replaceAll(RegExp(r'^[(¿¡]+'), '');
  if (!limpio.contains(r'$') && !limpio.contains(',') && !limpio.contains('.')) return null;
  final m = _cifra.firstMatch(limpio);
  if (m == null) return null;
  final pesos = int.parse(m.group(1)!.replaceAll(',', ''));
  final decimales = m.group(2);
  final centavos = decimales == null ? 0 : int.parse(decimales.padRight(2, '0'));
  return pesos * 100 + centavos;
}

/// "pesos con cincuenta (centavos)" justo después de un monto: los
/// centavos y dónde termina. `null` si no viene eso.
({int centavos, int fin})? _centavosDespues(List<String> tokens, int i) {
  var k = i;
  if (k < tokens.length && (tokens[k] == 'pesos' || tokens[k] == 'peso')) k++;
  if (k >= tokens.length || tokens[k] != 'con') return null;
  k++;
  final inicio = k;
  final corrida = <String>[];
  while (k < tokens.length && esPalabraDeNumero(tokens[k])) {
    corrida.add(tokens[k]);
    k++;
  }
  if (k == inicio) return null;
  final valor = valorDeTokensNumericos(corrida);
  if (valor == null || valor <= 0 || valor >= 100) return null;
  if (k < tokens.length && (tokens[k] == 'centavos' || tokens[k] == 'centavo')) k++;
  return (centavos: valor, fin: k);
}

const _mapaAcentos = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
};

String _quitarAcentos(String texto) {
  var resultado = texto;
  _mapaAcentos.forEach((con, sin) {
    resultado = resultado.replaceAll(con, sin);
  });
  return resultado;
}
