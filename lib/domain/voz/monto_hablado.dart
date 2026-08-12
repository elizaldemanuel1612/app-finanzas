import '../../core/money.dart';

const _unidades = [
  '', 'uno', 'dos', 'tres', 'cuatro', 'cinco', //
  'seis', 'siete', 'ocho', 'nueve',
];

const _diez19 = [
  'diez', 'once', 'doce', 'trece', 'catorce', //
  'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve',
];

const _veinti = [
  'veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', //
  'veinticinco', 'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve',
];

const _decenas = [
  '', '', '', 'treinta', 'cuarenta', 'cincuenta', //
  'sesenta', 'setenta', 'ochenta', 'noventa',
];

const _centenas = [
  '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', //
  'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos',
];

/// Lee un monto en voz alta, para `semanticsLabel` de las cifras héroe y
/// el total de la lista de gastos (Fase 6, Bloque 4.3) — el complemento
/// inverso de `numero_hablado.dart` (que convierte palabras a número; esto
/// convierte número a palabras).
///
/// "$1,234.56" → "mil doscientos treinta y cuatro pesos con cincuenta y
/// seis centavos". Los centavos en cero se omiten ("cien pesos", no "cien
/// pesos con cero centavos") — decirlos siempre sería ruido en el caso más
/// común. Soporta hasta 999,999,999 pesos; un monto mayor no es un caso
/// real en gasto personal, así que se trunca la lectura con "...y más" en
/// vez de fallar.
String montoEnPalabras(Dinero monto) {
  final negativo = monto.centavos < 0;
  final absoluto = monto.centavos.abs();
  final pesos = absoluto ~/ 100;
  final centavos = absoluto % 100;

  final pesosTexto = pesos == 0
      ? 'cero pesos'
      : '${_cantidad(pesos)} ${_palabraPesos(pesos)}';
  final centavosTexto = centavos == 0
      ? ''
      : ' con ${_cantidad(centavos)} ${_palabraCentavos(centavos)}';

  return '${negativo ? 'menos ' : ''}$pesosTexto$centavosTexto';
}

/// "un" antes de "peso"/"centavo", no "uno" — la única apócope que se
/// corrige aquí. Dentro de un compuesto ("veintiuno", "treinta y uno") se
/// deja "uno" tal cual: la forma gramaticalmente exacta sería "veintiún"/
/// "treinta y un", pero para un `semanticsLabel` leído por un lector de
/// pantalla la claridad importa más que la apócope — se documenta como
/// simplificación consciente, no como error.
String _cantidad(int n) => n == 1 ? 'un' : _numeroEnPalabras(n);

String _palabraPesos(int n) => n == 1 ? 'peso' : 'pesos';
String _palabraCentavos(int n) => n == 1 ? 'centavo' : 'centavos';

/// [n] siempre es positivo aquí — el signo y el caso cero ya se resolvieron
/// en [montoEnPalabras] antes de llamar a esta función.
String _numeroEnPalabras(int n) {
  if (n >= 1000000000) {
    return '${_numeroEnPalabras(n ~/ 1000000000)} mil millones y más';
  }
  if (n >= 1000000) {
    final millones = n ~/ 1000000;
    final resto = n % 1000000;
    final palabraMillones = millones == 1
        ? 'un millón'
        : '${_numeroEnPalabras(millones)} millones';
    return resto == 0
        ? palabraMillones
        : '$palabraMillones ${_numeroEnPalabras(resto)}';
  }
  if (n >= 1000) {
    final miles = n ~/ 1000;
    final resto = n % 1000;
    final palabraMiles = miles == 1 ? 'mil' : '${_numeroEnPalabras(miles)} mil';
    return resto == 0
        ? palabraMiles
        : '$palabraMiles ${_numeroEnPalabras(resto)}';
  }
  if (n >= 100) {
    final centena = n ~/ 100;
    final resto = n % 100;
    if (centena == 1 && resto == 0) return 'cien';
    final palabraCentena = _centenas[centena];
    return resto == 0
        ? palabraCentena
        : '$palabraCentena ${_numeroEnPalabras(resto)}';
  }
  if (n >= 30) {
    final decena = n ~/ 10;
    final unidad = n % 10;
    return unidad == 0
        ? _decenas[decena]
        : '${_decenas[decena]} y ${_unidades[unidad]}';
  }
  if (n >= 20) return _veinti[n - 20];
  if (n >= 10) return _diez19[n - 10];
  return _unidades[n];
}
