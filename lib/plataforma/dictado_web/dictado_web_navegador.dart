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
        _poner(EstadoDictadoWeb(
          texto: partes.toString().trim(),
          escuchando: _estado.value.escuchando,
          error: _estado.value.error,
        ));
      }).toJS
      ..onerror = ((web.SpeechRecognitionErrorEvent e) {
        // `aborted` es nuestro propio cancelar/detener: no es un error.
        if (e.error == 'aborted') return;
        _poner(EstadoDictadoWeb(texto: _estado.value.texto, escuchando: false, error: e.error));
      }).toJS
      ..onend = ((web.Event _) {
        _poner(EstadoDictadoWeb(texto: _estado.value.texto, error: _estado.value.error));
      }).toJS;
    try {
      _reconocedor.start();
    } catch (_) {
      _estado.value = const EstadoDictadoWeb(error: 'service-not-allowed');
    }
  }

  bool _cerrado = false;

  void _poner(EstadoDictadoWeb nuevo) {
    if (!_cerrado) _estado.value = nuevo;
  }

  @override
  ValueListenable<EstadoDictadoWeb> get estado => _estado;

  @override
  void detener() => _reconocedor.stop();

  @override
  void cancelar() {
    _cerrado = true;
    _reconocedor.abort();
  }
}
