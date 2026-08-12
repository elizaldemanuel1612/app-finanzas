import 'dart:math' as math;

/// Hex crudos de la paleta (app-finanzas-ingresos-ajustes-v11.html §CSS),
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
  static const fondo = 0xFFF2F4FA;
  static const tarjeta = 0xFFFFFFFF;
  static const tinta = 0xFF1A1B3A;

  /// Oscurecido de `#6B6F8D` (4.46:1 sobre `fondo`, insuficiente para AA)
  /// a `#5F6484` (5.24:1) — Fase 6, Bloque 4.1.
  static const medio = 0xFF5F6484;
  static const linea = 0xFFE7E9F2;

  static const violeta = 0xFF5B4BE8;
  static const violetaSuave = 0xFFEAE7FD;

  static const verde = 0xFF12B76A;
  static const verdeSuave = 0xFFDCF6EA;
  static const verdeTexto = 0xFF0A7A46;

  static const ambar = 0xFFF5A524;
  static const ambarSuave = 0xFFFDF0D8;
  static const ambarTexto = 0xFF8A5A00;

  static const coral = 0xFFF4623A;
  static const coralSuave = 0xFFFDE5DC;
  static const coralTexto = 0xFFB03A18;
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
