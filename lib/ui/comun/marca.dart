import 'package:flutter/material.dart';

import 'tema.dart';

/// Elementos de marca de la dirección visual premium (2026-10-25): el
/// emblema (el logo de FinVita, `assets/marca/logo.png`) y el fondo azul
/// noche con montañas, dibujado, para las pantallas de entrada (login y
/// bienvenida).

/// El logo de FinVita (aro dorado con montaña, bandera, flecha y barras).
class EmblemaApp extends StatelessWidget {
  final double tamano;

  const EmblemaApp({super.key, this.tamano = 112});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x40D4AF37), blurRadius: 28)],
        ),
        child: Image.asset('assets/marca/logo.png', width: tamano, height: tamano),
      ),
    );
  }
}

/// Fondo azul noche con dos cordilleras al pie: una azul marino y otra con
/// filo dorado. Decorativo; el contenido va encima.
class FondoMontanas extends StatelessWidget {
  final Widget child;

  const FondoMontanas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071529), ColoresApp.azul, ColoresApp.azulMarino],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: _PintorMontanas())),
          ),
          child,
        ],
      ),
    );
  }
}

class _PintorMontanas extends CustomPainter {
  const _PintorMontanas();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Cordillera del fondo, apenas más clara que el cielo.
    final lejana = Path()
      ..moveTo(0, h * 0.78)
      ..lineTo(w * 0.18, h * 0.66)
      ..lineTo(w * 0.32, h * 0.73)
      ..lineTo(w * 0.52, h * 0.58)
      ..lineTo(w * 0.70, h * 0.70)
      ..lineTo(w * 0.86, h * 0.62)
      ..lineTo(w, h * 0.70)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(lejana, Paint()..color = const Color(0xFF16345C));

    // Cordillera del frente.
    final cercana = Path()
      ..moveTo(0, h * 0.88)
      ..lineTo(w * 0.22, h * 0.76)
      ..lineTo(w * 0.40, h * 0.84)
      ..lineTo(w * 0.62, h * 0.72)
      ..lineTo(w * 0.80, h * 0.82)
      ..lineTo(w, h * 0.77)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(cercana, Paint()..color = const Color(0xFF0A1A33));

    // Filo dorado sobre la cima principal, como luz de amanecer.
    final filo = Path()
      ..moveTo(w * 0.40, h * 0.84)
      ..lineTo(w * 0.62, h * 0.72)
      ..lineTo(w * 0.80, h * 0.82);
    canvas.drawPath(
      filo,
      Paint()
        ..color = ColoresApp.oro.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
