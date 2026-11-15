import 'package:flutter/material.dart';

import 'tema.dart';

/// El renglón de lista estándar (`docs/rediseno/design-system/componentes/Renglon.md`):
/// emoji o ícono en círculo, título, subtítulo, monto a la derecha y
/// chevron solo si abre algo. Alto mínimo 60. A más de 1.6× de texto, el
/// monto baja debajo del título en vez de cortarse.
///
/// Los montos de gasto van en `texto`, no en rojo: gastar no es un error.
class RenglonApp extends StatelessWidget {
  /// Emoji de la categoría o cuenta (dentro de un círculo hundido).
  final String? emoji;

  /// Ícono, si no hay emoji.
  final IconData? icono;

  /// Fondo y color del círculo del ícono; por omisión, superficie hundida.
  final Color? fondoIcono;
  final Color? colorIcono;

  /// Ícono en cuadro redondeado de color (renglones de Ajustes, como en las
  /// listas de configuración de iOS) en vez del círculo.
  final bool iconoCuadrado;

  final String titulo;
  final String? subtitulo;

  /// Monto (o dato corto) a la derecha, en `cuerpo-fuerte`.
  final String? monto;
  final Color? colorMonto;

  /// Debajo del título y el monto: una barra de ritmo, una frase.
  final Widget? abajo;

  /// Widget a la derecha en lugar del monto (un chip, un switch).
  final Widget? derecha;

  final VoidCallback? onTap;

  /// Para lectores de pantalla, si el texto visible no basta.
  final String? etiquetaSemantica;

  const RenglonApp({
    super.key,
    this.emoji,
    this.icono,
    this.fondoIcono,
    this.colorIcono,
    this.iconoCuadrado = false,
    required this.titulo,
    this.subtitulo,
    this.monto,
    this.colorMonto,
    this.abajo,
    this.derecha,
    this.onTap,
    this.etiquetaSemantica,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final escala = MediaQuery.textScalerOf(context).scale(1);
    final apilado = escala > 1.6;

    Widget? lider;
    if (emoji != null || icono != null) {
      final lado = iconoCuadrado ? 32.0 : 40.0;
      lider = Container(
        width: lado,
        height: lado,
        alignment: Alignment.center,
        decoration: iconoCuadrado
            ? BoxDecoration(color: fondoIcono ?? p.superficieHundida, borderRadius: BorderRadius.circular(9))
            : BoxDecoration(color: fondoIcono ?? p.superficieHundida, shape: BoxShape.circle),
        child: emoji != null
            ? ExcludeSemantics(child: Text(emoji!, style: textos.cuerpo, textScaler: TextScaler.noScaling))
            : Icon(icono, size: iconoCuadrado ? 19 : 20, color: colorIcono ?? p.texto),
      );
    }
    final montoTexto = monto == null
        ? null
        : Text(monto!, style: textos.cuerpoFuerte.copyWith(color: colorMonto ?? p.texto));
    final derechaFinal = derecha ?? (apilado ? null : montoTexto);

    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            if (lider != null) ...[lider, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(titulo, style: textos.cuerpoFuerte)),
                      if (derechaFinal != null) ...[const SizedBox(width: 8), derechaFinal],
                    ],
                  ),
                  if (apilado && montoTexto != null && derecha == null) montoTexto,
                  if (subtitulo != null) Text(subtitulo!, style: textos.etiqueta),
                  if (abajo != null) ...[const SizedBox(height: 6), abajo!],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: p.texto2, size: 22),
            ],
          ],
        ),
      ),
    );
    final cuerpo = onTap == null ? contenido : InkWell(onTap: onTap, child: contenido);
    final etiqueta = etiquetaSemantica;
    return Semantics(
      button: onTap != null,
      label: etiqueta,
      excludeSemantics: etiqueta != null,
      child: cuerpo,
    );
  }
}

/// Encabezado de sección: título en `seccion` y, opcional, un dato a la
/// derecha en `etiqueta` ("Quedan $6,390") o una acción.
class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final String? dato;
  final Widget? accion;

  const EncabezadoSeccion({super.key, required this.titulo, this.dato, this.accion});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 32, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Semantics(header: true, child: Text(titulo, style: textos.seccion))),
          if (dato != null) Text(dato!, style: textos.etiqueta),
          ?accion,
        ],
      ),
    );
  }
}
