// Generado a mano a partir de android/app/google-services.json — el
// equivalente de lo que produciría `flutterfire configure`, sin necesitar
// el CLI de Firebase autenticado (ver memoria del proyecto:
// firebase-cli-sin-login-usar-consola-web). El bloque iOS sale de
// ios/Runner/GoogleService-Info.plist (app registrada en Firebase con el
// bundle ID unificado com.manuelelizalde.appfinanzas). El bloque web sale
// de `firebase apps:sdkconfig WEB` (app web "MAVfin").
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
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

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCjVGekh_XYPIEOmcEVelwRrb6MOq9UZw8',
    appId: '1:549374317068:ios:1cd15f6a3ef15a90055429',
    messagingSenderId: '549374317068',
    projectId: 'app-finanzas-27e41',
    storageBucket: 'app-finanzas-27e41.firebasestorage.app',
    iosClientId:
        '549374317068-sf9bfi3tq20d17ejmu7vaskom05oa4mu.apps.googleusercontent.com',
    iosBundleId: 'com.manuelelizalde.appfinanzas',
  );

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyC_k520RPjz8--CH4ti4yL4w2fqPSnef20',
    appId: '1:549374317068:web:80dc0d598d0e0acf055429',
    messagingSenderId: '549374317068',
    projectId: 'app-finanzas-27e41',
    authDomain: 'app-finanzas-27e41.firebaseapp.com',
    storageBucket: 'app-finanzas-27e41.firebasestorage.app',
    measurementId: 'G-LS96HN0N3N',
  );
}
