import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:local_auth/local_auth.dart';

/// Face ID o huella del teléfono (spec-app-finanzas-v2.md §7.3). En la web
/// no hay: ahí se desbloquea con PIN o contraseña.
abstract final class Biometria {
  static final _auth = LocalAuthentication();

  /// Hay biometría registrada en el teléfono.
  static Future<bool> disponible() async {
    if (kIsWeb) return false;
    try {
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// "Face ID" en iPhone con cara; si no, "huella".
  static Future<String> nombre() async {
    if (kIsWeb) return 'huella';
    try {
      final tipos = await _auth.getAvailableBiometrics();
      if (tipos.contains(BiometricType.face)) {
        return defaultTargetPlatform == TargetPlatform.iOS ? 'Face ID' : 'reconocimiento facial';
      }
    } catch (_) {}
    return 'huella';
  }

  /// `true` si el usuario se identificó; cualquier error o cancelación es
  /// `false` y la app ofrece el PIN.
  static Future<bool> autenticar() async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(localizedReason: 'Desbloquea MAVfin', biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}
