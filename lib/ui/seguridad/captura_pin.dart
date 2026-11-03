import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/seguridad/politica_bloqueo.dart';
import '../comun/tema.dart';

/// Seis puntos y un teclado numérico, como el del iPhone. Al completar los
/// 6 dígitos llama a [alCompletar] y se vacía. También acepta el teclado
/// físico (computadora).
class CapturaPin extends StatefulWidget {
  final String titulo;
  final String? subtitulo;

  /// En coral, bajo los puntos (PIN incorrecto, no coinciden…).
  final String? error;
  final bool habilitado;
  final Future<void> Function(String pin) alCompletar;

  const CapturaPin({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.error,
    this.habilitado = true,
    required this.alCompletar,
  });

  @override
  State<CapturaPin> createState() => _CapturaPinState();
}

class _CapturaPinState extends State<CapturaPin> {
  var _digitos = '';
  bool _procesando = false;
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  Future<void> _tocar(String tecla) async {
    if (!widget.habilitado || _procesando) return;
    if (tecla == '⌫') {
      if (_digitos.isNotEmpty) setState(() => _digitos = _digitos.substring(0, _digitos.length - 1));
      return;
    }
    if (_digitos.length >= largoPin) return;
    setState(() => _digitos += tecla);
    if (_digitos.length < largoPin) return;
    _procesando = true;
    final pin = _digitos;
    await widget.alCompletar(pin);
    if (!mounted) return;
    setState(() {
      _digitos = '';
      _procesando = false;
    });
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent evento) {
    if (evento is! KeyDownEvent) return KeyEventResult.ignored;
    final caracter = evento.character;
    if (caracter != null && RegExp(r'^\d$').hasMatch(caracter)) {
      _tocar(caracter);
      return KeyEventResult.handled;
    }
    if (evento.logicalKey == LogicalKeyboardKey.backspace) {
      _tocar('⌫');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: _tecla,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.titulo, textAlign: TextAlign.center, style: textos.titleMedium),
          if (widget.subtitulo != null) ...[
            const SizedBox(height: 6),
            Text(widget.subtitulo!, textAlign: TextAlign.center, style: textos.bodySmall),
          ],
          const SizedBox(height: 20),
          Semantics(
            label: '${_digitos.length} de $largoPin dígitos',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < largoPin; i++)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _digitos.length ? ColoresApp.azul : Colors.transparent,
                      border: Border.all(color: ColoresApp.azul, width: 1.5),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: widget.error == null
                  ? null
                  : Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      style: textos.bodySmall?.copyWith(color: ColoresApp.coralTexto),
                    ),
            ),
          ),
          for (final fila in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final t in fila) _Tecla(texto: t, habilitada: widget.habilitado, alTocar: _tocar)],
            ),
        ],
      ),
    );
  }
}

class _Tecla extends StatelessWidget {
  final String texto;
  final bool habilitada;
  final void Function(String) alTocar;

  const _Tecla({required this.texto, required this.habilitada, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    if (texto.isEmpty) return const SizedBox(width: 88, height: 76);
    final borrar = texto == '⌫';
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 76,
        height: 64,
        child: Material(
          color: borrar ? Colors.transparent : ColoresApp.azulSuave,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: habilitada ? () => alTocar(texto) : null,
            child: Center(
              child: borrar
                  ? Icon(Icons.backspace_outlined, color: ColoresApp.tinta, semanticLabel: 'Borrar')
                  : Text(texto, style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
        ),
      ),
    );
  }
}
