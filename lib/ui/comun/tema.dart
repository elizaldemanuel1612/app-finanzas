import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paleta.dart';

/// Una paleta completa, clara u oscura. Los hex viven en `paleta.dart`
/// (sin import de Flutter, para que `test/ui_contraste_test.dart` los
/// pruebe con `dart test`); esto solo los envuelve en `Color`.
///
/// `verdeTexto`/`ambarTexto`/`coralTexto` son las variantes que sí pasan
/// WCAG AA (4.5:1) para texto; `verde`/`ambar`/`coral` se quedan
/// brillantes para barras, gráficas y fondos con ícono encima (umbral
/// 3:1). Nunca usar el brillante como color de texto (Fase 6, Bloque 4.1).
final class Paleta {
  final bool esOscura;
  final Color fondo, tarjeta, tinta, medio, linea;
  final Color azul, azulSuave, sobreAzul, pista;
  final Color oro, oroSuave, oroTexto;
  final Color verde, verdeSuave, verdeTexto;
  final Color ambar, ambarSuave, ambarTexto;
  final Color coral, coralSuave, coralTexto;

  const Paleta._({
    required this.esOscura,
    required this.fondo,
    required this.tarjeta,
    required this.tinta,
    required this.medio,
    required this.linea,
    required this.azul,
    required this.azulSuave,
    required this.sobreAzul,
    required this.pista,
    required this.oro,
    required this.oroSuave,
    required this.oroTexto,
    required this.verde,
    required this.verdeSuave,
    required this.verdeTexto,
    required this.ambar,
    required this.ambarSuave,
    required this.ambarTexto,
    required this.coral,
    required this.coralSuave,
    required this.coralTexto,
  });

  static const clara = Paleta._(
    esOscura: false,
    fondo: Color(PaletaHex.fondo),
    tarjeta: Color(PaletaHex.tarjeta),
    tinta: Color(PaletaHex.tinta),
    medio: Color(PaletaHex.medio),
    linea: Color(PaletaHex.linea),
    azul: Color(PaletaHex.azul),
    azulSuave: Color(PaletaHex.azulSuave),
    sobreAzul: Color(PaletaHex.sobreAzul),
    pista: Color(PaletaHex.pista),
    oro: Color(PaletaHex.oro),
    oroSuave: Color(PaletaHex.oroSuave),
    oroTexto: Color(PaletaHex.oroTexto),
    verde: Color(PaletaHex.verde),
    verdeSuave: Color(PaletaHex.verdeSuave),
    verdeTexto: Color(PaletaHex.verdeTexto),
    ambar: Color(PaletaHex.ambar),
    ambarSuave: Color(PaletaHex.ambarSuave),
    ambarTexto: Color(PaletaHex.ambarTexto),
    coral: Color(PaletaHex.coral),
    coralSuave: Color(PaletaHex.coralSuave),
    coralTexto: Color(PaletaHex.coralTexto),
  );

  static const oscura = Paleta._(
    esOscura: true,
    fondo: Color(PaletaHexOscura.fondo),
    tarjeta: Color(PaletaHexOscura.tarjeta),
    tinta: Color(PaletaHexOscura.tinta),
    medio: Color(PaletaHexOscura.medio),
    linea: Color(PaletaHexOscura.linea),
    azul: Color(PaletaHexOscura.azul),
    azulSuave: Color(PaletaHexOscura.azulSuave),
    sobreAzul: Color(PaletaHexOscura.sobreAzul),
    pista: Color(PaletaHexOscura.pista),
    oro: Color(PaletaHexOscura.oro),
    oroSuave: Color(PaletaHexOscura.oroSuave),
    oroTexto: Color(PaletaHexOscura.oroTexto),
    verde: Color(PaletaHexOscura.verde),
    verdeSuave: Color(PaletaHexOscura.verdeSuave),
    verdeTexto: Color(PaletaHexOscura.verdeTexto),
    ambar: Color(PaletaHexOscura.ambar),
    ambarSuave: Color(PaletaHexOscura.ambarSuave),
    ambarTexto: Color(PaletaHexOscura.ambarTexto),
    coral: Color(PaletaHexOscura.coral),
    coralSuave: Color(PaletaHexOscura.coralSuave),
    coralTexto: Color(PaletaHexOscura.coralTexto),
  );
}

/// Los colores de la apariencia activa (claro u oscuro, 2026-10-26).
///
/// Son getters sobre una paleta global en vez de un `ThemeExtension` a
/// propósito: así las ~360 referencias `ColoresApp.x` de `lib/ui/` siguen
/// iguales. A cambio no son `const`, y quien cambia la apariencia
/// (`AparienciaApp` en `apariencia.dart`) reconstruye todo el árbol para
/// que nadie se quede con el color anterior.
///
/// [noche] y [azulMarino] son de marca y no cambian con el modo: degradados
/// del login, la bienvenida y las tarjetas héroe, con texto blanco encima.
abstract final class ColoresApp {
  static Paleta _actual = Paleta.clara;

  static Paleta get actual => _actual;
  static bool get oscuro => _actual.esOscura;

  /// Devuelve `true` si cambió.
  static bool usar(Paleta paleta) {
    if (identical(paleta, _actual)) return false;
    _actual = paleta;
    return true;
  }

  static const noche = Color(PaletaHex.noche);
  static const azulMarino = Color(PaletaHex.azulMarino);

  static Color get fondo => _actual.fondo;
  static Color get tarjeta => _actual.tarjeta;
  static Color get tinta => _actual.tinta;
  static Color get medio => _actual.medio;
  static Color get linea => _actual.linea;
  static Color get azul => _actual.azul;
  static Color get azulSuave => _actual.azulSuave;
  static Color get sobreAzul => _actual.sobreAzul;
  static Color get pista => _actual.pista;
  static Color get oro => _actual.oro;
  static Color get oroSuave => _actual.oroSuave;
  static Color get oroTexto => _actual.oroTexto;
  static Color get verde => _actual.verde;
  static Color get verdeSuave => _actual.verdeSuave;
  static Color get verdeTexto => _actual.verdeTexto;
  static Color get ambar => _actual.ambar;
  static Color get ambarSuave => _actual.ambarSuave;
  static Color get ambarTexto => _actual.ambarTexto;
  static Color get coral => _actual.coral;
  static Color get coralSuave => _actual.coralSuave;
  static Color get coralTexto => _actual.coralTexto;
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
/// Familia por defecto. `ThemeData.fontFamily` solo llega al `textTheme`:
/// los estilos de componentes que **reemplazan** el estilo en vez de
/// combinarlo (texto de `ElevatedButton`, `SnackBar`, `ListTile`) la
/// necesitan explícita, o en iPhone caen a la fuente del sistema.
const _familia = 'PlusJakartaSans';

TextTheme _textTheme(Paleta p) => TextTheme(
  displaySmall: TextStyle(
    fontFamily: 'Outfit',
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: p.tinta,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'Outfit',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: p.tinta,
  ),
  titleMedium: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: p.tinta,
  ),
  bodyMedium: TextStyle(color: p.tinta),
  bodySmall: TextStyle(fontSize: 13, color: p.medio),
  labelSmall: TextStyle(fontSize: 12, color: p.medio),
);

ThemeData construirTema([Paleta p = Paleta.clara]) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: p.azul,
    brightness: p.esOscura ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: p.azul,
    onPrimary: p.sobreAzul,
    secondary: p.oro,
    onSecondary: p.azul,
    surface: p.tarjeta,
    onSurface: p.tinta,
    surfaceTint: Colors.transparent,
    outline: p.linea,
    outlineVariant: p.linea,
    secondaryContainer: p.azulSuave,
    onSecondaryContainer: p.azul,
    // La variante de texto, no la brillante: ColorScheme.error se pinta
    // como texto/ícono (mensajes de error de TextField, etc.), donde el
    // umbral WCAG es 4.5:1, no el 3:1 de un elemento gráfico.
    error: p.coralTexto,
  );

  final esquinas14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    fontFamily: _familia,
    textTheme: _textTheme(p),
    scaffoldBackgroundColor: p.fondo,
    colorScheme: colorScheme,
    dividerTheme: DividerThemeData(color: p.linea, thickness: 1),
    // Tarjetas limpias: blanco sobre marfil con un filo gris niebla, sin
    // sombra pesada — el "premium" sale del aire y la jerarquía, no del
    // relieve.
    cardTheme: CardThemeData(
      color: p.tarjeta,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.linea),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      foregroundColor: p.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: p.esOscura ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.tinta,
      ),
    ),
    // CTA principal en azul noche; el oro se reserva para el botón de
    // registrar (FAB) y acentos.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.azul,
        foregroundColor: p.sobreAzul,
        disabledBackgroundColor: p.linea,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        minimumSize: const Size(0, 52),
        shape: esquinas14,
        textStyle: const TextStyle(fontFamily: _familia, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.azul,
        side: BorderSide(color: p.azul),
        shape: esquinas14,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.azul),
    ),
    // El "+" va en azul noche fijo: el azul del tema en oscuro es claro y
    // no se lee sobre el oro.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.oro,
      foregroundColor: ColoresApp.noche,
      elevation: 2,
      shape: CircleBorder(),
    ),
    // Selección clara: lo activo en azul noche con texto blanco.
    chipTheme: ChipThemeData(
      backgroundColor: p.tarjeta,
      selectedColor: p.azul,
      checkmarkColor: p.sobreAzul,
      secondarySelectedColor: p.azul,
      // Seleccionado = fondo azul noche: el texto tiene que pasar a blanco o
      // se pierde (el estilo fijo en tinta dejaba los nombres invisibles).
      // (RawChip resuelve el color por estado, no el TextStyle completo).
      labelStyle: TextStyle(
        fontFamily: _familia,
        color: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.sobreAzul : p.tinta,
        ),
      ),
      secondaryLabelStyle: TextStyle(fontFamily: _familia, color: p.sobreAzul),
      side: BorderSide(color: p.linea),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.azul : p.tarjeta,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.sobreAzul : p.tinta,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.sobreAzul : p.tinta,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.linea)),
        shape: WidgetStatePropertyAll(esquinas14),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? p.verde : p.linea,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.azul,
      inactiveTrackColor: p.linea,
      thumbColor: p.azul,
      overlayColor: p.azul.withValues(alpha: 0.12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.azul),
    // En oscuro, un azul noche sobre fondo casi negro no se distingue:
    // la barra sube un tono para separarse del fondo.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.esOscura ? const Color(0xFF2A3C5C) : p.azul,
      contentTextStyle: const TextStyle(fontFamily: _familia, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: esquinas14,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.tarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.tarjeta,
      surfaceTintColor: Colors.transparent,
    ),
    // Sin estilo propio, ListTile usa bodyLarge/bodyMedium de Material
    // (16 y 14 con letra espaciada): sus renglones salían más grandes que
    // el resto. Mismo tamaño que los nombres de las tarjetas de categoría.
    listTileTheme: ListTileThemeData(
      iconColor: p.tinta,
      titleTextStyle: TextStyle(fontFamily: _familia, fontSize: 15, fontWeight: FontWeight.w700, color: p.tinta),
      subtitleTextStyle: TextStyle(fontFamily: _familia, fontSize: 13, color: p.medio),
      leadingAndTrailingTextStyle: TextStyle(fontFamily: _familia, fontSize: 14, color: p.tinta),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.tarjeta,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.linea),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.linea),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.azul, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
