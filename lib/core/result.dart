/// Resultado de una operación que puede fallar, sin usar excepciones para
/// control de flujo. El dominio nunca lanza para señalar una regla de
/// negocio incumplida (ej. partes de un ticket que no cuadran): regresa
/// [Falla] y quien llama decide qué hacer.
sealed class Resultado<T> {
  const Resultado();

  const factory Resultado.exito(T valor) = Exito<T>;
  const factory Resultado.falla(String mensaje) = Falla<T>;

  bool get esExito => this is Exito<T>;
  bool get esFalla => this is Falla<T>;

  /// Regresa el valor si es [Exito], o lanza si es [Falla].
  /// Úsalo solo donde ya se validó `esExito`, o en pruebas.
  T get valorOLanza => switch (this) {
        Exito<T>(:final valor) => valor,
        Falla<T>(:final mensaje) => throw StateError(mensaje),
      };

  R cuando<R>({
    required R Function(T valor) exito,
    required R Function(String mensaje) falla,
  }) =>
      switch (this) {
        Exito<T>(:final valor) => exito(valor),
        Falla<T>(:final mensaje) => falla(mensaje),
      };
}

final class Exito<T> extends Resultado<T> {
  final T valor;
  const Exito(this.valor);

  @override
  bool operator ==(Object other) => other is Exito<T> && other.valor == valor;
  @override
  int get hashCode => Object.hash(Exito, valor);
  @override
  String toString() => 'Exito($valor)';
}

final class Falla<T> extends Resultado<T> {
  final String mensaje;
  const Falla(this.mensaje);

  @override
  bool operator ==(Object other) =>
      other is Falla<T> && other.mensaje == mensaje;
  @override
  int get hashCode => Object.hash(Falla, mensaje);
  @override
  String toString() => 'Falla($mensaje)';
}
