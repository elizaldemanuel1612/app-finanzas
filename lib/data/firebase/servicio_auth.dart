import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Envuelve Google Sign-In + Firebase Auth. Vive en data/firebase/ porque
/// domain/ no puede tocar Flutter ni Firebase (paquete-construccion-final.md
/// §2) — esto es infraestructura, no lógica de negocio.
class ServicioAuth {
  static const _serverClientId =
      '549374317068-oaevgsoluq8k6fpm52h5amukdstccf0g.apps.googleusercontent.com';

  static bool _googleSignInInicializado = false;

  static Future<void> inicializar() async {
    if (_googleSignInInicializado) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleSignInInicializado = true;
  }

  Stream<User?> get cambiosDeUsuario => FirebaseAuth.instance.authStateChanges();

  User? get usuarioActual => FirebaseAuth.instance.currentUser;

  /// Abre el selector de cuentas de Google y entra a Firebase con esa
  /// cuenta. Lanza [GoogleSignInException] si el usuario cancela.
  Future<UserCredential> iniciarSesionConGoogle() async {
    final cuenta = await GoogleSignIn.instance.authenticate();
    final idToken = cuenta.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google no regresó un idToken para ${cuenta.email}.');
    }
    final credencial = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credencial);
  }

  Future<void> cerrarSesion() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// Borra la cuenta de Firebase Auth — el primer paso del flujo de
  /// "Eliminar cuenta" de Ajustes (Fase 6, Bloque 2.4). `currentUser.delete()`
  /// falla con `requires-recent-login` para sesiones de más de ~5 minutos
  /// (casi todas): se reautentica con Google solo cuando hace falta, en vez
  /// de forzar el selector de cuentas siempre, y se reintenta una vez.
  ///
  /// Quien llama debe borrar los datos locales (`AlmacenLocal.borrarTodo`)
  /// **después** de que esto termine sin lanzar, nunca antes: si `delete()`
  /// falla, los datos locales deben seguir intactos para poder reintentar.
  Future<void> eliminarCuenta() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    try {
      await usuario.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      final cuenta = await GoogleSignIn.instance.authenticate();
      final idToken = cuenta.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google no regresó un idToken para ${cuenta.email}.');
      }
      final credencial = GoogleAuthProvider.credential(idToken: idToken);
      await usuario.reauthenticateWithCredential(credencial);
      await usuario.delete();
    }
  }
}
