import 'package:flutter/material.dart';

import 'tema.dart';

/// Estado de carga (`docs/rediseno/design-system/componentes/Estados.md`):
/// la forma real del contenido en `superficie-hundida`, sin spinners de
/// pantalla completa ni brillo animado.
class Esqueleto extends StatelessWidget {
  final double? ancho;
  final double alto;
  final double radio;

  const Esqueleto({super.key, this.ancho, required this.alto, this.radio = Radios.s});

  /// Una tarjeta entera.
  const Esqueleto.tarjeta({super.key, required this.alto})
      : ancho = null,
        radio = Radios.l;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          color: ColoresApp.superficieHundida,
          borderRadius: BorderRadius.circular(radio),
        ),
      ),
    );
  }
}

/// Lo que se lee mientras carga, una sola vez para toda la pantalla.
class CargandoPantalla extends StatelessWidget {
  final List<Widget> formas;

  const CargandoPantalla({super.key, required this.formas});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (i, f) in formas.indexed) ...[if (i > 0) const SizedBox(height: 12), f],
        ],
      ),
    );
  }
}
