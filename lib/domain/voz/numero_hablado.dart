/// Convierte números escritos en palabras (español) a enteros, mezclados
/// libremente con dígitos ("3 mil 132", "mil doscientos", "cuatrocientos
/// ochenta"). Solo pesos completos — spec-app-finanzas-v2.md §5.3 nota
/// explícitamente que los centavos hablados ("cuarenta y ocho cincuenta")
/// no se intentan interpretar; eso queda para dígitos escritos o ticket.
library;

const _unidades = {
  'cero': 0, 'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4,
  'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, //
  'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15,
  'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19,
  'veinte': 20, 'veintiuno': 21, 'veintidos': 22, 'veintitres': 23,
  'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26, 'veintisiete': 27,
  'veintiocho': 28, 'veintinueve': 29,
};

const _decenas = {
  'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, //
  'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90,
};

const _centenas = {
  'cien': 100, 'ciento': 100, 'doscientos': 200, 'trescientos': 300,
  'cuatrocientos': 400, 'quinientos': 500, 'seiscientos': 600, //
  'setecientos': 700, 'ochocientos': 800, 'novecientos': 900,
};

/// Palabras que forman parte de un número hablado (incluye "mil" y el
/// conector "y" que solo es válido entre decena y unidad: "treinta y dos").
bool esPalabraDeNumero(String palabra) {
  final p = palabra.toLowerCase();
  return p == 'mil' ||
      p == 'y' ||
      RegExp(r'^\d+$').hasMatch(p) ||
      _unidades.containsKey(p) ||
      _decenas.containsKey(p) ||
      _centenas.containsKey(p);
}

/// Convierte una lista de tokens ya identificados como "de número"
/// (ver [esPalabraDeNumero]) a su valor entero. Regresa `null` si la
/// secuencia no forma un número válido (ej. solo un "y" suelto).
int? valorDeTokensNumericos(List<String> tokens) {
  var total = 0;
  var actual = 0;
  var huboValor = false;

  for (final token in tokens) {
    final p = token.toLowerCase();
    if (p == 'y') continue;
    final comoDigito = int.tryParse(p);
    if (comoDigito != null) {
      actual += comoDigito;
      huboValor = true;
    } else if (p == 'mil') {
      actual = (actual == 0 ? 1 : actual) * 1000;
      total += actual;
      actual = 0;
      huboValor = true;
    } else if (_centenas.containsKey(p)) {
      actual += _centenas[p]!;
      huboValor = true;
    } else if (_decenas.containsKey(p)) {
      actual += _decenas[p]!;
      huboValor = true;
    } else if (_unidades.containsKey(p)) {
      actual += _unidades[p]!;
      huboValor = true;
    }
  }

  if (!huboValor) return null;
  return total + actual;
}
