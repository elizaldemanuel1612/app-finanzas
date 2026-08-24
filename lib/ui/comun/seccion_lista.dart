import 'package:flutter/material.dart';

/// Un título de sección (mayúsculas implícitas por estilo, `w700`) seguido
/// de una `Card` con sus renglones — el patrón que ya usaba Ajustes seis
/// veces como clase privada `_Seccion`, ahora compartido con la guía por
/// temas.
class SeccionLista extends StatelessWidget {
  final String titulo;
  final List<Widget> hijos;

  const SeccionLista({super.key, required this.titulo, required this.hijos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: hijos),
          ),
        ),
      ],
    );
  }
}
