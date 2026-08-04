/// Aritmética de dinero en centavos enteros.
///
/// Regla no negociable (spec-app-finanzas-v2.md §1.1, paquete-construccion-
/// final.md §6.1): todo monto se guarda como entero en centavos. Prohibido
/// `double` en cualquier operación monetaria — 0.1 + 0.2 no da 0.3 en punto
/// flotante, y sumas de cientos de movimientos terminan desfasadas.
///
/// [Dinero] es el único tipo que el dominio usa para representar montos.
/// Envolver el `int` evita que un centavo se sume por accidente con un peso,
/// o que un cálculo cuele un `double` sin que el compilador lo marque.
final class Dinero implements Comparable<Dinero> {
  final int centavos;

  const Dinero(this.centavos);
  const Dinero.cero() : centavos = 0;
  const Dinero.pesos(int pesos) : centavos = pesos * 100;

  /// Convierte texto de un campo de captura ("19.99", "1,019.84") a centavos
  /// sin pasar por `double` en ningún punto. Regresa `null` si el texto no
  /// tiene forma de monto (a lo más 2 decimales, sin signo).
  static Dinero? intentarDesdeTexto(String texto) {
    final limpio = texto.trim().replaceAll(',', '');
    final match = RegExp(r'^(\d+)(\.(\d{1,2}))?$').firstMatch(limpio);
    if (match == null) return null;
    final pesos = int.parse(match.group(1)!);
    final parteCentavos = (match.group(3) ?? '').padRight(2, '0');
    final centavos = parteCentavos.isEmpty ? 0 : int.parse(parteCentavos);
    return Dinero(pesos * 100 + centavos);
  }

  static Dinero suma(Iterable<Dinero> valores) =>
      valores.fold(const Dinero.cero(), (acc, d) => acc + d);

  bool get esPositivo => centavos > 0;
  bool get esNegativo => centavos < 0;
  bool get esCero => centavos == 0;

  Dinero get absoluto => Dinero(centavos.abs());

  Dinero operator +(Dinero otro) => Dinero(centavos + otro.centavos);
  Dinero operator -(Dinero otro) => Dinero(centavos - otro.centavos);
  Dinero operator *(int factor) => Dinero(centavos * factor);
  Dinero operator -() => Dinero(-centavos);

  bool operator <(Dinero otro) => centavos < otro.centavos;
  bool operator <=(Dinero otro) => centavos <= otro.centavos;
  bool operator >(Dinero otro) => centavos > otro.centavos;
  bool operator >=(Dinero otro) => centavos >= otro.centavos;

  @override
  int compareTo(Dinero otro) => centavos.compareTo(otro.centavos);

  @override
  bool operator ==(Object other) =>
      other is Dinero && other.centavos == centavos;
  @override
  int get hashCode => centavos.hashCode;

  /// Formato de presentación ("$1,019.84"). Solo para mostrar en la interfaz
  /// — nunca para calcular. La moneda se fija por configuración de la app
  /// (es_MX), no por la del sistema (paquete-construccion-final.md §3, fila
  /// "Formato de moneda").
  String formateado({String simbolo = r'$'}) {
    final negativo = centavos < 0;
    final abs = centavos.abs();
    final pesos = abs ~/ 100;
    final resto = (abs % 100).toString().padLeft(2, '0');
    final pesosTexto = _conSeparadorDeMiles(pesos);
    return '${negativo ? '-' : ''}$simbolo$pesosTexto.$resto';
  }

  static String _conSeparadorDeMiles(int n) {
    final texto = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      final posDesdeElFinal = texto.length - i;
      if (i > 0 && posDesdeElFinal % 3 == 0) buffer.write(',');
      buffer.write(texto[i]);
    }
    return buffer.toString();
  }

  @override
  String toString() => formateado();
}
