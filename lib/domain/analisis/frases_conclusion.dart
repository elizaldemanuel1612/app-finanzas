// Fracciones en palabras para las frases-conclusión de Análisis ›
// Detalle (`docs/rediseno/plan-rediseno.md`, Etapa 5): "Salidas es la
// mitad de tus variables", "2 de cada 3 pesos van a tarjeta". Sin
// porcentajes que interpretar (addendum-v3 §3.3).

const _tolerancia = 0.04;

const _partes = [
  (1 / 2, 'la mitad', '1 de cada 2'),
  (1 / 3, 'un tercio', '1 de cada 3'),
  (2 / 3, 'dos tercios', '2 de cada 3'),
  (1 / 4, 'la cuarta parte', '1 de cada 4'),
  (3 / 4, 'tres cuartas partes', '3 de cada 4'),
  (1 / 5, 'la quinta parte', '1 de cada 5'),
  (4 / 5, 'cuatro quintas partes', '4 de cada 5'),
];

(double, String, String)? _cercana(double fraccion) {
  (double, String, String)? mejor;
  for (final p in _partes) {
    final distancia = (p.$1 - fraccion).abs();
    if (distancia <= _tolerancia && (mejor == null || distancia < (mejor.$1 - fraccion).abs())) mejor = p;
  }
  return mejor;
}

/// "la mitad", "un tercio"… o "el 42 %" si no se parece a ninguna.
String fraccionEnPalabras(double fraccion) => _cercana(fraccion)?.$2 ?? 'el ${(fraccion * 100).round()} %';

/// "2 de cada 3 pesos"… o "el 42 % de cada peso".
String deCadaPeso(double fraccion) {
  final p = _cercana(fraccion);
  return p == null ? 'el ${(fraccion * 100).round()} % de cada peso' : '${p.$3} pesos';
}

/// "5 veces más", "el doble", "un poco más": cuánto más es [mayor] que
/// [base]. `null` si no hay contra qué comparar.
String? vecesMas(int mayor, int base) {
  if (base <= 0) return null;
  final razon = mayor / base;
  if (razon >= 2.5) return '${razon.round()} veces más';
  if (razon >= 1.8) return 'el doble';
  return 'un poco más';
}
