import 'package:flutter/material.dart';

import '../../domain/rollups/estado_ritmo.dart';
import 'barra_ritmo.dart';
import 'tema.dart';

/// Tono de un chip o un aviso: el color nunca va solo, siempre con ícono y
/// palabra (`docs/rediseno/design-system/README.md`, Accesibilidad).
enum TonoEstado { exito, atencion, peligro, neutro }

TonoEstado tonoEstadoDeRitmo(TonoRitmo t) => switch (t) {
      TonoRitmo.vasBien => TonoEstado.exito,
      TonoRitmo.vasRapido => TonoEstado.atencion,
      TonoRitmo.tePasaste => TonoEstado.peligro,
    };

IconData iconoDeTono(TonoEstado t) => switch (t) {
      TonoEstado.exito => Icons.check_rounded,
      TonoEstado.atencion => Icons.speed_rounded,
      TonoEstado.peligro => Icons.error_outline_rounded,
      TonoEstado.neutro => Icons.remove_rounded,
    };

/// El estado en una o dos palabras ("Vas bien", "Vas un poco rápido",
/// "Te pasaste"), con ícono: así se reduce el texto (regla 1 · 6 · 12).
class ChipEstado extends StatelessWidget {
  final TonoEstado tono;
  final String texto;

  /// Dentro de la tarjeta héroe: fondo translúcido y colores `heroe-*`.
  final bool enHeroe;

  const ChipEstado({super.key, required this.tono, required this.texto, this.enHeroe = false});

  /// El chip del veredicto de ritmo, con su texto de siempre.
  factory ChipEstado.ritmo(TonoRitmo tono, {bool enHeroe = false}) =>
      ChipEstado(tono: tonoEstadoDeRitmo(tono), texto: etiquetaTonoRitmo(tono), enHeroe: enHeroe);

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final (fondo, color) = enHeroe
        ? (
            const Color(0x1AFFFFFF),
            switch (tono) {
              TonoEstado.exito => p.heroeExito,
              TonoEstado.atencion => p.heroeAtencion,
              TonoEstado.peligro => p.heroePeligro,
              TonoEstado.neutro => p.heroeTexto2,
            }
          )
        : switch (tono) {
            TonoEstado.exito => (p.exitoFondo, p.exitoTexto),
            TonoEstado.atencion => (p.atencionFondo, p.atencionTexto),
            TonoEstado.peligro => (p.peligroFondo, p.peligroTexto),
            TonoEstado.neutro => (p.superficieHundida, p.texto2),
          };
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Radios.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoDeTono(tono), size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.etiqueta.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
