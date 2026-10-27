import 'dart:math' as math;

/// Hex crudos de la paleta (dirección visual premium, 2026-10-25),
/// separados de `tema.dart` a propósito: este archivo **no importa
/// Flutter** (`dart:math` es Dart puro, no Flutter), así que
/// `test/ui_contraste_test.dart` puede probarlo con `dart test` sin
/// `flutter_test` ni árbol de widgets — el mismo truco de
/// `arquitectura_test.dart` para domain/core, aplicado a un archivo de
/// `ui/` (Fase 6, Bloque 4.1).
///
/// Los sufijos `Texto` son variantes oscurecidas de los colores brillantes
/// (`verde`, `ambar`, `coral`), pensadas **solo para texto** — WCAG AA
/// (4.5:1) sobre fondo blanco o `Suave`. Los colores brillantes se quedan
/// tal cual para barras, gráficas y fondos con ícono blanco encima, donde
/// el umbral es 3:1, no 4.5:1 (paquete-construccion-final.md §11).
abstract final class PaletaHex {
  // Dirección visual premium (2026-10-25): azul noche como color principal,
  // oro como acento solo en momentos clave, fondo marfil cálido.
  static const fondo = 0xFFFCFAF7; // Marfil
  static const tarjeta = 0xFFFFFFFF;
  static const tinta = 0xFF0B1F3B; // Azul Noche: texto y CTA principal

  /// Texto secundario: 5.53:1 sobre `fondo` (AA).
  static const medio = 0xFF5F6484;
  static const linea = 0xFFE6E8EE; // Gris Niebla

  static const azul = 0xFF0B1F3B; // Azul Noche: botones, selección
  static const azulMarino = 0xFF143A66; // superficies oscuras secundarias
  static const azulSuave = 0xFFE9EEF6; // fondo de chips/selección

  /// Oro Centenario: solo gráfico (2.1:1 sobre blanco). Texto azul noche
  /// encima pasa (7.84:1); para texto dorado usar `oroTexto`.
  static const oro = 0xFFD4AF37;
  static const oroSuave = 0xFFF8F0D8;
  static const oroTexto = 0xFF7A5C0A;

  static const verde = 0xFF16A34A;
  static const verdeSuave = 0xFFDCFCE7;
  static const verdeTexto = 0xFF15803D;

  static const ambar = 0xFFF59E0B;
  static const ambarSuave = 0xFFFEF3C7;
  static const ambarTexto = 0xFF92400E;

  static const coral = 0xFFEF4444;
  static const coralSuave = 0xFFFEE2E2;
  static const coralTexto = 0xFFB91C1C;

  /// Texto e íconos encima de `azul` (botones, selección).
  static const sobreAzul = 0xFFFFFFFF;

  /// Fondo de las barras de avance (lo que falta por recorrer).
  static const pista = 0xFFEDEFF6;

  /// Azul noche de marca, igual en los dos modos: degradados del login,
  /// la bienvenida y las tarjetas héroe, siempre con texto blanco encima.
  static const noche = 0xFF0B1F3B;
}

/// Modo oscuro (2026-10-26): mismos nombres que [PaletaHex], con los
/// pares de texto en AA (4.5:1) sobre `fondo`, `tarjeta` y los `Suave`
/// (lo vigila `test/ui_contraste_test.dart`). `azul` pasa a azul hielo
/// porque se usa como texto y como fondo de selección: ningún azul oscuro
/// se lee sobre fondo oscuro, así que el texto encima (`sobreAzul`) pasa
/// a azul noche.
abstract final class PaletaHexOscura {
  static const fondo = 0xFF0A1424;
  static const tarjeta = 0xFF13213A;
  static const tinta = 0xFFEEF1F7;
  static const medio = 0xFFA9B2C9;
  static const linea = 0xFF26354F;

  static const azul = 0xFF8DB4F2;
  static const azulSuave = 0xFF1B2D4A;

  static const oro = 0xFFD4AF37;
  static const oroSuave = 0xFF2C2615;
  static const oroTexto = 0xFFE6C65C;

  static const verde = 0xFF22C55E;
  static const verdeSuave = 0xFF0F2A1C;
  static const verdeTexto = 0xFF4ADE80;

  static const ambar = 0xFFF59E0B;
  static const ambarSuave = 0xFF2F2410;
  static const ambarTexto = 0xFFFBBF24;

  static const coral = 0xFFEF4444;
  static const coralSuave = 0xFF351819;
  static const coralTexto = 0xFFF87171;

  static const sobreAzul = 0xFF0B1F3B;
  static const pista = 0xFF22314B;
}

/// Fórmula de contraste WCAG 2.x (luminancia relativa + razón), aritmética
/// pura sobre un entero `0xRRGGBB` (el byte alto se ignora, así que un
/// `0xAARRGGBB` también sirve). Sin `dart:ui`, para que sea importable
/// desde `dart test`.
double razonDeContraste(int colorA, int colorB) {
  final la = _luminanciaRelativa(colorA) + 0.05;
  final lb = _luminanciaRelativa(colorB) + 0.05;
  return la > lb ? la / lb : lb / la;
}

double _luminanciaRelativa(int color) {
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  return 0.2126 * _canalLinealizado(r) +
      0.7152 * _canalLinealizado(g) +
      0.0722 * _canalLinealizado(b);
}

double _canalLinealizado(int canal8bit) {
  final c = canal8bit / 255.0;
  if (c <= 0.03928) return c / 12.92;
  return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}
