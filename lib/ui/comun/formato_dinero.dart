import '../../core/money.dart';

/// Texto editable para un campo de captura ("35.00"), inverso de
/// [Dinero.intentarDesdeTexto]. Solo para precargar formularios — nunca
/// para calcular (mismo principio que [Dinero.formateado]).
String textoEditableDeDinero(Dinero d) {
  final pesos = d.centavos ~/ 100;
  final centavos = (d.centavos % 100).toString().padLeft(2, '0');
  return '$pesos.$centavos';
}
