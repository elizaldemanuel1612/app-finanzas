import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paleta.dart';

/// Una paleta completa, clara u oscura. Los hex viven en `paleta.dart`
/// (sin import de Flutter, para que `test/ui_contraste_test.dart` los
/// pruebe con `dart test`); esto solo los envuelve en `Color`.
///
/// Rediseño (2026-11-15): los campos son los tokens semánticos de
/// `docs/rediseno/design-system/tokens.json` (`texto`, `texto2`, `superficie`,
/// `exito`/`exitoTexto`/`exitoFondo`…). Los nombres de antes (`tinta`,
/// `medio`, `azul`, `verde`…) son alias que apuntan al token equivalente.
/// Nunca usar la versión de gráfica (`exito`, `atencion`, `peligro`) como
/// color de texto: para eso están las `…Texto`.
final class Paleta {
  final bool esOscura;
  final Color fondo;
  final Color superficie;
  final Color superficieHundida;
  final Color borde;
  final Color bordeControl;
  final Color texto;
  final Color texto2;
  final Color textoDesactivado;
  final Color accion;
  final Color sobreAccion;
  final Color accionPresionada;
  final Color foco;
  final Color oro;
  final Color sobreOro;
  final Color oroTexto;
  final Color heroeFondo;
  final Color heroeTexto;
  final Color heroeTexto2;
  final Color heroePista;
  final Color exito;
  final Color exitoTexto;
  final Color exitoFondo;
  final Color atencion;
  final Color atencionTexto;
  final Color atencionFondo;
  final Color peligro;
  final Color peligroTexto;
  final Color peligroFondo;
  final Color infoTexto;
  final Color infoFondo;
  final Color heroeExito;
  final Color heroeAtencion;
  final Color heroePeligro;
  final Color graf1;
  final Color graf2;
  final Color graf3;
  final Color graf4;
  final Color graf5;
  final Color grafPista;
  final Color grafGuia;
  final Color marcaRitmo;
  final Color velo;
  final Color oroSuave;
  final Color aFavor;
  final Color enContra;

  const Paleta._({
    required this.esOscura,
    required this.fondo,
    required this.superficie,
    required this.superficieHundida,
    required this.borde,
    required this.bordeControl,
    required this.texto,
    required this.texto2,
    required this.textoDesactivado,
    required this.accion,
    required this.sobreAccion,
    required this.accionPresionada,
    required this.foco,
    required this.oro,
    required this.sobreOro,
    required this.oroTexto,
    required this.heroeFondo,
    required this.heroeTexto,
    required this.heroeTexto2,
    required this.heroePista,
    required this.exito,
    required this.exitoTexto,
    required this.exitoFondo,
    required this.atencion,
    required this.atencionTexto,
    required this.atencionFondo,
    required this.peligro,
    required this.peligroTexto,
    required this.peligroFondo,
    required this.infoTexto,
    required this.infoFondo,
    required this.heroeExito,
    required this.heroeAtencion,
    required this.heroePeligro,
    required this.graf1,
    required this.graf2,
    required this.graf3,
    required this.graf4,
    required this.graf5,
    required this.grafPista,
    required this.grafGuia,
    required this.marcaRitmo,
    required this.velo,
    required this.oroSuave,
    required this.aFavor,
    required this.enContra,
  });

  // Alias de los nombres de antes del rediseño.
  Color get tarjeta => superficie;
  Color get tinta => texto;
  Color get medio => texto2;
  Color get linea => borde;
  Color get azul => accion;
  Color get azulSuave => infoFondo;
  Color get sobreAzul => sobreAccion;
  Color get pista => grafPista;
  Color get verde => exito;
  Color get verdeSuave => exitoFondo;
  Color get verdeTexto => exitoTexto;
  Color get ambar => atencion;
  Color get ambarSuave => atencionFondo;
  Color get ambarTexto => atencionTexto;
  Color get coral => peligro;
  Color get coralSuave => peligroFondo;
  Color get coralTexto => peligroTexto;

  static const clara = Paleta._(
    esOscura: false,
    fondo: Color(PaletaHex.fondo),
    superficie: Color(PaletaHex.superficie),
    superficieHundida: Color(PaletaHex.superficieHundida),
    borde: Color(PaletaHex.borde),
    bordeControl: Color(PaletaHex.bordeControl),
    texto: Color(PaletaHex.texto),
    texto2: Color(PaletaHex.texto2),
    textoDesactivado: Color(PaletaHex.textoDesactivado),
    accion: Color(PaletaHex.accion),
    sobreAccion: Color(PaletaHex.sobreAccion),
    accionPresionada: Color(PaletaHex.accionPresionada),
    foco: Color(PaletaHex.foco),
    oro: Color(PaletaHex.oro),
    sobreOro: Color(PaletaHex.sobreOro),
    oroTexto: Color(PaletaHex.oroTexto),
    heroeFondo: Color(PaletaHex.heroeFondo),
    heroeTexto: Color(PaletaHex.heroeTexto),
    heroeTexto2: Color(PaletaHex.heroeTexto2),
    heroePista: Color(PaletaHex.heroePista),
    exito: Color(PaletaHex.exito),
    exitoTexto: Color(PaletaHex.exitoTexto),
    exitoFondo: Color(PaletaHex.exitoFondo),
    atencion: Color(PaletaHex.atencion),
    atencionTexto: Color(PaletaHex.atencionTexto),
    atencionFondo: Color(PaletaHex.atencionFondo),
    peligro: Color(PaletaHex.peligro),
    peligroTexto: Color(PaletaHex.peligroTexto),
    peligroFondo: Color(PaletaHex.peligroFondo),
    infoTexto: Color(PaletaHex.infoTexto),
    infoFondo: Color(PaletaHex.infoFondo),
    heroeExito: Color(PaletaHex.heroeExito),
    heroeAtencion: Color(PaletaHex.heroeAtencion),
    heroePeligro: Color(PaletaHex.heroePeligro),
    graf1: Color(PaletaHex.graf1),
    graf2: Color(PaletaHex.graf2),
    graf3: Color(PaletaHex.graf3),
    graf4: Color(PaletaHex.graf4),
    graf5: Color(PaletaHex.graf5),
    grafPista: Color(PaletaHex.grafPista),
    grafGuia: Color(PaletaHex.grafGuia),
    marcaRitmo: Color(PaletaHex.marcaRitmo),
    velo: Color(PaletaHex.velo),
    oroSuave: Color(PaletaHex.oroSuave),
    aFavor: Color(PaletaHex.aFavor),
    enContra: Color(PaletaHex.enContra),
  );

  static const oscura = Paleta._(
    esOscura: true,
    fondo: Color(PaletaHexOscura.fondo),
    superficie: Color(PaletaHexOscura.superficie),
    superficieHundida: Color(PaletaHexOscura.superficieHundida),
    borde: Color(PaletaHexOscura.borde),
    bordeControl: Color(PaletaHexOscura.bordeControl),
    texto: Color(PaletaHexOscura.texto),
    texto2: Color(PaletaHexOscura.texto2),
    textoDesactivado: Color(PaletaHexOscura.textoDesactivado),
    accion: Color(PaletaHexOscura.accion),
    sobreAccion: Color(PaletaHexOscura.sobreAccion),
    accionPresionada: Color(PaletaHexOscura.accionPresionada),
    foco: Color(PaletaHexOscura.foco),
    oro: Color(PaletaHexOscura.oro),
    sobreOro: Color(PaletaHexOscura.sobreOro),
    oroTexto: Color(PaletaHexOscura.oroTexto),
    heroeFondo: Color(PaletaHexOscura.heroeFondo),
    heroeTexto: Color(PaletaHexOscura.heroeTexto),
    heroeTexto2: Color(PaletaHexOscura.heroeTexto2),
    heroePista: Color(PaletaHexOscura.heroePista),
    exito: Color(PaletaHexOscura.exito),
    exitoTexto: Color(PaletaHexOscura.exitoTexto),
    exitoFondo: Color(PaletaHexOscura.exitoFondo),
    atencion: Color(PaletaHexOscura.atencion),
    atencionTexto: Color(PaletaHexOscura.atencionTexto),
    atencionFondo: Color(PaletaHexOscura.atencionFondo),
    peligro: Color(PaletaHexOscura.peligro),
    peligroTexto: Color(PaletaHexOscura.peligroTexto),
    peligroFondo: Color(PaletaHexOscura.peligroFondo),
    infoTexto: Color(PaletaHexOscura.infoTexto),
    infoFondo: Color(PaletaHexOscura.infoFondo),
    heroeExito: Color(PaletaHexOscura.heroeExito),
    heroeAtencion: Color(PaletaHexOscura.heroeAtencion),
    heroePeligro: Color(PaletaHexOscura.heroePeligro),
    graf1: Color(PaletaHexOscura.graf1),
    graf2: Color(PaletaHexOscura.graf2),
    graf3: Color(PaletaHexOscura.graf3),
    graf4: Color(PaletaHexOscura.graf4),
    graf5: Color(PaletaHexOscura.graf5),
    grafPista: Color(PaletaHexOscura.grafPista),
    grafGuia: Color(PaletaHexOscura.grafGuia),
    marcaRitmo: Color(PaletaHexOscura.marcaRitmo),
    velo: Color(PaletaHexOscura.velo),
    oroSuave: Color(PaletaHexOscura.oroSuave),
    aFavor: Color(PaletaHexOscura.aFavor),
    enContra: Color(PaletaHexOscura.enContra),
  );
}

/// Los colores de la apariencia activa (claro u oscuro, 2026-10-26).
///
/// Son getters sobre una paleta global en vez de un `ThemeExtension` a
/// propósito: así las referencias `ColoresApp.x` de `lib/ui/` no necesitan
/// `context`. A cambio no son `const`, y quien cambia la apariencia
/// (`AparienciaApp` en `apariencia.dart`) reconstruye todo el árbol para
/// que nadie se quede con el color anterior.
///
/// [noche] y [azulMarino] son de marca y no cambian con el modo: login,
/// bienvenida y emblema, con texto claro encima.
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

  // Tokens (docs/rediseno/design-system/tokens.json).
  static Color get fondo => _actual.fondo;
  static Color get superficie => _actual.superficie;
  static Color get superficieHundida => _actual.superficieHundida;
  static Color get borde => _actual.borde;
  static Color get bordeControl => _actual.bordeControl;
  static Color get texto => _actual.texto;
  static Color get texto2 => _actual.texto2;
  static Color get textoDesactivado => _actual.textoDesactivado;
  static Color get accion => _actual.accion;
  static Color get sobreAccion => _actual.sobreAccion;
  static Color get accionPresionada => _actual.accionPresionada;
  static Color get foco => _actual.foco;
  static Color get oro => _actual.oro;
  static Color get sobreOro => _actual.sobreOro;
  static Color get oroTexto => _actual.oroTexto;
  static Color get heroeFondo => _actual.heroeFondo;
  static Color get heroeTexto => _actual.heroeTexto;
  static Color get heroeTexto2 => _actual.heroeTexto2;
  static Color get heroePista => _actual.heroePista;
  static Color get exito => _actual.exito;
  static Color get exitoTexto => _actual.exitoTexto;
  static Color get exitoFondo => _actual.exitoFondo;
  static Color get atencion => _actual.atencion;
  static Color get atencionTexto => _actual.atencionTexto;
  static Color get atencionFondo => _actual.atencionFondo;
  static Color get peligro => _actual.peligro;
  static Color get peligroTexto => _actual.peligroTexto;
  static Color get peligroFondo => _actual.peligroFondo;
  static Color get infoTexto => _actual.infoTexto;
  static Color get infoFondo => _actual.infoFondo;
  static Color get heroeExito => _actual.heroeExito;
  static Color get heroeAtencion => _actual.heroeAtencion;
  static Color get heroePeligro => _actual.heroePeligro;
  static Color get graf1 => _actual.graf1;
  static Color get graf2 => _actual.graf2;
  static Color get graf3 => _actual.graf3;
  static Color get graf4 => _actual.graf4;
  static Color get graf5 => _actual.graf5;
  static Color get grafPista => _actual.grafPista;
  static Color get grafGuia => _actual.grafGuia;
  static Color get marcaRitmo => _actual.marcaRitmo;
  static Color get velo => _actual.velo;
  static Color get oroSuave => _actual.oroSuave;
  static Color get aFavor => _actual.aFavor;
  static Color get enContra => _actual.enContra;

  // Alias de los nombres de antes del rediseño.
  static Color get tarjeta => _actual.superficie;
  static Color get tinta => _actual.texto;
  static Color get medio => _actual.texto2;
  static Color get linea => _actual.borde;
  static Color get azul => _actual.accion;
  static Color get azulSuave => _actual.infoFondo;
  static Color get sobreAzul => _actual.sobreAccion;
  static Color get pista => _actual.grafPista;
  static Color get verde => _actual.exito;
  static Color get verdeSuave => _actual.exitoFondo;
  static Color get verdeTexto => _actual.exitoTexto;
  static Color get ambar => _actual.atencion;
  static Color get ambarSuave => _actual.atencionFondo;
  static Color get ambarTexto => _actual.atencionTexto;
  static Color get coral => _actual.peligro;
  static Color get coralSuave => _actual.peligroFondo;
  static Color get coralTexto => _actual.peligroTexto;
}

/// Tipografía del rediseño (`docs/rediseno/plan-rediseno.md`, Etapa 1;
/// `design-system/tokens.json` → `type`): seis estilos, ninguno menor a
/// 13 px, cifras tabulares siempre. Se guardan en ranuras de Material para
/// que los componentes estándar los tomen solos; en código se piden por su
/// nombre con [EstilosApp] (`textos.cifraHeroe`, `textos.etiqueta`…).
///
/// | Estilo          | Ranura           | Familia           | Tamaño/alto, peso |
/// |-----------------|------------------|-------------------|-------------------|
/// | `cifra-heroe`   | `displaySmall`   | Outfit            | 44/48, 600        |
/// | `titulo`        | `headlineMedium` | Outfit            | 24/30, 600        |
/// | `seccion`       | `titleMedium`    | Outfit            | 17/24, 600        |
/// | `cuerpo-fuerte` | `titleSmall`     | Plus Jakarta Sans | 15/22, 600        |
/// | `cuerpo`        | `bodyMedium`     | Plus Jakarta Sans | 15/22, 400        |
/// | `etiqueta`      | `bodySmall`      | Plus Jakarta Sans | 13/18, 500        |
///
/// `bodyLarge` (campos de texto) y `labelSmall` repiten `cuerpo` y
/// `etiqueta`: así nada del Material de fábrica sale con otro tamaño.
/// `test/estilos_ui_test.dart` vigila que no aparezcan `fontSize:` sueltos.
///
/// `ThemeData.fontFamily` solo llega al `textTheme`: los estilos de
/// componentes que **reemplazan** el estilo en vez de combinarlo (texto de
/// `ElevatedButton`, `SnackBar`, `ListTile`) llevan la familia explícita,
/// o en iPhone caen a la fuente del sistema.
const _familia = 'PlusJakartaSans';
const _display = 'Outfit';
const _tabulares = [FontFeature.tabularFigures()];

TextTheme _textTheme(Paleta p) {
  final cuerpo = TextStyle(
    fontFamily: _familia,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    color: p.texto,
    fontFeatures: _tabulares,
  );
  final etiqueta = TextStyle(
    fontFamily: _familia,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.13,
    color: p.texto2,
    fontFeatures: _tabulares,
  );
  return TextTheme(
    displaySmall: TextStyle(
      fontFamily: _display,
      fontSize: 44,
      height: 48 / 44,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.88,
      color: p.texto,
      fontFeatures: _tabulares,
    ),
    headlineMedium: TextStyle(
      fontFamily: _display,
      fontSize: 24,
      height: 30 / 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.24,
      color: p.texto,
      fontFeatures: _tabulares,
    ),
    titleMedium: TextStyle(
      fontFamily: _display,
      fontSize: 17,
      height: 24 / 17,
      fontWeight: FontWeight.w600,
      color: p.texto,
      fontFeatures: _tabulares,
    ),
    titleSmall: cuerpo.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: cuerpo,
    bodyMedium: cuerpo,
    bodySmall: etiqueta,
    labelLarge: cuerpo.copyWith(fontWeight: FontWeight.w600),
    labelMedium: etiqueta,
    labelSmall: etiqueta,
  );
}

/// Los seis estilos del sistema de diseño por su nombre.
extension EstilosApp on TextTheme {
  /// Una por pantalla: la cifra que responde la pregunta.
  TextStyle get cifraHeroe => displaySmall!;

  /// Título de pantalla raíz.
  TextStyle get titulo => headlineMedium!;

  /// Encabezado de sección, cifra de tarjeta.
  TextStyle get seccion => titleMedium!;

  /// Título de renglón y montos en listas.
  TextStyle get cuerpoFuerte => titleSmall!;

  /// Frases interpretativas.
  TextStyle get cuerpo => bodyMedium!;

  /// Subtítulos, chips, ejes, leyendas (en `texto2`).
  TextStyle get etiqueta => bodySmall!;
}

/// Espaciado (escala de 4 pt), radios y duraciones de `tokens.json`.
abstract final class Esp {
  static const e4 = 4.0;
  static const e8 = 8.0;
  static const e12 = 12.0;
  static const e16 = 16.0;
  static const e20 = 20.0;
  static const e24 = 24.0;
  static const e32 = 32.0;
  static const e48 = 48.0;
}

abstract final class Radios {
  static const s = 8.0;
  static const m = 14.0;
  static const l = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract final class Duracion {
  static const rapida = Duration(milliseconds: 120);
  static const media = Duration(milliseconds: 220);
  static const lenta = Duration(milliseconds: 320);

  /// `cubic-bezier(0.2, 0, 0, 1)`.
  static const curva = Cubic(0.2, 0, 0, 1);
}

/// `sombra-1`: tarjetas en claro; en oscuro, solo borde.
List<BoxShadow> sombra1(Paleta p) => p.esOscura
    ? const []
    : const [
        BoxShadow(color: Color(0x0A0B1F3B), offset: Offset(0, 1), blurRadius: 2),
        BoxShadow(color: Color(0x0A0B1F3B), offset: Offset(0, 6), blurRadius: 16),
      ];

/// `sombra-fab`: solo el botón ＋.
List<BoxShadow> sombraFab(Paleta p) => [
      BoxShadow(
        color: p.esOscura ? const Color(0x80000000) : const Color(0x4D7A5C0A),
        offset: const Offset(0, 6),
        blurRadius: 18,
      ),
    ];

ThemeData construirTema([Paleta p = Paleta.clara]) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: p.accion,
    brightness: p.esOscura ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: p.accion,
    onPrimary: p.sobreAccion,
    secondary: p.oro,
    onSecondary: p.sobreOro,
    surface: p.superficie,
    onSurface: p.texto,
    onSurfaceVariant: p.texto2,
    surfaceContainerHighest: p.superficieHundida,
    surfaceContainerHigh: p.superficieHundida,
    surfaceContainer: p.superficie,
    surfaceContainerLow: p.superficie,
    surfaceTint: Colors.transparent,
    outline: p.bordeControl,
    outlineVariant: p.borde,
    secondaryContainer: p.infoFondo,
    onSecondaryContainer: p.infoTexto,
    // La variante de texto, no la de gráfica: ColorScheme.error se pinta
    // como texto/ícono (mensajes de error de TextField), umbral 4.5:1.
    error: p.peligroTexto,
    scrim: p.velo,
  );
  final textos = _textTheme(p);
  final esquinasM = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.m));
  final botonTexto = textos.cuerpoFuerte.copyWith(color: null);

  return ThemeData(
    useMaterial3: true,
    fontFamily: _familia,
    textTheme: textos,
    scaffoldBackgroundColor: p.fondo,
    colorScheme: colorScheme,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: p.borde, thickness: 1, space: 1),
    // Tarjeta informativa (componentes/Tarjeta.md): superficie, borde y
    // radio-l; la sombra la pone `TarjetaApp` (Card no la dibuja suave).
    cardTheme: CardThemeData(
      color: p.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.l),
        side: BorderSide(color: p.borde),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      foregroundColor: p.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: p.esOscura ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: textos.seccion,
    ),
    // Botón primario (componentes/Boton.md): uno por pantalla, alto 52,
    // radio-m; deshabilitado en superficie hundida.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((e) {
          if (e.contains(WidgetState.disabled)) return p.superficieHundida;
          if (e.contains(WidgetState.pressed)) return p.accionPresionada;
          return p.accion;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.disabled) ? p.textoDesactivado : p.sobreAccion,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
        shape: WidgetStatePropertyAll(esquinasM),
        textStyle: WidgetStatePropertyAll(botonTexto),
      ),
    ),
    // Secundario: borde borde-control de 1.5 px.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.texto,
        disabledForegroundColor: p.textoDesactivado,
        side: BorderSide(color: p.bordeControl, width: 1.5),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: esquinasM,
        textStyle: botonTexto,
      ),
    ),
    // Texto: acciones terciarias, alto táctil 44.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.texto,
        minimumSize: const Size(44, 44),
        textStyle: botonTexto,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.texto, minimumSize: const Size(44, 44)),
    ),
    // FAB ＋: el único uso de oro en controles; ícono en `sobre-oro`.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.oro,
      foregroundColor: p.sobreOro,
      elevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
    ),
    // Chips (componentes/Chip.md): seleccionado = accion con check; sin
    // seleccionar, borde borde-control. Alto visual 36.
    chipTheme: ChipThemeData(
      backgroundColor: p.superficie,
      selectedColor: p.accion,
      disabledColor: p.superficieHundida,
      checkmarkColor: p.sobreAccion,
      secondarySelectedColor: p.accion,
      showCheckmark: true,
      // RawChip resuelve el color por estado, no el TextStyle completo.
      labelStyle: textos.etiqueta.copyWith(
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.sobreAccion : p.texto,
        ),
      ),
      secondaryLabelStyle: textos.etiqueta.copyWith(fontWeight: FontWeight.w600, color: p.sobreAccion),
      side: WidgetStateBorderSide.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? BorderSide(color: p.accion) : BorderSide(color: p.bordeControl),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.pill)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    // Segmentado: la opción activa se eleva sobre superficie-hundida.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.superficie : p.superficieHundida,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? p.texto : p.texto2,
        ),
        iconColor: WidgetStatePropertyAll(p.texto),
        side: WidgetStateProperty.resolveWith(
          (estados) => BorderSide(color: estados.contains(WidgetState.selected) ? p.bordeControl : p.superficieHundida),
        ),
        shape: WidgetStatePropertyAll(esquinasM),
        textStyle: WidgetStatePropertyAll(textos.etiqueta.copyWith(fontWeight: FontWeight.w600)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(p.superficie),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? p.accion : p.bordeControl,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accion,
      inactiveTrackColor: p.grafPista,
      thumbColor: p.accion,
      overlayColor: p.accion.withValues(alpha: 0.12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accion, linearTrackColor: p.grafPista),
    // Snackbar (componentes/Aviso.md): dice el resultado y ofrece Deshacer.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.esOscura ? const Color(0xFF2A3C5C) : p.texto,
      contentTextStyle: textos.cuerpo.copyWith(color: p.esOscura ? p.texto : p.superficie),
      actionTextColor: p.esOscura ? p.accion : const Color(0xFFB3CDF7),
      behavior: SnackBarBehavior.floating,
      shape: esquinasM,
      elevation: 0,
    ),
    // Diálogo: solo para confirmar algo que cambia datos (componentes/Hoja.md).
    dialogTheme: DialogThemeData(
      backgroundColor: p.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.l)),
      titleTextStyle: textos.seccion,
      contentTextStyle: textos.cuerpo,
    ),
    // Hoja: esquinas radio-xl y agarradera.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.superficie,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: p.velo,
      showDragHandle: true,
      dragHandleColor: p.bordeControl,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radios.xl))),
    ),
    // Renglón (componentes/Renglon.md): título cuerpo-fuerte, subtítulo
    // etiqueta en texto-2.
    listTileTheme: ListTileThemeData(
      iconColor: p.texto,
      minVerticalPadding: 10,
      titleTextStyle: textos.cuerpoFuerte,
      subtitleTextStyle: textos.etiqueta,
      leadingAndTrailingTextStyle: textos.cuerpoFuerte,
    ),
    // Campo (componentes/Campo.md): alto 52, borde borde-control; enfocado
    // con 2 px de foco; error en peligro-texto.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.superficie,
      labelStyle: textos.etiqueta,
      hintStyle: textos.cuerpo.copyWith(color: p.texto2),
      helperStyle: textos.etiqueta,
      errorStyle: textos.etiqueta.copyWith(color: p.peligroTexto),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        borderSide: BorderSide(color: p.bordeControl),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        borderSide: BorderSide(color: p.bordeControl),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        borderSide: BorderSide(color: p.foco, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        borderSide: BorderSide(color: p.peligroTexto),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radios.m),
        borderSide: BorderSide(color: p.peligroTexto, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.superficieHundida,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (e) => textos.etiqueta.copyWith(
          fontWeight: FontWeight.w600,
          color: e.contains(WidgetState.selected) ? p.texto : p.texto2,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (e) => IconThemeData(color: e.contains(WidgetState.selected) ? p.texto : p.texto2),
      ),
    ),
  );
}
