import 'package:flutter/material.dart';

/// Paleta tomada de los mockups (app-finanzas-ingresos-ajustes-v11.html
/// §CSS): mismos tonos, para que la app y los mockups se sientan del
/// mismo sistema aunque la tipografía todavía sea la del sistema — las
/// fuentes empaquetadas (Outfit/Plus Jakarta Sans) quedan para un pase de
/// pulido visual posterior.
abstract final class ColoresApp {
  static const fondo = Color(0xFFF2F4FA);
  static const tarjeta = Color(0xFFFFFFFF);
  static const tinta = Color(0xFF1A1B3A);
  static const medio = Color(0xFF6B6F8D);
  static const linea = Color(0xFFE7E9F2);

  static const violeta = Color(0xFF5B4BE8);
  static const violetaSuave = Color(0xFFEAE7FD);
  static const verde = Color(0xFF12B76A);
  static const verdeSuave = Color(0xFFDCF6EA);
  static const ambar = Color(0xFFF5A524);
  static const ambarSuave = Color(0xFFFDF0D8);
  static const coral = Color(0xFFF4623A);
  static const coralSuave = Color(0xFFFDE5DC);
}

ThemeData construirTema() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: ColoresApp.violeta,
    brightness: Brightness.light,
  ).copyWith(
    primary: ColoresApp.violeta,
    surface: ColoresApp.tarjeta,
    error: ColoresApp.coral,
  );

  return ThemeData(
    useMaterial3: true,
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
