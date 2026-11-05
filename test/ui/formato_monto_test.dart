import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/ui/comun/formato_dinero.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _valor(String texto, [int? cursor]) =>
    TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: cursor ?? texto.length));

TextEditingValue _teclear(String anterior, String nuevo, [int? cursor]) =>
    formatearMontoAlTeclear(_valor(anterior), _valor(nuevo, cursor));

void main() {
  test('pone las comas de miles al escribir', () {
    expect(_teclear('1700', '17000').text, '17,000');
    expect(_teclear('17,000', '17,0000').text, '170,000');
    expect(_teclear('123,456', '123,4567').text, '1,234,567');
    expect(_teclear('1,234', '1,234.5').text, '1,234.5');
  });

  test('el cursor sigue al dígito que se escribió', () {
    // "17,000" con cursor tras el "1" y se teclea "2": "127,000".
    final r = _teclear('17,000', '127,000', 2);
    expect(r.text, '127,000');
    expect(r.selection.extentOffset, 2);
  });

  test('borrar una coma se lleva el dígito de la izquierda', () {
    // Cursor justo después de la coma de "17,000"; borrar la deja en "1000".
    final r = formatearMontoAlTeclear(_valor('17,000', 3), _valor('17000', 2));
    expect(r.text, '1,000');
    expect(r.selection.extentOffset, 1);
  });

  test('rechaza un segundo punto o un tercer decimal', () {
    expect(_teclear('12.5', '12.5.').text, '12.5');
    expect(_teclear('12.55', '12.555').text, '12.55');
  });

  test('el texto con comas se lee igual', () {
    expect(Dinero.intentarDesdeTexto('17,000'), const Dinero.pesos(17000));
    expect(textoEditableDeDinero(const Dinero(123456789)), '1,234,567.89');
    expect(conComasDeMiles('999'), '999');
  });
}
