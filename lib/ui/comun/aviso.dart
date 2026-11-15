import 'package:flutter/material.dart';

import 'chip_estado.dart';
import 'tema.dart';

/// Banner de aviso (`docs/rediseno/design-system/componentes/Aviso.md`):
/// qué pasa en una línea (≤ 6 palabras) y su salida concreta. El tono va en
/// el fondo y el ícono; el texto se queda en `texto`. Máximo uno por
/// pantalla.
class Aviso extends StatelessWidget {
  final TonoEstado tono;
  final String titulo;

  /// Apoyo opcional, ≤ 12 palabras.
  final String? apoyo;

  /// La salida: texto del enlace y qué hace.
  final String? accion;
  final VoidCallback? onAccion;

  /// Ícono propio (por omisión, el del tono; `info` usa un candado o una i).
  final IconData? icono;

  /// Info en vez de los tonos de estado (ciclo cerrado).
  final bool info;

  const Aviso({
    super.key,
    required this.tono,
    required this.titulo,
    this.apoyo,
    this.accion,
    this.onAccion,
    this.icono,
  }) : info = false;

  const Aviso.info({super.key, required this.titulo, this.apoyo, this.accion, this.onAccion, this.icono})
      : tono = TonoEstado.neutro,
        info = true;

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final (fondo, colorIcono) = info
        ? (p.infoFondo, p.infoTexto)
        : switch (tono) {
            TonoEstado.exito => (p.exitoFondo, p.exitoTexto),
            TonoEstado.atencion => (p.atencionFondo, p.atencionTexto),
            TonoEstado.peligro => (p.peligroFondo, p.peligroTexto),
            TonoEstado.neutro => (p.superficieHundida, p.texto2),
          };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Radios.m)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icono ?? (info ? Icons.info_outline_rounded : iconoDeTono(tono)), size: 20, color: colorIcono),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: textos.cuerpoFuerte),
                  if (apoyo != null) Text(apoyo!, style: textos.etiqueta.copyWith(color: p.texto)),
                  if (accion != null && onAccion != null)
                    InkWell(
                      onTap: onAccion,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              accion!,
                              style: textos.cuerpoFuerte.copyWith(decoration: TextDecoration.underline),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
