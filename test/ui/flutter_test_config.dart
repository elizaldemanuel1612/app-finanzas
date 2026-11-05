import 'dart:async';

import 'package:app_finanzas/ui/comun/guia_rapida.dart';

/// Para todas las pruebas de `test/ui/`: las guías rápidas de primera vez
/// tapan la pantalla que se revisa, así que se apagan aquí; la suya las
/// enciende de nuevo.
Future<void> testExecutable(FutureOr<void> Function() pruebas) async {
  guiasRapidasActivas = false;
  await pruebas();
}
