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

  /// Qué mide esta barra ("Súper/Comida", "Renta") — obligatorio a
  /// propósito: sin esto, un lector de pantalla solo puede anunciar
  /// "imagen" o quedarse mudo frente al único elemento de interfaz que
  /// hay que aprender (Fase 6, Bloque 4.3).
  final String descripcion;

  /// Proyección aparte del [estado] absoluto (ver `vaMuyRapido` en
  /// estado_ritmo.dart): "a este paso no te va a alcanzar". Solo se
  /// dibuja cuando [estado] todavía no es [EstadoRitmo.excedido] — si ya
  /// te excediste, la proyección no aporta nada que la etiqueta
  /// "Excedido" no diga ya.
  final bool vaMuyRapido;

  const BarraRitmo({
    super.key,
    required this.porcentajeUsado,
    required this.avanceCiclo,
    required this.estado,
    required this.descripcion,
    this.vaMuyRapido = false,
  });

  Color get _color => switch (estado) {
    EstadoRitmo.vaBien => ColoresApp.verde,
    EstadoRitmo.justo => ColoresApp.ambar,
    EstadoRitmo.excedido => ColoresApp.coral,
  };

  /// Solo tiene sentido mostrar "a este paso no te va a alcanzar" cuando
  /// [estado] no es ya [EstadoRitmo.excedido] — si ya se excedió el
  /// presupuesto, la proyección no dice nada que "Excedido" no diga ya.
  bool get _mostrarProyeccion => vaMuyRapido && estado != EstadoRitmo.excedido;

  String get _label {
    final usado = (porcentajeUsado.clamp(0.0, 1.0) * 100).round();
    final avance = (avanceCiclo.clamp(0.0, 1.0) * 100).round();
    final proyeccion = _mostrarProyeccion ? ' A este paso, no te va a alcanzar.' : '';
    return 'Ritmo de $descripcion: ${etiquetaEstadoRitmo(estado)}. '
        'Llevas $usado% del presupuesto; a estas alturas del ciclo deberías ir en $avance%.$proyeccion';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
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
                      child: Container(
                        width: 2,
                        height: 10,
                        color: ColoresApp.tinta,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_mostrarProyeccion) ...[
            const SizedBox(height: 4),
            Text(
              'A este paso, no te va a alcanzar',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ColoresApp.ambarTexto,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

String etiquetaEstadoRitmo(EstadoRitmo estado) => switch (estado) {
  EstadoRitmo.vaBien => 'Vas bien',
  EstadoRitmo.justo => 'Justo',
  EstadoRitmo.excedido => 'Excedido',
};

/// Para fondos y gráficas (barra, tinte de chip con alpha) — umbral WCAG
/// 3:1, no 4.5:1. **Nunca** como color de texto directo; para eso está
/// [colorTextoEstadoRitmo] (Fase 6, Bloque 4.1).
Color colorEstadoRitmo(EstadoRitmo estado) => switch (estado) {
  EstadoRitmo.vaBien => ColoresApp.verde,
  EstadoRitmo.justo => ColoresApp.ambar,
  EstadoRitmo.excedido => ColoresApp.coral,
};

/// Variante oscurecida de [colorEstadoRitmo], la que sí pasa 4.5:1 sobre
/// blanco o sobre un tinte `Suave` — para las etiquetas de estado ("Vas
/// bien", "Excedido") que muestran el color como texto, no como fondo.
Color colorTextoEstadoRitmo(EstadoRitmo estado) => switch (estado) {
  EstadoRitmo.vaBien => ColoresApp.verdeTexto,
  EstadoRitmo.justo => ColoresApp.ambarTexto,
  EstadoRitmo.excedido => ColoresApp.coralTexto,
};
