import 'package:flutter/material.dart';

import 'paleta.dart';

/// Paleta tomada de los mockups (app-finanzas-ingresos-ajustes-v11.html
/// §CSS). Los valores hex viven en `paleta.dart` (sin import de Flutter,
/// para que `test/ui_contraste_test.dart` los pueda probar con
/// `dart test`) — este archivo solo los envuelve en `Color`.
///
/// `verdeTexto`/`ambarTexto`/`coralTexto` son las variantes que sí pasan
/// WCAG AA (4.5:1) para texto; `verde`/`ambar`/`coral` se quedan
/// brillantes para barras, gráficas y fondos con ícono blanco encima
/// (umbral 3:1). Nunca usar el brillante como color de texto — para eso
/// está la variante `Texto` (Fase 6, Bloque 4.1).
abstract final class ColoresApp {
  static const fondo = Color(PaletaHex.fondo);
  static const tarjeta = Color(PaletaHex.tarjeta);
  static const tinta = Color(PaletaHex.tinta);
  static const medio = Color(PaletaHex.medio);
  static const linea = Color(PaletaHex.linea);

  static const violeta = Color(PaletaHex.violeta);
  static const violetaSuave = Color(PaletaHex.violetaSuave);
  static const verde = Color(PaletaHex.verde);
  static const verdeSuave = Color(PaletaHex.verdeSuave);
  static const verdeTexto = Color(PaletaHex.verdeTexto);
  static const ambar = Color(PaletaHex.ambar);
  static const ambarSuave = Color(PaletaHex.ambarSuave);
  static const ambarTexto = Color(PaletaHex.ambarTexto);
  static const coral = Color(PaletaHex.coral);
  static const coralSuave = Color(PaletaHex.coralSuave);
  static const coralTexto = Color(PaletaHex.coralTexto);
}

/// Ranuras de Material a las que se mapean los tamaños que hoy están
/// dispersos como `fontSize:` sueltos por `lib/ui/` (Fase 6, Bloque 3):
///
/// | Uso                     | Ranura          | Tamaño/peso |
/// |--------------------------|-----------------|-------------|
/// | Cifra héroe              | `displaySmall`  | 34, w800    |
/// | Cifra tarjeta oscura     | `headlineMedium`| 28, w800    |
/// | Título de sección        | `titleMedium`   | 16, w800    |
/// | Etiqueta gris            | `bodySmall`     | 13, medio   |
/// | Micro (chips, etiquetas) | `labelSmall`    | 12, medio   |
///
/// Outfit solo en las dos ranuras de cifras — el resto usa Plus Jakarta
/// Sans, fijado como familia por defecto del tema. `test/estilos_ui_test.dart`
/// vigila que los `fontSize:` sueltos no vuelvan a crecer sin querer.
const _textTheme = TextTheme(
  displaySmall: TextStyle(
    fontFamily: 'Outfit',
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: ColoresApp.tinta,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'Outfit',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: ColoresApp.tinta,
  ),
  titleMedium: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: ColoresApp.tinta,
  ),
  bodyMedium: TextStyle(color: ColoresApp.tinta),
  bodySmall: TextStyle(fontSize: 13, color: ColoresApp.medio),
  labelSmall: TextStyle(fontSize: 12, color: ColoresApp.medio),
);

ThemeData construirTema() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: ColoresApp.violeta,
    brightness: Brightness.light,
  ).copyWith(
    primary: ColoresApp.violeta,
    surface: ColoresApp.tarjeta,
    // La variante de texto, no la brillante: ColorScheme.error se pinta
    // como texto/ícono (mensajes de error de TextField, etc.), donde el
    // umbral WCAG es 4.5:1, no el 3:1 de un elemento gráfico.
    error: ColoresApp.coralTexto,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    textTheme: _textTheme,
    scaffoldBackgroundColor: ColoresApp.fondo,
    colorScheme: colorScheme,
    cardTheme: CardThemeData(
      color: ColoresApp.tarjeta,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresApp.fondo,
      foregroundColor: ColoresApp.tinta,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColoresApp.violeta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.fondo,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
