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
}
