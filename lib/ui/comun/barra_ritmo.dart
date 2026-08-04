import 'package:flutter/material.dart';

import '../../domain/rollups/estado_ritmo.dart';
import 'tema.dart';

/// La "marca de ritmo" (addendum-v3 §3.2): una línea vertical que marca
/// dónde deberías ir hoy. Barra pasada de la marca = vas rápido; barra
/// corta = vas bien. Es el único elemento de interfaz que hay que
/// aprender, y se ve igual en toda la app.
class BarraRitmo extends StatelessWidget {
  final double porcentajeUsado;
  final double avanceCiclo;
  final EstadoRitmo estado;

  const BarraRitmo({
    super.key,
    required this.porcentajeUsado,
    required this.avanceCiclo,
    required this.estado,
  });

  Color get _color => switch (estado) {
        EstadoRitmo.vaBien => ColoresApp.verde,
        EstadoRitmo.justo => ColoresApp.ambar,
        EstadoRitmo.pasado => ColoresApp.coral,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final anchoBarra = ancho * porcentajeUsado.clamp(0.0, 1.0);
        final posMarca = ancho * avanceCiclo.clamp(0.0, 1.0);
        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFF6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: anchoBarra,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Positioned(
                left: (posMarca - 1).clamp(0.0, ancho - 2),
                child: Container(width: 2, height: 10, color: ColoresApp.tinta),
              ),
            ],
          ),
        );
      },
    );
  }
}

String etiquetaEstadoRitmo(EstadoRitmo estado) => switch (estado) {
      EstadoRitmo.vaBien => 'Vas bien',
      EstadoRitmo.justo => 'Justo',
      EstadoRitmo.pasado => 'Pasado',
    };

Color colorEstadoRitmo(EstadoRitmo estado) => switch (estado) {
      EstadoRitmo.vaBien => ColoresApp.verde,
      EstadoRitmo.justo => ColoresApp.ambar,
      EstadoRitmo.pasado => ColoresApp.coral,
    };
