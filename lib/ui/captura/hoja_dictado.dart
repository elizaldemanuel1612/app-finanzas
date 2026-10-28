import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../domain/modelos/categoria.dart';
import '../../domain/voz/parser_dictado.dart';
import '../../domain/voz/seleccion_locale.dart';
import '../../plataforma/dictado_web.dart';
import '../comun/tema.dart';

/// Abre la hoja de dictado y regresa los gastos que el parser entendió del
/// audio, o `null` si la persona canceló sin decir nada útil.
///
/// addendum-v3-ajuste-y-ux.md §3.4: "Foto y voz viven dentro del mismo
/// teclado, no en menús aparte" — por eso esto es una hoja modal sobre
/// Pantalla Captura, no una pantalla nueva con su propia navegación.
///
/// En la web, [dictadoWeb] ya viene escuchando: se arranca en el toque del
/// botón, antes de cualquier espera, porque Safari solo deja abrir el
/// micrófono directo desde un toque. Si es `null` (o el navegador no da
/// permiso), la hoja cae al dictado del teclado.
Future<List<GastoDictado>?> mostrarHojaDictado(
  BuildContext context, {
  required List<Categoria> categorias,
  DictadoWeb? dictadoWeb,
}) {
  return showModalBottomSheet<List<GastoDictado>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HojaDictado(categorias: categorias, dictadoWeb: dictadoWeb),
  );
}

class _HojaDictado extends StatefulWidget {
  final List<Categoria> categorias;
  final DictadoWeb? dictadoWeb;

  const _HojaDictado({required this.categorias, this.dictadoWeb});

  @override
  State<_HojaDictado> createState() => _HojaDictadoState();
}

class _HojaDictadoState extends State<_HojaDictado> {
  final _speech = stt.SpeechToText();
  bool _disponible = false;
  bool _escuchando = false;
  bool _inicializando = true;
  String _texto = '';
  String? _error;

  /// En la web se escucha con el reconocimiento del navegador
  /// ([DictadoWeb]); si no hay o no da permiso, se dicta con el micrófono
  /// del teclado sobre este campo de texto.
  final _campoWeb = TextEditingController();
  DictadoWeb? _web;
  bool _usado = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _inicializando = false;
      _escucharWeb(widget.dictadoWeb);
      return;
    }
    _inicializar();
  }

  void _escucharWeb(DictadoWeb? dictado) {
    _web?.estado.removeListener(_alCambiarWeb);
    _web = dictado;
    dictado?.estado.addListener(_alCambiarWeb);
  }

  /// Al terminar de escuchar (Safari corta solo tras una pausa) se usa lo
  /// que entendió sin pedir otro toque: el gasto llega a la captura para
  /// confirmarlo con "Registrar".
  void _alCambiarWeb() {
    if (!mounted) return;
    final estado = _web!.estado.value;
    setState(() {
      _texto = estado.texto;
      if (estado.escuchando) _campoWeb.text = estado.texto;
    });
    if (!estado.escuchando && estado.error == null && !_usado) {
      if (parsearDictado(estado.texto, categorias: widget.categorias).isNotEmpty) {
        _usado = true;
        _usarTexto();
      }
    }
  }

  /// Volver a escuchar: se llama directo desde el toque del micrófono.
  void _reintentarWeb() {
    _web?.cancelar();
    _usado = false;
    _escucharWeb(DictadoWeb.iniciar());
    setState(() => _texto = '');
  }

  Future<void> _inicializar() async {
    final disponible = await _speech.initialize(
      onStatus: (estado) {
        if ((estado == 'done' || estado == 'notListening') && mounted) {
          setState(() => _escuchando = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _error = 'No se pudo escuchar. Intenta de nuevo.');
      },
    );
    if (!mounted) return;
    setState(() {
      _disponible = disponible;
      _inicializando = false;
    });
    if (disponible) _empezarAEscuchar();
  }

  Future<void> _empezarAEscuchar() async {
    setState(() {
      _escuchando = true;
      _texto = '';
      _error = null;
    });
    final locales = await _speech.locales();
    final localeId = seleccionarLocaleDictado([for (final l in locales) l.localeId]);
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        setState(() => _texto = r.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _detener() {
    _speech.stop();
    setState(() => _escuchando = false);
  }

  void _usarTexto() {
    final gastos = parsearDictado(_texto, categorias: widget.categorias);
    Navigator.of(context).pop(gastos);
  }

  void _cancelar() {
    if (!kIsWeb) _speech.cancel();
    Navigator.of(context).pop(null);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _web?.estado.removeListener(_alCambiarWeb);
      _web?.cancelar();
    } else {
      _speech.stop();
    }
    _campoWeb.dispose();
    super.dispose();
  }

  List<Widget> _contenidoWeb(BuildContext context) {
    final estado = _web?.estado.value;
    if (estado == null || estado.sinPermiso) return _contenidoTeclado(context, sinPermiso: estado != null);
    final textos = Theme.of(context).textTheme;
    final escuchando = estado.escuchando;
    final aviso = switch (estado.error) {
      null when !escuchando && _texto.isNotEmpty => 'No entendí un gasto. Toca el micrófono para repetirlo.',
      null => null,
      'no-speech' => 'No te escuché. Toca el micrófono para intentar de nuevo.',
      'audio-capture' => 'No encontré el micrófono. Toca para intentar de nuevo.',
      'network' => 'El dictado necesita internet. Revisa tu conexión.',
      final codigo => 'No se pudo escuchar ($codigo). Toca para intentar de nuevo.',
    };
    return [
      GestureDetector(
        onTap: escuchando ? _web!.detener : _reintentarWeb,
        child: CircleAvatar(
          radius: 36,
          backgroundColor: escuchando ? ColoresApp.azul : ColoresApp.azulSuave,
          child: Icon(
            escuchando ? Icons.mic : Icons.mic_none,
            color: escuchando ? ColoresApp.sobreAzul : ColoresApp.azul,
            size: 32,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        escuchando ? 'Escuchando… di tu gasto' : 'Toca el micrófono para hablar',
        style: textos.labelSmall?.copyWith(color: ColoresApp.medio),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _campoWeb,
        minLines: 1,
        maxLines: 3,
        readOnly: escuchando,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Ej. "480 de súper con tarjeta"'),
        onChanged: (texto) => setState(() => _texto = texto),
        onSubmitted: (_) {
          if (_texto.trim().isNotEmpty) _usarTexto();
        },
      ),
      if (aviso != null) ...[
        const SizedBox(height: 8),
        Text(aviso, textAlign: TextAlign.center, style: textos.bodySmall?.copyWith(color: ColoresApp.coralTexto)),
      ],
    ];
  }

  List<Widget> _contenidoTeclado(BuildContext context, {required bool sinPermiso}) {
    final textos = Theme.of(context).textTheme;
    return [
      CircleAvatar(
        radius: 30,
        backgroundColor: ColoresApp.azulSuave,
        child: Icon(Icons.keyboard_voice_outlined, color: ColoresApp.azul, size: 28),
      ),
      const SizedBox(height: 12),
      Text(
        'Toca el micrófono de tu teclado y di tu gasto',
        textAlign: TextAlign.center,
        style: textos.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        sinPermiso
            ? 'Tu navegador no dejó usar el micrófono aquí. Puedes dictar con el del teclado '
                'o permitirlo en Ajustes del teléfono › Safari › Micrófono.'
            : 'También puedes escribirlo. Si no ves el micrófono, actívalo en Ajustes del '
                'teléfono › General › Teclado › Dictado.',
        textAlign: TextAlign.center,
        style: textos.bodySmall,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _campoWeb,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Ej. "480 de súper con tarjeta"'),
        onChanged: (texto) => setState(() => _texto = texto),
        onSubmitted: (_) {
          if (_texto.trim().isNotEmpty) _usarTexto();
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kIsWeb) ..._contenidoWeb(context),
            if (kIsWeb) const SizedBox(height: 20),
            if (kIsWeb)
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _cancelar, child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _texto.trim().isEmpty ? null : _usarTexto,
                      child: const Text('Usar esto'),
                    ),
                  ),
                ],
              )
            else if (_inicializando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              )
            else if (!_disponible)
              Column(
                children: [
                  Text(
                    'No se pudo activar el micrófono. Si ya lo negaste antes, '
                    've a Ajustes del sistema › Permisos › Micrófono y actívalo '
                    'para MAVfin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ColoresApp.coralTexto),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cerrar')),
                ],
              )
            else ...[
              GestureDetector(
                onTap: _escuchando ? _detener : _empezarAEscuchar,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: _escuchando ? ColoresApp.azul : ColoresApp.azulSuave,
                  child: Icon(
                    _escuchando ? Icons.mic : Icons.mic_none,
                    color: _escuchando ? ColoresApp.sobreAzul : ColoresApp.azul,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _escuchando ? 'Escuchando… toca para detener' : 'Toca para hablar de nuevo',
                style: TextStyle(color: ColoresApp.medio, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ColoresApp.fondo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _texto.isEmpty ? 'Ej. "480 de súper con tarjeta"' : _texto,
                  style: TextStyle(
                    fontSize: 15,
                    color: _texto.isEmpty ? ColoresApp.medio : ColoresApp.tinta,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: ColoresApp.coralTexto, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _cancelar, child: const Text('Cancelar')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _texto.trim().isEmpty ? null : _usarTexto,
                      child: const Text('Usar esto'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
