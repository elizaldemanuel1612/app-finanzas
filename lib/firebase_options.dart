// Generado a mano a partir de android/app/google-services.json — el
// equivalente de lo que produciría `flutterfire configure`, sin necesitar
// el CLI de Firebase autenticado (ver memoria del proyecto:
// firebase-cli-sin-login-usar-consola-web). Solo Android está configurado
// por ahora; iOS se agrega cuando haya una Mac para compilarlo.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions no está configurado para web todavía.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para iOS todavía '
          '— falta registrar la app en Firebase y compilar desde una Mac.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soporta esta plataforma: '
          '$defaultTargetPlatform.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyD39Mb6LCA7Ltc-wq218W0n-BlSp-jPwJA',
    appId: '1:549374317068:android:5a0bb4fe2fc4efe9055429',
    messagingSenderId: '549374317068',
    projectId: 'app-finanzas-27e41',
    storageBucket: 'app-finanzas-27e41.firebasestorage.app',
  );
}
