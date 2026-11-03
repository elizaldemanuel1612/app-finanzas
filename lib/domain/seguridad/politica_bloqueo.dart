import '../../core/result.dart';

/// Cómo se desbloquea la app (spec-app-finanzas-v2.md §7.3). El PIN existe
/// siempre: es el respaldo si la biometría falla y lo que se pide cada
/// semana.
enum MetodoDesbloqueo { biometria, pin, contrasena }

/// Cada cuánto se pide el PIN aunque se use Face ID o contraseña, para no
/// olvidarlo (como el iPhone).
const pinCadaCuanto = Duration(days: 7);

/// Tiempo fuera de la app tras el cual se vuelve a pedir el desbloqueo.
const bloquearTrasSegundoPlano = Duration(minutes: 1);

/// Intentos fallidos tras los que ya solo se entra confirmando la cuenta de
/// Google (el correo del usuario).
const intentosAntesDeRecuperar = 10;

const largoPin = 6;

/// Toca pedir el PIN: nunca se ha usado, o pasó una semana desde la última vez.
bool tocaPedirPin({required DateTime? ultimoPin, required DateTime ahora}) =>
    ultimoPin == null || !ahora.isBefore(ultimoPin.add(pinCadaCuanto));

/// Al volver de segundo plano, ¿se vuelve a bloquear?
bool debeBloquearAlVolver({required DateTime? salioEn, required DateTime ahora}) =>
    salioEn == null || !ahora.isBefore(salioEn.add(bloquearTrasSegundoPlano));

/// Cuánto esperar tras [fallidos] intentos seguidos; `null` cuando ya solo
/// se puede recuperar con la cuenta de Google.
Duration? esperaTrasFallidos(int fallidos) {
  if (fallidos >= intentosAntesDeRecuperar) return null;
  return switch (fallidos) {
    < 5 => Duration.zero,
    5 => const Duration(seconds: 30),
    6 => const Duration(minutes: 1),
    7 => const Duration(minutes: 5),
    8 => const Duration(minutes: 15),
    _ => const Duration(hours: 1),
  };
}

/// 6 dígitos, y no algo que se adivina a la primera (111111, 123456, 654321).
Resultado<String> validarPinNuevo(String pin) {
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) return const Falla('El PIN son 6 números.');
  final digitos = pin.codeUnits.map((c) => c - 48).toList();
  final iguales = digitos.every((d) => d == digitos.first);
  bool consecutivo(int paso) {
    for (var i = 1; i < digitos.length; i++) {
      if (digitos[i] != (digitos[i - 1] + paso) % 10) return false;
    }
    return true;
  }

  if (iguales || consecutivo(1) || consecutivo(9)) {
    return const Falla('Ese PIN es muy fácil de adivinar. Elige otro.');
  }
  return Exito(pin);
}

/// Al menos 6 caracteres, con letras y números.
Resultado<String> validarContrasenaNueva(String contrasena) {
  if (contrasena.length < 6) return const Falla('Usa al menos 6 caracteres.');
  if (!contrasena.contains(RegExp(r'\p{L}', unicode: true)) || !contrasena.contains(RegExp(r'\d'))) {
    return const Falla('Combina letras y números.');
  }
  return Exito(contrasena);
}
