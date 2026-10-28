import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../dictado_web.dart';

JSFunction? get _constructor =>
    (globalContext['SpeechRecognition'] ?? globalContext['webkitSpeechRecognition']) as JSFunction?;

bool get disponible => _constructor != null;

DictadoWeb? iniciar() {
  final constructor = _constructor;
  if (constructor == null) return null;
  return _DictadoNavegador(constructor.callAsConstructor<web.SpeechRecognition>());
}

final class _DictadoNavegador implements DictadoWeb {
  final web.SpeechRecognition _reconocedor;
  final _estado = ValueNotifier(const EstadoDictadoWeb(escuchando: true));

  _DictadoNavegador(this._reconocedor) {
    _reconocedor
      ..lang = 'es-MX'
      ..continuous = false
      ..interimResults = true
      ..maxAlternatives = 1
      ..onresult = ((web.SpeechRecognitionEvent e) {
        final partes = StringBuffer();
        for (var i = 0; i < e.results.length; i++) {
          partes.write(e.results.item(i).item(0).transcript);
        }
        _cambiar(texto: partes.toString().trim());
      }).toJS
      ..onaudiostart = ((web.Event _) => _cambiar(evento: 'audio')).toJS
      ..onsoundstart = ((web.Event _) => _cambiar(evento: 'sonido')).toJS
      ..onspeechstart = ((web.Event _) => _cambiar(evento: 'voz')).toJS
      ..onerror = ((web.SpeechRecognitionErrorEvent e) {
        // `aborted` es nuestro propio cancelar/detener: no es un error.
        if (e.error == 'aborted') return;
        _cambiar(escuchando: false, error: e.error);
      }).toJS
      ..onend = ((web.Event _) {
        _limite?.cancel();
        _cambiar(escuchando: false);
      }).toJS;
    try {
      _reconocedor.start();
      _limite = Timer(DictadoWeb.limiteSinTexto, () {
        if (_estado.value.texto.isNotEmpty || !_estado.value.escuchando) return;
        _cambiar(escuchando: false, error: EstadoDictadoWeb.sinRespuesta);
        _cerrado = true;
        _reconocedor.abort();
      });
    } catch (_) {
      _estado.value = const EstadoDictadoWeb(error: 'service-not-allowed');
    }
  }

  bool _cerrado = false;
  Timer? _limite;

  void _cambiar({String? texto, bool? escuchando, String? error, String? evento}) {
    final actual = _estado.value;
    _poner(EstadoDictadoWeb(
      texto: texto ?? actual.texto,
      escuchando: escuchando ?? actual.escuchando,
      error: error ?? actual.error,
      eventos: evento == null ? actual.eventos : {...actual.eventos, evento},
    ));
  }

  void _poner(EstadoDictadoWeb nuevo) {
    if (!_cerrado) _estado.value = nuevo;
  }

  @override
  ValueListenable<EstadoDictadoWeb> get estado => _estado;

  @override
  void detener() => _reconocedor.stop();

  @override
  void cancelar() {
    _limite?.cancel();
    _cerrado = true;
    _reconocedor.abort();
  }
}
