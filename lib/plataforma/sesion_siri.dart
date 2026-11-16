import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Qué cuenta tiene la sesión abierta en este iPhone, para que Siri sepa
/// dónde registrar sin abrir la app (spec-app-finanzas-v2.md §5.6.3). Es
/// solo el `uid` (el nombre de la carpeta `usuarios/<uid>/`), nada de
/// datos; se olvida al cerrar sesión o eliminar la cuenta.
abstract final class SesionSiri {
  static const _clave = 'siri.cuenta';

  static Future<void> recordar(String uid) async {
    if (kIsWeb) return;
    try {
      await SharedPreferencesAsync().setString(_clave, uid);
    } catch (_) {
      // Sin preferencias, Siri dice "abre la app": nada más falla.
    }
  }

  static Future<void> olvidar() async {
    if (kIsWeb) return;
    try {
      await SharedPreferencesAsync().remove(_clave);
    } catch (_) {}
  }

  static Future<String?> cuenta() async {
    try {
      return await SharedPreferencesAsync().getString(_clave);
    } catch (_) {
      return null;
    }
  }
}
