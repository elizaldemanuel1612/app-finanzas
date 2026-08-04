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
  final porComas = texto.split(',');
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

  // Agrupa corridas contiguas de tokens numéricos en candidatos de monto.
  final montos = <int>[];
  final indicesUsados = <int>{};
  var i = 0;
  while (i < tokensLimpios.length) {
    if (esPalabraDeNumero(tokensLimpios[i])) {
      final inicio = i;
      final corrida = <String>[];
      while (i < tokensLimpios.length && esPalabraDeNumero(tokensLimpios[i])) {
        corrida.add(tokensLimpios[i]);
        i++;
      }
      final valor = valorDeTokensNumericos(corrida);
      if (valor != null && valor > 0) {
        montos.add(valor);
        for (var j = inicio; j < i; j++) {
          indicesUsados.add(j);
        }
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
      montosAmbiguos: montos.map(Dinero.pesos).toList(),
      descripcion: descripcion,
      medio: medio,
      categoriaId: categoriaId,
      textoOriginal: segmento,
    );
  }

  return GastoDictado(
    monto: Dinero.pesos(montos.single),
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

String _quitarPuntuacion(String palabra) =>
    palabra.replaceAll(RegExp(r'[^\wÁÉÍÓÚÜÑáéíóúüñ]'), '').toLowerCase();

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
