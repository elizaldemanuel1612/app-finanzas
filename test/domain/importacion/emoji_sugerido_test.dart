import 'package:app_finanzas/domain/importacion/emoji_sugerido.dart';
import 'package:test/test.dart';

void main() {
  test('sugiere por palabra clave, sin importar acentos ni mayúsculas', () {
    expect(sugerirEmoji('Super/Comida'), '🛒');
    expect(sugerirEmoji('Salidas/Diversión'), '🍿');
    expect(sugerirEmoji('Auto operación'), '🚗');
    expect(sugerirEmoji('Seguro del auto'), '🛡️');
    expect(sugerirEmoji('Gym'), '🏋️');
    expect(sugerirEmoji('MEDICINAS'), '💊');
    expect(sugerirEmoji('Cuidado personal'), '💇');
  });

  test('las claves cortas solo cuentan como palabra completa', () {
    expect(sugerirEmoji('Gastos varios'), emojiPorDefecto);
    expect(sugerirEmoji('Gas'), '🔥');
    expect(sugerirEmoji('Barbería'), emojiPorDefecto);
  });

  test('sin coincidencia, el emoji por defecto', () {
    expect(sugerirEmoji('Varios'), emojiPorDefecto);
    expect(sugerirEmoji(''), emojiPorDefecto);
  });

  test('separa el emoji pegado al inicio del nombre', () {
    expect(separarEmojiDelNombre('🛒 Súper'), (emoji: '🛒', nombre: 'Súper'));
    expect(separarEmojiDelNombre('🏋️Gym'), (emoji: '🏋️', nombre: 'Gym'));
  });

  test('sin emoji, o con símbolos sueltos, deja el nombre igual', () {
    expect(separarEmojiDelNombre(' Súper '), (emoji: null, nombre: 'Súper'));
    expect(separarEmojiDelNombre('- Varios'), (emoji: null, nombre: '- Varios'));
    expect(separarEmojiDelNombre('🛒'), (emoji: null, nombre: '🛒'));
    expect(separarEmojiDelNombre(''), (emoji: null, nombre: ''));
  });
}
