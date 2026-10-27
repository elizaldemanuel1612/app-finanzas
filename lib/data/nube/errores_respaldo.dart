import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'respaldo_drive.dart';

/// Qué decirle al usuario cuando falla el respaldo en Drive (spec
/// §4.2.1). Antes todo error decía "Revisa tu internet", aunque la causa
/// fuera una ventana bloqueada o un permiso negado. Cada mensaje cierra
/// con un código corto para poder diagnosticarlo a distancia.
String describirErrorRespaldo(Object error) {
  return switch (error) {
    FirebaseAuthException(code: 'popup-blocked') =>
      'El navegador bloqueó la ventana de Google. Toca el botón otra vez; si sigue, '
          'permite ventanas emergentes (Ajustes del iPhone → Safari → Bloquear ventanas) '
          'o ábrela desde Safari en vez del ícono de inicio. (popup-blocked)',
    FirebaseAuthException(code: 'popup-closed-by-user' || 'cancelled-popup-request') =>
      'La ventana de Google se cerró antes de terminar. Intenta de nuevo y acepta el '
          'permiso de Google Drive. (${error.code})',
    FirebaseAuthException(code: 'user-mismatch') =>
      'Elegiste otra cuenta de Google. Usa la misma con la que entraste. (user-mismatch)',
    FirebaseAuthException(code: 'network-request-failed') =>
      'Sin conexión. Revisa tu internet e intenta de nuevo. (network-request-failed)',
    FirebaseAuthException(:final code) => 'Google no dio el permiso de Drive. Intenta de nuevo. ($code)',
    GoogleSignInException(code: GoogleSignInExceptionCode.canceled) =>
      'Cancelaste el permiso de Google Drive. Sin él no se puede guardar la copia. (canceled)',
    GoogleSignInException(:final code) => 'Google no dio el permiso de Drive. Intenta de nuevo. (${code.name})',
    ErrorDrive(codigo: 403, :final detalle)
        when detalle.contains('accessNotConfigured') || detalle.contains('SERVICE_DISABLED') =>
      'La API de Google Drive no está habilitada en el proyecto, o aún se está '
          'activando (puede tardar unos minutos). (drive-403-api)',
    ErrorDrive(codigo: 403, :final detalle) when detalle.contains('insufficient') =>
      'Falta el permiso de Google Drive. Intenta de nuevo y deja marcada la casilla de '
          'Drive en la ventana de Google. (drive-403-permiso)',
    ErrorDrive(codigo: 401) || StateError() =>
      'Google no dio el permiso de Drive. Intenta de nuevo y acéptalo en la ventana de '
          'Google. (drive-401)',
    ErrorDrive(:final codigo) => 'Google Drive respondió con un error. Intenta más tarde. (drive-$codigo)',
    http.ClientException() => 'Sin conexión con Google Drive. Revisa tu internet e intenta de nuevo. (red)',
    _ => 'No se pudo conectar con tu Google Drive. Intenta de nuevo. (${error.runtimeType})',
  };
}
