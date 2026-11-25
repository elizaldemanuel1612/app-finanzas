import 'dart:js_interop';

import 'package:web/web.dart' as web;

void alCambiarEnOtraPestana(void Function() accion) {
  web.window.addEventListener('storage', ((web.Event _) => accion()).toJS);
}
