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

  static const azul = Color(PaletaHex.azul);
  static const azulMarino = Color(PaletaHex.azulMarino);
  static const azulSuave = Color(PaletaHex.azulSuave);
  static const oro = Color(PaletaHex.oro);
  static const oroSuave = Color(PaletaHex.oroSuave);
  static const oroTexto = Color(PaletaHex.oroTexto);
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
    seedColor: ColoresApp.azul,
    brightness: Brightness.light,
  ).copyWith(
    primary: ColoresApp.azul,
    onPrimary: Colors.white,
    secondary: ColoresApp.oro,
    onSecondary: ColoresApp.azul,
    surface: ColoresApp.tarjeta,
    onSurface: ColoresApp.tinta,
    surfaceTint: Colors.transparent,
    outline: ColoresApp.linea,
    outlineVariant: ColoresApp.linea,
    secondaryContainer: ColoresApp.azulSuave,
    onSecondaryContainer: ColoresApp.azul,
    // La variante de texto, no la brillante: ColorScheme.error se pinta
    // como texto/ícono (mensajes de error de TextField, etc.), donde el
    // umbral WCAG es 4.5:1, no el 3:1 de un elemento gráfico.
    error: ColoresApp.coralTexto,
  );

  final esquinas14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    textTheme: _textTheme,
    scaffoldBackgroundColor: ColoresApp.fondo,
    colorScheme: colorScheme,
    dividerTheme: const DividerThemeData(color: ColoresApp.linea, thickness: 1),
    // Tarjetas limpias: blanco sobre marfil con un filo gris niebla, sin
    // sombra pesada — el "premium" sale del aire y la jerarquía, no del
    // relieve.
    cardTheme: CardThemeData(
      color: ColoresApp.tarjeta,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ColoresApp.linea),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresApp.fondo,
      foregroundColor: ColoresApp.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ColoresApp.tinta,
      ),
    ),
    // CTA principal en azul noche; el oro se reserva para el botón de
    // registrar (FAB) y acentos.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColoresApp.azul,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ColoresApp.linea,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        minimumSize: const Size(0, 52),
        shape: esquinas14,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.azul,
        side: const BorderSide(color: ColoresApp.azul),
        shape: esquinas14,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ColoresApp.oro,
      foregroundColor: ColoresApp.azul,
      elevation: 2,
      shape: CircleBorder(),
    ),
    // Selección clara: lo activo en azul noche con texto blanco.
    chipTheme: ChipThemeData(
      backgroundColor: ColoresApp.tarjeta,
      selectedColor: ColoresApp.azul,
      checkmarkColor: Colors.white,
      secondarySelectedColor: ColoresApp.azul,
      labelStyle: const TextStyle(color: ColoresApp.tinta),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      side: const BorderSide(color: ColoresApp.linea),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? ColoresApp.azul : ColoresApp.tarjeta,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? Colors.white : ColoresApp.tinta,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? Colors.white : ColoresApp.tinta,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: ColoresApp.linea)),
        shape: WidgetStatePropertyAll(esquinas14),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? ColoresApp.verde : ColoresApp.linea,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: ColoresApp.azul,
      inactiveTrackColor: ColoresApp.linea,
      thumbColor: ColoresApp.azul,
      overlayColor: Color(0x1F0B1F3B),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: ColoresApp.azul),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ColoresApp.azul,
      behavior: SnackBarBehavior.floating,
      shape: esquinas14,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ColoresApp.tarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresApp.tarjeta,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(iconColor: ColoresApp.tinta),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.tarjeta,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ColoresApp.linea),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ColoresApp.linea),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ColoresApp.azul, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
