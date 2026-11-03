import 'package:app_finanzas/domain/analisis/agrupar_descripciones.dart';
import 'package:test/test.dart';

void main() {
  test('el ejemplo del café: todo se junta como "Café"', () {
    final textos = {'café': 2, 'cafe': 1, 'cafés': 1, 'Cafes': 1, 'pan y café': 1, 'un café': 1};
    final g = agruparDescripciones(textos);
    final grupos = {for (final t in textos.keys) g.grupo(t)};
    expect(grupos, {'cafe'});
    expect(g.nombre('cafe'), 'Café');
  });

  test('no junta cosas que solo comparten una palabra que nunca va sola', () {
    final g = agruparDescripciones({'Cena con amigos': 1, 'Comida con amigos': 1});
    expect(g.grupo('Cena con amigos'), isNot(g.grupo('Comida con amigos')));
    expect(g.nombre(g.grupo('Cena con amigos')), 'Cena con amigos');
  });

  test('una descripción larga va al concepto más frecuente que contenga', () {
    final g = agruparDescripciones({'pan': 1, 'café': 3, 'pan y café': 1, 'Pan dulce': 1});
    expect(g.grupo('pan y café'), 'cafe');
    expect(g.grupo('Pan dulce'), 'pan');
    expect(g.nombre('pan'), 'Pan');
  });

  test('plurales en -es y en -s, y mayúsculas', () {
    final g = agruparDescripciones({'Tacos': 1, 'taco': 1, 'Panes': 1, 'PAN': 1, 'Gas': 1});
    expect(g.grupo('Tacos'), g.grupo('taco'));
    expect(g.grupo('Panes'), g.grupo('PAN'));
    expect(g.nombre('taco'), 'Taco');
    expect(g.grupo('Gas'), 'gas');
    final h = agruparDescripciones({'chicles': 1, 'chicle': 1, 'Papeles': 1, 'papel': 1, 'postres': 1, 'Postre': 1});
    expect(h.grupo('chicles'), h.grupo('chicle'));
    expect(h.grupo('Papeles'), h.grupo('papel'));
    expect(h.grupo('postres'), h.grupo('Postre'));
  });

  test('sin forma en singular escrita, usa la más usada', () {
    final g = agruparDescripciones({'Uber': 1, 'ubers': 3});
    expect(g.nombre('uber'), 'Uber');
    final h = agruparDescripciones({'chicles': 2});
    expect(h.nombre('chicle'), 'Chicles');
  });

  test('solo palabras vacías o signos: se queda con su texto', () {
    final g = agruparDescripciones({'de la': 1, '!!!': 1});
    expect(g.grupo('de la'), 'de la');
    expect(g.nombre(g.grupo('!!!')), '!!!');
    expect(g.nombre('nada'), 'Nada');
  });
}
