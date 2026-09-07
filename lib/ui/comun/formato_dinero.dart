import 'package:flutter/services.dart';

import '../../core/money.dart';

/// Filtra lo que se puede teclear en un campo de monto: solo dígitos, coma
/// (separador de miles) y un único punto con hasta 2 decimales — el mismo
/// formato que acepta [Dinero.intentarDesdeTexto]. `keyboardType:
/// numberWithOptions` solo le pide al sistema que **muestre** un teclado
/// numérico; no bloquea un teclado físico, un IME de terceros, dictado ni
/// pegar texto, así que sin esto cualquiera de esos caminos deja escribir
/// letras en un campo que solo debería aceptar números.
final List<TextInputFormatter> formateadoresDeMonto = [
  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
  TextInputFormatter.withFunction((anterior, nuevo) {
    final partes = nuevo.text.split('.');
    final decimalesInvalidos = partes.length == 2 && partes[1].length > 2;
    if (partes.length > 2 || decimalesInvalidos) return anterior;
    return nuevo;
  }),
];

/// Texto editable para un campo de captura ("35.00"), inverso de
/// [Dinero.intentarDesdeTexto]. Solo para precargar formularios — nunca
/// para calcular (mismo principio que [Dinero.formateado]).
String textoEditableDeDinero(Dinero d) {
  final pesos = d.centavos ~/ 100;
  final centavos = (d.centavos % 100).toString().padLeft(2, '0');
  return '$pesos.$centavos';
}

/// [Dinero.formateado] no antepone "+" a positivos — este helper sí, para
/// mostrar el efecto de un ajuste temporal de presupuesto ("ajustado por
/// +$X" / "ajustado por -$X").
String signoYMonto(Dinero delta) =>
    '${delta.esPositivo ? '+' : '-'}${delta.absoluto.formateado()}';
