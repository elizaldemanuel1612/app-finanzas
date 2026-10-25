import 'package:flutter/material.dart';

import '../ayuda/modelo_guia.dart';
import 'tema.dart';

/// El callout `.note` de `docs/app-finanzas-onboarding-v5.html:119-122`:
/// borde izquierdo de 4 px y una etiqueta en mayúsculas. Es la pieza más
/// repetida de la guía por temas, pero también sirve para la bienvenida
/// del onboarding.
///
/// El color brillante del [tono] se usa **solo** como borde (elemento
/// gráfico, umbral WCAG 3:1); la etiqueta siempre usa la variante
/// `…Texto` (4.5:1), regla de [tema.dart:11-14](../comun/tema.dart).
class NotaDestacada extends StatelessWidget {
  final String etiqueta;
  final String texto;
  final TonoNota tono;

  const NotaDestacada({
    super.key,
    required this.etiqueta,
    required this.texto,
    this.tono = TonoNota.info,
  });

  Color get _colorBorde => switch (tono) {
    TonoNota.info => ColoresApp.azul,
    TonoNota.ojo => ColoresApp.ambar,
    TonoNota.tip => ColoresApp.verde,
  };

  Color get _colorEtiqueta => switch (tono) {
    TonoNota.info => ColoresApp.azul,
    TonoNota.ojo => ColoresApp.ambarTexto,
    TonoNota.tip => ColoresApp.verdeTexto,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _colorBorde, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: theme.labelSmall?.copyWith(
              color: _colorEtiqueta,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(texto, style: theme.bodySmall),
        ],
      ),
    );
  }
}
