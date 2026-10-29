import '../clasificacion/normalizacion_texto.dart';

/// Emoji que se pone a una categoría nueva cuando el CSV no trae uno: el
/// mismo que usa "Nueva categoría" por defecto.
const emojiPorDefecto = '🏷️';

/// El emoji que se ponía a toda categoría creada al importar antes del
/// 2026-10-29. Una categoría que todavía lo tiene recibe el emoji del CSV
/// (o el sugerido) al volver a importar.
const emojiImportadoAntiguo = '📥';

/// Palabras clave (sin acentos, en minúsculas) → emoji. Gana la primera que
/// aparezca en el nombre, así que las más específicas van antes ("auto
/// seguro" es seguro antes que auto).
const _emojiPorPalabra = [
  ('seguro', '🛡️'),
  ('gasolina', '⛽'),
  ('uber', '🚕'),
  ('taxi', '🚕'),
  ('transporte', '🚌'),
  ('estacionamiento', '🅿️'),
  ('auto', '🚗'),
  ('carro', '🚗'),
  ('coche', '🚗'),
  ('vivienda', '🏠'),
  ('renta', '🏠'),
  ('casa', '🏠'),
  ('hipoteca', '🏠'),
  ('luz', '💡'),
  ('agua', '🚰'),
  ('gas', '🔥'),
  ('internet', '📶'),
  ('telefono', '📱'),
  ('celular', '📱'),
  ('servicio', '🧾'),
  ('super', '🛒'),
  ('despensa', '🛒'),
  ('mandado', '🛒'),
  ('restaurante', '🍽️'),
  ('comida', '🍽️'),
  ('cafe', '☕'),
  ('salida', '🍿'),
  ('diversion', '🍿'),
  ('cine', '🎬'),
  ('entretenimiento', '🎬'),
  ('bar', '🍻'),
  ('gym', '🏋️'),
  ('gimnasio', '🏋️'),
  ('deporte', '⚽'),
  ('salud', '💊'),
  ('medic', '💊'),
  ('farmacia', '💊'),
  ('doctor', '🩺'),
  ('hijo', '👶'),
  ('bebe', '👶'),
  ('escuela', '🎒'),
  ('colegiatura', '🎒'),
  ('educacion', '📚'),
  ('curso', '📚'),
  ('libro', '📚'),
  ('suscripcion', '🎵'),
  ('streaming', '🎵'),
  ('netflix', '🎵'),
  ('spotify', '🎵'),
  ('ropa', '👕'),
  ('zapato', '👟'),
  ('viaje', '✈️'),
  ('vacacion', '✈️'),
  ('mascota', '🐶'),
  ('perro', '🐶'),
  ('gato', '🐱'),
  ('veterinari', '🐶'),
  ('regalo', '🎁'),
  ('belleza', '💇'),
  ('cuidado personal', '💇'),
  ('hogar', '🛋️'),
  ('mantenimiento', '🔧'),
  ('tarjeta', '💳'),
  ('credito', '💳'),
  ('deuda', '💳'),
  ('prestamo', '💳'),
  ('ahorro', '🐷'),
  ('inversion', '📈'),
  ('donativo', '🤝'),
  ('impuesto', '🏛️'),
];

/// Sugiere un emoji para una categoría a partir de su nombre ("Super/Comida"
/// → 🛒). [emojiPorDefecto] si ninguna palabra clave aparece.
///
/// Compara por palabra: la clave debe ser el inicio de una palabra del
/// nombre ("salida" calza con "Salidas"), y las de [_palabrasExactas],
/// la palabra completa — si no, "Gastos varios" sería 🔥 por "gas".
String sugerirEmoji(String nombreCategoria) {
  final nombre = normalizarTexto(nombreCategoria);
  final palabras = nombre.split(RegExp(r'[^a-zñ0-9]+')).where((p) => p.isNotEmpty).toList();
  for (final (clave, emoji) in _emojiPorPalabra) {
    final calza = clave.contains(' ')
        ? nombre.contains(clave)
        : palabras.any((p) => _palabrasExactas.contains(clave) ? p == clave : p.startsWith(clave));
    if (calza) return emoji;
  }
  return emojiPorDefecto;
}

const _palabrasExactas = {'gas', 'bar', 'luz'};

final _inicioNoTexto = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);

/// Separa un emoji pegado al inicio del nombre ("🛒 Súper" → 🛒 y "Súper"),
/// como lo escriben muchas hojas y las IA. Si no hay, el emoji es `null`.
({String? emoji, String nombre}) separarEmojiDelNombre(String texto) {
  final limpio = texto.trim();
  final prefijo = _inicioNoTexto.firstMatch(limpio)?.group(0);
  if (prefijo == null) return (emoji: null, nombre: limpio);
  final emoji = prefijo.trim();
  final nombre = limpio.substring(prefijo.length).trim();
  // Solo símbolos sueltos ("-", "#") no son un emoji: se deja el texto igual.
  if (emoji.isEmpty || nombre.isEmpty || !_esEmoji(emoji)) return (emoji: null, nombre: limpio);
  return (emoji: emoji, nombre: nombre);
}

/// Un emoji es de fuera del ASCII; con eso basta para no confundir un
/// guion o un numeral con un emoji.
bool _esEmoji(String texto) => texto.runes.any((r) => r > 0x7F);
