import 'package:flutter/foundation.dart';

import 'dictado_web/dictado_web_nativo.dart'
    if (dart.library.js_interop) 'dictado_web/dictado_web_navegador.dart' as impl;

/// Lo que va escuchando el reconocimiento de voz del navegador.
@immutable
final class EstadoDictadoWeb {
  final String texto;
  final bool escuchando;

  /// Código del navegador (`not-allowed`, `service-not-allowed`,
  /// `no-speech`, `network`, `audio-capture`…) o `null` si no hubo error.
  final String? error;

  const EstadoDictadoWeb({this.texto = '', this.escuchando = false, this.error});

  /// El navegador no deja usar el micrófono o el servicio de dictado: no
  /// tiene caso reintentar, toca el respaldo del teclado.
  bool get sinPermiso => error == 'not-allowed' || error == 'service-not-allowed';
}

/// Dictado con el micrófono directo en la web (`SpeechRecognition` /
/// `webkitSpeechRecognition` de Safari), sin pasar por el teclado
/// (2026-10-28). No usa `speech_to_text`: su versión web inicializa y
/// consulta idiomas antes de escuchar, así que el `start()` ya no salía del
/// toque del usuario y Safari en iPhone pedía permiso, se trababa y fallaba.
/// Aquí [iniciar] se llama **directo desde el toque**, sin esperas antes.
abstract interface class DictadoWeb {
  /// `false` fuera de la web o si el navegador no trae reconocimiento.
  static bool get disponible => impl.disponible;

  /// Empieza a escuchar en es-MX; `null` si no hay reconocimiento.
  static DictadoWeb? iniciar() => impl.iniciar();

  ValueListenable<EstadoDictadoWeb> get estado;

  /// Deja de escuchar y se queda con lo que ya entendió.
  void detener();

  /// Deja de escuchar y descarta.
  void cancelar();
}
