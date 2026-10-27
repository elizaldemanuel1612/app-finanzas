import 'package:flutter/material.dart';

import 'formato_fecha.dart';
import 'tema.dart';

/// Selector de fecha compartido por los tres flujos de captura (manual,
/// dictado, ticket): chips rápidos para "Hoy" y "Ayer", y un calendario
/// (`showDatePicker`, ya en español gracias a `main.dart`) para cualquier
/// otro día dentro de [primeraFecha]..[ultimaFecha].
///
/// Los chips "Hoy"/"Ayer" solo se dibujan si su fecha cae dentro del rango
/// — en edición de un gasto viejo, "Hoy" puede quedar fuera del ciclo y no
/// debe aparecer como opción.
class SelectorFecha extends StatelessWidget {
  final DateTime seleccionada;
  final ValueChanged<DateTime> onCambio;
  final DateTime primeraFecha;
  final DateTime ultimaFecha;
  final String etiqueta;

  const SelectorFecha({
    super.key,
    required this.seleccionada,
    required this.onCambio,
    required this.primeraFecha,
    required this.ultimaFecha,
    this.etiqueta = '¿Cuándo fue?',
  });

  static DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

  bool _dentroDelRango(DateTime f) {
    final dia = _soloFecha(f);
    return !dia.isBefore(primeraFecha) && !dia.isAfter(ultimaFecha);
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _elegirOtroDia(BuildContext context) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _soloFecha(seleccionada),
      firstDate: primeraFecha,
      lastDate: ultimaFecha,
      helpText: 'Elige el día',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (elegida != null) onCambio(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = _soloFecha(DateTime.now());
    final ayer = hoy.subtract(const Duration(days: 1));
    final esOtroDia = !_mismoDia(seleccionada, hoy) && !_mismoDia(seleccionada, ayer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextStyle(color: ColoresApp.medio)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_dentroDelRango(hoy))
              ChoiceChip(
                label: const Text('Hoy'),
                selected: _mismoDia(seleccionada, hoy),
                onSelected: (_) => onCambio(hoy),
              ),
            if (_dentroDelRango(ayer))
              ChoiceChip(
                label: const Text('Ayer'),
                selected: _mismoDia(seleccionada, ayer),
                onSelected: (_) => onCambio(ayer),
              ),
            ChoiceChip(
              label: Text(esOtroDia ? fechaCorta(seleccionada) : '📅 Otro día'),
              selected: esOtroDia,
              onSelected: (_) => _elegirOtroDia(context),
            ),
          ],
        ),
      ],
    );
  }
}
