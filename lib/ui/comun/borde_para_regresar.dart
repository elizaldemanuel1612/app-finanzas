import 'package:flutter/widgets.dart';

/// Franja del borde izquierdo que imita el gesto de atrás de iOS donde el
/// sistema no lo da: en las pestañas raíz (no hay ruta debajo) y en una
/// captura con cambios (el `PopScope` que pregunta "¿Descartar?" apaga el
/// gesto nativo). Deslizar hacia la derecha desde ahí llama a [alRegresar].
class BordeParaRegresar extends StatefulWidget {
  final VoidCallback alRegresar;
  final Widget child;
  const BordeParaRegresar({super.key, required this.alRegresar, required this.child});

  @override
  State<BordeParaRegresar> createState() => _BordeParaRegresarState();
}

class _BordeParaRegresarState extends State<BordeParaRegresar> {
  double _avance = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _avance = 0,
            onHorizontalDragUpdate: (d) => _avance += d.delta.dx,
            onHorizontalDragEnd: (d) {
              if (_avance > 60 || (d.primaryVelocity ?? 0) > 300) widget.alRegresar();
            },
          ),
        ),
      ],
    );
  }
}
