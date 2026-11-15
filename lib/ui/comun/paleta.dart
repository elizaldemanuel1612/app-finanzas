import 'dart:math' as math;

/// Hex crudos de la paleta, separados de `tema.dart` a propósito: este
/// archivo **no importa Flutter** (`dart:math` es Dart puro), así que
/// `test/ui_contraste_test.dart` lo prueba con `dart test` sin árbol de
/// widgets (Fase 6, Bloque 4.1).
///
/// Rediseño (2026-11-15): los valores son los tokens semánticos de
/// `docs/rediseno/design-system/tokens.json`, uno a uno y con el mismo nombre
/// en camelCase (`texto-2` → `texto2`). Cada estado tiene versión de
/// gráfica (3:1: `exito`, `atencion`, `peligro`) y de texto (4.5:1:
/// `exitoTexto`…). `atencion` quedó en #D18306 en claro para pasar 3:1
/// sobre blanco.
abstract final class PaletaHex {
  /// Fondo de toda pantalla (marfil / noche).
  static const fondo = 0xFFFCFAF7;

  /// Tarjetas, hojas inferiores, grupos de renglones.
  static const superficie = 0xFFFFFFFF;

  /// Campos, pista de controles segmentados, skeleton.
  static const superficieHundida = 0xFFF4F1EC;

  /// Bordes finos (1 px) de tarjetas y separadores de renglón. Decorativo: no lleva contraste.
  static const borde = 0xFFE6E8EE;

  /// Borde de campos, chips sin seleccionar y controles: 3:1 contra superficie.
  static const bordeControl = 0xFF8A93A6;

  /// Texto principal y cifras.
  static const texto = 0xFF0B1F3B;

  /// Texto secundario: etiquetas, fechas, subtítulos. AA sobre fondo y superficie.
  static const texto2 = 0xFF5A6478;

  /// Solo controles deshabilitados (exentos de contraste).
  static const textoDesactivado = 0xFFA3AAB8;

  /// Botón primario, selección (chip, segmento, pestaña activa).
  static const accion = 0xFF0B1F3B;

  /// Texto e íconos sobre accion.
  static const sobreAccion = 0xFFFFFFFF;

  /// Botón primario presionado.
  static const accionPresionada = 0xFF1C3A66;

  /// Anillo de foco de 2 px, separado 2 px del control.
  static const foco = 0xFF2F6FDB;

  /// Acento: botón ＋, ícono de meta, emblema. Nunca texto ni gráficas.
  static const oro = 0xFFD4AF37;

  /// Ícono sobre oro (8:1).
  static const sobreOro = 0xFF0B1F3B;

  /// Única forma de texto dorado (insignia Premium).
  static const oroTexto = 0xFF7A5C0A;

  /// Tarjeta héroe: una por pantalla como máximo.
  static const heroeFondo = 0xFF0B1F3B;

  /// Texto principal sobre heroe-fondo.
  static const heroeTexto = 0xFFF7F4EE;

  /// Texto secundario sobre heroe-fondo.
  static const heroeTexto2 = 0xFFAEB9CC;

  /// Pista de barras dentro del héroe.
  static const heroePista = 0xFF2A3F63;

  /// Relleno de barras y gráficas: vas bien.
  static const exito = 0xFF16A34A;

  /// Texto de estado positivo.
  static const exitoTexto = 0xFF15803D;

  /// Fondo de chip o banner positivo.
  static const exitoFondo = 0xFFEAF6EE;

  /// Relleno de barras: vas rápido. Refinado desde #F59E0B para llegar a 3:1 sobre blanco.
  static const atencion = 0xFFD18306;

  /// Texto de atención.
  static const atencionTexto = 0xFF92400E;

  /// Fondo de banner o chip de atención.
  static const atencionFondo = 0xFFFDF3E1;

  /// Relleno de barras: te pasaste (segmento de exceso).
  static const peligro = 0xFFEF4444;

  /// Texto de peligro.
  static const peligroTexto = 0xFFB91C1C;

  /// Fondo de banner o chip de peligro.
  static const peligroFondo = 0xFFFDECEC;

  /// Texto de aviso informativo (ciclo cerrado).
  static const infoTexto = 0xFF1F4E8C;

  /// Fondo de aviso informativo.
  static const infoFondo = 0xFFEAF1FB;

  /// Estado positivo dentro del héroe.
  static const heroeExito = 0xFF5BE08C;

  /// Estado de atención dentro del héroe.
  static const heroeAtencion = 0xFFFFC94D;

  /// Estado de peligro dentro del héroe.
  static const heroePeligro = 0xFFFF8A8A;

  /// Serie 1 de gráficas (categoría principal).
  static const graf1 = 0xFF1F4E8C;

  /// Serie 2.
  static const graf2 = 0xFF2B8C7E;

  /// Serie 3.
  static const graf3 = 0xFFB8661F;

  /// Serie 4.
  static const graf4 = 0xFF7A5DB0;

  /// Serie 'Otros' y ciclo anterior.
  static const graf5 = 0xFF8A93A6;

  /// Pista de barras de ritmo, progreso y proporción.
  static const grafPista = 0xFFECE9E3;

  /// Líneas guía de ejes.
  static const grafGuia = 0xFFE6E8EE;

  /// La marca de ritmo: línea de 2 px donde deberías ir hoy.
  static const marcaRitmo = 0xFF0B1F3B;

  /// Velo detrás de hojas y diálogos.
  static const velo = 0x660B1F3B;

  // Nombres de antes del rediseño, como alias de los tokens: así las
  // referencias `ColoresApp.x` existentes siguen funcionando mientras se
  // migran pantalla por pantalla. Lo nuevo usa los nombres de arriba.
  static const tarjeta = superficie;
  static const tinta = texto;
  static const medio = texto2;
  static const linea = borde;
  static const azul = accion;
  static const azulSuave = infoFondo;
  static const sobreAzul = sobreAccion;
  static const pista = grafPista;
  static const verde = exito;
  static const verdeSuave = exitoFondo;
  static const verdeTexto = exitoTexto;
  static const ambar = atencion;
  static const ambarSuave = atencionFondo;
  static const ambarTexto = atencionTexto;
  static const coral = peligro;
  static const coralSuave = peligroFondo;
  static const coralTexto = peligroTexto;

  /// Fondo tenue del ícono de la meta (no está en tokens.json: es el halo
  /// del único acento dorado).
  static const oroSuave = 0xFFF8F0D8;

  /// Lo que tienes y lo que debes en las cuentas, en tonos apagados
  /// (2026-11-06). El rediseño pide montos neutros en `texto`; se quedan
  /// para las pantallas que aún no migran.
  static const aFavor = 0xFF2E7D5B;
  static const enContra = 0xFFB4534B;

  /// Azul noche de marca, igual en los dos modos: login, bienvenida y
  /// emblema, siempre con texto claro encima.
  static const noche = 0xFF0B1F3B;
  static const azulMarino = 0xFF143A66;
}

/// Modo oscuro: los mismos tokens en su valor `oscuro`.
abstract final class PaletaHexOscura {
  /// Fondo de toda pantalla (marfil / noche).
  static const fondo = 0xFF0A1424;

  /// Tarjetas, hojas inferiores, grupos de renglones.
  static const superficie = 0xFF13213A;

  /// Campos, pista de controles segmentados, skeleton.
  static const superficieHundida = 0xFF0F1B30;

  /// Bordes finos (1 px) de tarjetas y separadores de renglón. Decorativo: no lleva contraste.
  static const borde = 0xFF22345A;

  /// Borde de campos, chips sin seleccionar y controles: 3:1 contra superficie.
  static const bordeControl = 0xFF6A7FA6;

  /// Texto principal y cifras.
  static const texto = 0xFFEEF1F7;

  /// Texto secundario: etiquetas, fechas, subtítulos. AA sobre fondo y superficie.
  static const texto2 = 0xFFA9B4C8;

  /// Solo controles deshabilitados (exentos de contraste).
  static const textoDesactivado = 0xFF5B6B88;

  /// Botón primario, selección (chip, segmento, pestaña activa).
  static const accion = 0xFF8DB4F2;

  /// Texto e íconos sobre accion.
  static const sobreAccion = 0xFF0A1424;

  /// Botón primario presionado.
  static const accionPresionada = 0xFFB3CDF7;

  /// Anillo de foco de 2 px, separado 2 px del control.
  static const foco = 0xFF8DB4F2;

  /// Acento: botón ＋, ícono de meta, emblema. Nunca texto ni gráficas.
  static const oro = 0xFFD4AF37;

  /// Ícono sobre oro (8:1).
  static const sobreOro = 0xFF0B1F3B;

  /// Única forma de texto dorado (insignia Premium).
  static const oroTexto = 0xFFE2C467;

  /// Tarjeta héroe: una por pantalla como máximo.
  static const heroeFondo = 0xFF1A2F55;

  /// Texto principal sobre heroe-fondo.
  static const heroeTexto = 0xFFF7F4EE;

  /// Texto secundario sobre heroe-fondo.
  static const heroeTexto2 = 0xFFB9C4D8;

  /// Pista de barras dentro del héroe.
  static const heroePista = 0xFF2E4670;

  /// Relleno de barras y gráficas: vas bien.
  static const exito = 0xFF4ADE80;

  /// Texto de estado positivo.
  static const exitoTexto = 0xFF4ADE80;

  /// Fondo de chip o banner positivo.
  static const exitoFondo = 0xFF12301F;

  /// Relleno de barras: vas rápido. Refinado desde #F59E0B para llegar a 3:1 sobre blanco.
  static const atencion = 0xFFFBBF24;

  /// Texto de atención.
  static const atencionTexto = 0xFFFBBF24;

  /// Fondo de banner o chip de atención.
  static const atencionFondo = 0xFF33260C;

  /// Relleno de barras: te pasaste (segmento de exceso).
  static const peligro = 0xFFF87171;

  /// Texto de peligro.
  static const peligroTexto = 0xFFFCA5A5;

  /// Fondo de banner o chip de peligro.
  static const peligroFondo = 0xFF3A1519;

  /// Texto de aviso informativo (ciclo cerrado).
  static const infoTexto = 0xFF8DB4F2;

  /// Fondo de aviso informativo.
  static const infoFondo = 0xFF16294A;

  /// Estado positivo dentro del héroe.
  static const heroeExito = 0xFF5BE08C;

  /// Estado de atención dentro del héroe.
  static const heroeAtencion = 0xFFFFC94D;

  /// Estado de peligro dentro del héroe.
  static const heroePeligro = 0xFFFF8A8A;

  /// Serie 1 de gráficas (categoría principal).
  static const graf1 = 0xFF8DB4F2;

  /// Serie 2.
  static const graf2 = 0xFF5CC7B5;

  /// Serie 3.
  static const graf3 = 0xFFE8A15C;

  /// Serie 4.
  static const graf4 = 0xFFB39DE6;

  /// Serie 'Otros' y ciclo anterior.
  static const graf5 = 0xFF6B7A93;

  /// Pista de barras de ritmo, progreso y proporción.
  static const grafPista = 0xFF22345A;

  /// Líneas guía de ejes.
  static const grafGuia = 0xFF22345A;

  /// La marca de ritmo: línea de 2 px donde deberías ir hoy.
  static const marcaRitmo = 0xFFEEF1F7;

  /// Velo detrás de hojas y diálogos.
  static const velo = 0x99000000;

  // Nombres de antes del rediseño, como alias de los tokens: así las
  // referencias `ColoresApp.x` existentes siguen funcionando mientras se
  // migran pantalla por pantalla. Lo nuevo usa los nombres de arriba.
  static const tarjeta = superficie;
  static const tinta = texto;
  static const medio = texto2;
  static const linea = borde;
  static const azul = accion;
  static const azulSuave = infoFondo;
  static const sobreAzul = sobreAccion;
  static const pista = grafPista;
  static const verde = exito;
  static const verdeSuave = exitoFondo;
  static const verdeTexto = exitoTexto;
  static const ambar = atencion;
  static const ambarSuave = atencionFondo;
  static const ambarTexto = atencionTexto;
  static const coral = peligro;
  static const coralSuave = peligroFondo;
  static const coralTexto = peligroTexto;

  static const oroSuave = 0xFF2C2615;
  static const aFavor = 0xFF7CC4A0;
  static const enContra = 0xFFE39A92;
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
