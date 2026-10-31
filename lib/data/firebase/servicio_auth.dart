import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Envuelve Google Sign-In + Firebase Auth. Vive en data/firebase/ porque
/// domain/ no puede tocar Flutter ni Firebase (paquete-construccion-final.md
/// §2) — esto es infraestructura, no lógica de negocio.
class ServicioAuth {
  static const _serverClientId =
      '549374317068-oaevgsoluq8k6fpm52h5amukdstccf0g.apps.googleusercontent.com';

  static bool _googleSignInInicializado = false;

  /// Permiso para la carpeta privada de la app en el Google Drive del
  /// usuario, donde vive su respaldo (spec-app-finanzas-v2.md §4.2.1). No
  /// da acceso a ningún otro archivo de su Drive.
  static const alcanceDrive = 'https://www.googleapis.com/auth/drive.appdata';

  /// En la web, Firebase entrega el token de Drive solo al iniciar sesión o
  /// al volver a autenticarse con ventana; dura una hora y no se guarda en
  /// disco.
  static String? _tokenDriveWeb;
  static DateTime? _venceTokenDriveWeb;

  static Future<void> inicializar() async {
    // En la web se entra con la ventana emergente de Firebase Auth, sin
    // google_sign_in (spec-app-finanzas-v2.md §4.2.2).
    if (kIsWeb || _googleSignInInicializado) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleSignInInicializado = true;
  }

  Stream<User?> get cambiosDeUsuario => FirebaseAuth.instance.authStateChanges();

  User? get usuarioActual => FirebaseAuth.instance.currentUser;

  /// Abre el selector de cuentas de Google y entra a Firebase con esa
  /// cuenta. Lanza [GoogleSignInException] si el usuario cancela.
  Future<UserCredential> iniciarSesionConGoogle() async {
    if (kIsWeb) {
      // El permiso de Drive se pide aquí mismo para poder ofrecer restaurar
      // el respaldo en cuanto entra (§4.2.2); Google deja desmarcarlo.
      final credencial = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider()
          ..addScope(alcanceDrive)
          ..setCustomParameters({'prompt': 'select_account'}),
      );
      _guardarTokenDriveWeb(credencial);
      return credencial;
    }
    final cuenta = await GoogleSignIn.instance.authenticate();
    final idToken = cuenta.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google no regresó un idToken para ${cuenta.email}.');
    }
    final credencial = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credencial);
  }

  /// Token de acceso para el respaldo en Drive. Con [interactivo] puede
  /// mostrar la ventana de permiso de Google; en la web debe llamarse
  /// directo desde un toque, sin esperas antes (o el navegador bloquea la
  /// ventana). Sin [interactivo] devuelve `null` si haría falta preguntar.
  Future<String?> tokenDrive({required bool interactivo}) async {
    if (kIsWeb) {
      final vence = _venceTokenDriveWeb;
      if (_tokenDriveWeb != null && vence != null && DateTime.now().isBefore(vence)) {
        return _tokenDriveWeb;
      }
      final usuario = FirebaseAuth.instance.currentUser;
      if (!interactivo || usuario == null) return null;
      final credencial = await usuario.reauthenticateWithPopup(
        GoogleAuthProvider()
          ..addScope(alcanceDrive)
          ..setCustomParameters({if (usuario.email != null) 'login_hint': usuario.email!}),
      );
      _guardarTokenDriveWeb(credencial);
      return _tokenDriveWeb;
    }
    final cliente = GoogleSignIn.instance.authorizationClient;
    final autorizacion = await cliente.authorizationForScopes(const [alcanceDrive]) ??
        (interactivo ? await cliente.authorizeScopes(const [alcanceDrive]) : null);
    return autorizacion?.accessToken;
  }

  /// Drive rechazó [token]: que no se vuelva a usar.
  Future<void> invalidarTokenDrive(String token) async {
    if (kIsWeb) {
      if (_tokenDriveWeb == token) _tokenDriveWeb = null;
      return;
    }
    await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: token);
  }

  static void _guardarTokenDriveWeb(UserCredential credencial) {
    final token = credencial.credential?.accessToken;
    if (token == null) return;
    _tokenDriveWeb = token;
    // Google los emite por una hora; margen para no usar uno a punto de vencer.
    _venceTokenDriveWeb = DateTime.now().add(const Duration(minutes: 55));
  }

  Future<void> cerrarSesion() async {
    _tokenDriveWeb = null;
    if (!kIsWeb) await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// En la web, confirma la identidad con la ventana de Google **antes** de
  /// eliminar: deja la sesión reciente (`delete()` ya no pide reautenticar)
  /// y un token de Drive vigente para borrar la copia. Debe llamarse directo
  /// desde el toque de la última confirmación: tras cualquier espera, Safari
  /// bloquea la ventana y la cuenta no se podía eliminar (2026-10-30). En
  /// móvil no hace nada; [eliminarCuenta] reautentica si hace falta.
  Future<void> reautenticarParaEliminar() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (!kIsWeb || usuario == null) return;
    final credencial = await usuario.reauthenticateWithPopup(
      GoogleAuthProvider()
        ..addScope(alcanceDrive)
        ..setCustomParameters({if (usuario.email != null) 'login_hint': usuario.email!}),
    );
    _guardarTokenDriveWeb(credencial);
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
      if (kIsWeb) {
        await usuario.reauthenticateWithPopup(GoogleAuthProvider());
        await usuario.delete();
        return;
      }
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
