import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';

/// Filtra y da formato a lo que se teclea en un campo de monto: solo
/// dígitos y un único punto con hasta 2 decimales —el formato que acepta
/// [Dinero.intentarDesdeTexto]— y las comas de miles se ponen solas al
/// escribir ("17000" → "17,000"). El "$" va como `prefixText` del campo.
/// `keyboardType: numberWithOptions` solo le pide al sistema que **muestre**
/// un teclado numérico; no bloquea un teclado físico, un IME de terceros,
/// dictado ni pegar texto, así que sin esto cualquiera de esos caminos deja
/// escribir letras en un campo que solo debería aceptar números.
final List<TextInputFormatter> formateadoresDeMonto = [
  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
  TextInputFormatter.withFunction(formatearMontoAlTeclear),
];

/// "1234567.5" → "1,234,567.5". Sin comas que respetar: las pone de nuevo.
String conComasDeMiles(String texto) {
  final limpio = texto.replaceAll(',', '');
  final punto = limpio.indexOf('.');
  final entero = punto < 0 ? limpio : limpio.substring(0, punto);
  final resto = punto < 0 ? '' : limpio.substring(punto);
  final grupos = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) grupos.write(',');
    grupos.write(entero[i]);
  }
  return '$grupos$resto';
}

/// El paso de [formateadoresDeMonto] que acomoda las comas sin mover el
/// cursor de entre los dígitos. Borrar una coma borra el dígito anterior,
/// como en las apps de banco.
@visibleForTesting
TextEditingValue formatearMontoAlTeclear(TextEditingValue anterior, TextEditingValue nuevo) {
  var texto = nuevo.text;
  var cursor = nuevo.selection.isValid ? nuevo.selection.extentOffset : texto.length;
  final sinComasAntes = anterior.text.replaceAll(',', '');
  // Se borró solo una coma: se lleva el dígito que tenía a la izquierda.
  if (texto.length < anterior.text.length && texto.replaceAll(',', '') == sinComasAntes && cursor > 0) {
    texto = texto.substring(0, cursor - 1) + texto.substring(cursor);
    cursor -= 1;
  }
  // Cuántos caracteres que no son coma quedan antes del cursor.
  final antesDelCursor = texto.substring(0, cursor.clamp(0, texto.length)).replaceAll(',', '').length;
  final limpio = texto.replaceAll(',', '');
  final partes = limpio.split('.');
  if (partes.length > 2 || (partes.length == 2 && partes[1].length > 2)) return anterior;
  final formateado = conComasDeMiles(limpio);
  var posicion = 0;
  var vistos = 0;
  while (posicion < formateado.length && vistos < antesDelCursor) {
    if (formateado[posicion] != ',') vistos++;
    posicion++;
  }
  return TextEditingValue(text: formateado, selection: TextSelection.collapsed(offset: posicion));
}

/// Texto editable para un campo de captura ("1,035.00"), inverso de
/// [Dinero.intentarDesdeTexto]. Solo para precargar formularios — nunca
/// para calcular (mismo principio que [Dinero.formateado]).
String textoEditableDeDinero(Dinero d) {
  final pesos = d.centavos ~/ 100;
  final centavos = (d.centavos % 100).toString().padLeft(2, '0');
  return conComasDeMiles('$pesos.$centavos');
}

/// [Dinero.formateado] no antepone "+" a positivos — este helper sí, para
/// mostrar el efecto de un ajuste temporal de presupuesto ("ajustado por
/// +$X" / "ajustado por -$X").
String signoYMonto(Dinero delta) =>
    '${delta.esPositivo ? '+' : '-'}${delta.absoluto.formateado()}';
