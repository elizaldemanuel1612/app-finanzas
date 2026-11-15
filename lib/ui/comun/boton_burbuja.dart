import 'package:flutter/material.dart';

import 'tema.dart';

/// Ícono dentro de una burbuja circular (al estilo de los botones de
/// navegación de iOS): fondo hundido y contorno suave, para que atrás,
/// cerrar y las acciones del encabezado se vean como botones y no como
/// íconos sueltos. Lo usan `ActionIconThemeData` (atrás y cerrar en toda la
/// app) y [BotonBurbuja].
class IconoBurbuja extends StatelessWidget {
  final IconData icono;
  const IconoBurbuja(this.icono, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.superficieHundida,
        shape: BoxShape.circle,
        border: Border.all(color: p.borde),
      ),
      child: Icon(icono, size: 20, color: p.texto),
    );
  }
}

/// Botón de encabezado en burbuja (micrófono, cámara, filtros…).
class BotonBurbuja extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  const BotonBurbuja({super.key, required this.icono, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Opacity(opacity: onPressed == null ? 0.4 : 1, child: IconoBurbuja(icono)),
    );
  }
}
