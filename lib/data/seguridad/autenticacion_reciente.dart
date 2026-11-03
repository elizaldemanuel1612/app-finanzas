import 'dart:convert';

/// Cuánto puede haber pasado desde que el usuario escribió su contraseña
/// de Google para aceptar la recuperación del PIN.
const margenAutenticacionReciente = Duration(minutes: 5);

/// Por qué no se aceptó la confirmación de Google.
enum MotivoNoReciente {
  /// Google no mandó la hora en que el usuario escribió su contraseña.
  sinHora,

  /// Google confirmó con una sesión que ya estaba abierta: no pidió contraseña.
  sesionAbierta,
}

/// ¿El usuario escribió su contraseña de Google hace muy poco? Lee el claim
/// `auth_time` del ID token de Google (spec §7.3): es la hora real de la
/// última vez que se autenticó, no la de la ventana que acaba de cerrar.
/// Sin él no se puede saber si Google reusó una sesión abierta en el
/// teléfono, y se rechaza. `null` si sí es reciente.
MotivoNoReciente? verificarAutenticacionReciente({required String? idToken, required DateTime ahora}) {
  final authTime = _authTime(idToken);
  if (authTime == null) return MotivoNoReciente.sinHora;
  final diferencia = ahora.difference(authTime);
  // Un reloj del teléfono un poco adelantado o atrasado no debe bloquear.
  if (diferencia > margenAutenticacionReciente || diferencia < -margenAutenticacionReciente) {
    return MotivoNoReciente.sesionAbierta;
  }
  return null;
}

DateTime? _authTime(String? idToken) {
  if (idToken == null) return null;
  final partes = idToken.split('.');
  if (partes.length != 3) return null;
  try {
    final carga = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))));
    final segundos = (carga as Map<String, dynamic>)['auth_time'];
    if (segundos is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(segundos.toInt() * 1000);
  } catch (_) {
    return null;
  }
}
