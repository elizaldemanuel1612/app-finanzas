import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../domain/modelos/categoria.dart';
import '../../domain/voz/parser_dictado.dart';
import '../../domain/voz/seleccion_locale.dart';
import '../comun/tema.dart';

/// Abre la hoja de dictado y regresa los gastos que el parser entendió del
/// audio, o `null` si la persona canceló sin decir nada útil.
///
/// addendum-v3-ajuste-y-ux.md §3.4: "Foto y voz viven dentro del mismo
/// teclado, no en menús aparte" — por eso esto es una hoja modal sobre
/// Pantalla Captura, no una pantalla nueva con su propia navegación.
Future<List<GastoDictado>?> mostrarHojaDictado(
  BuildContext context, {
  required List<Categoria> categorias,
}) {
  return showModalBottomSheet<List<GastoDictado>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HojaDictado(categorias: categorias),
  );
}

class _HojaDictado extends StatefulWidget {
  final List<Categoria> categorias;

  const _HojaDictado({required this.categorias});

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

  @override
  void initState() {
    super.initState();
    _inicializar();
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
    _speech.cancel();
    Navigator.of(context).pop(null);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
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
            if (_inicializando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              )
            else if (!_disponible)
              Column(
                children: [
                  const Text(
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
                    color: _escuchando ? Colors.white : ColoresApp.azul,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _escuchando ? 'Escuchando… toca para detener' : 'Toca para hablar de nuevo',
                style: const TextStyle(color: ColoresApp.medio, fontSize: 12, fontWeight: FontWeight.w600),
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
                Text(_error!, style: const TextStyle(color: ColoresApp.coralTexto, fontSize: 12)),
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
