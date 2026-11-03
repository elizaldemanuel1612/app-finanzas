import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../data/seguridad/candado.dart';
import '../../domain/seguridad/politica_bloqueo.dart';
import 'captura_pin.dart';

enum _Paso { actual, nuevo, confirmar }

/// Crear o cambiar el PIN (spec-app-finanzas-v2.md §7.3): se escribe dos
/// veces y, si se está cambiando, primero el actual.
class PantallaCrearPin extends StatefulWidget {
  final Candado candado;
  final VoidCallback alTerminar;

  /// Pide el PIN actual antes del nuevo (cambiar, no crear).
  final bool pedirActual;

  /// Qué decir arriba la primera vez (por qué se pide).
  final String? explicacion;

  const PantallaCrearPin({
    super.key,
    required this.candado,
    required this.alTerminar,
    this.pedirActual = false,
    this.explicacion,
  });

  @override
  State<PantallaCrearPin> createState() => _PantallaCrearPinState();
}

class _PantallaCrearPinState extends State<PantallaCrearPin> {
  late _Paso _paso = widget.pedirActual ? _Paso.actual : _Paso.nuevo;
  String? _nuevo;
  String? _error;

  Future<void> _alCompletar(String pin) async {
    switch (_paso) {
      case _Paso.actual:
        final bien = await widget.candado.probarPin(pin);
        setState(() {
          _error = bien ? null : 'Ese no es tu PIN actual.';
          if (bien) _paso = _Paso.nuevo;
        });
      case _Paso.nuevo:
        switch (validarPinNuevo(pin)) {
          case Falla(:final mensaje):
            setState(() => _error = mensaje);
          case Exito():
            setState(() {
              _nuevo = pin;
              _error = null;
              _paso = _Paso.confirmar;
            });
        }
      case _Paso.confirmar:
        if (pin != _nuevo) {
          setState(() {
            _error = 'No coinciden. Escríbelo otra vez.';
            _paso = _Paso.nuevo;
            _nuevo = null;
          });
          return;
        }
        await widget.candado.definirPin(pin);
        widget.alTerminar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (titulo, subtitulo) = switch (_paso) {
      _Paso.actual => ('Escribe tu PIN actual', null),
      _Paso.nuevo => (
          widget.pedirActual ? 'Escribe tu PIN nuevo' : 'Crea tu PIN de 6 números',
          widget.explicacion ?? 'Lo usarás si Face ID o tu huella fallan, y te lo pediremos una vez por semana.',
        ),
      _Paso.confirmar => ('Confírmalo', 'Escríbelo otra vez.'),
    };
    return Scaffold(
      appBar: widget.pedirActual ? AppBar(title: const Text('Cambiar PIN')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: CapturaPin(
              key: ValueKey(_paso),
              titulo: titulo,
              subtitulo: subtitulo,
              error: _error,
              alCompletar: _alCompletar,
            ),
          ),
        ),
      ),
    );
  }
}
