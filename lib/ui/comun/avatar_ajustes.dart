import 'package:flutter/material.dart';

import 'tema.dart';

/// El avatar de arriba a la derecha de las pantallas raíz: abre Ajustes
/// (`docs/rediseno/design-system/componentes/Navegacion.md`). Lleva la
/// inicial del nombre de la cuenta; sin nombre, una silueta.
class AvatarAjustes extends StatelessWidget {
  final String? nombre;
  final VoidCallback onTap;

  const AvatarAjustes({super.key, required this.nombre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final inicial = (nombre?.trim().isNotEmpty ?? false) ? nombre!.trim()[0].toUpperCase() : null;
    return Semantics(
      button: true,
      label: 'Ajustes',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle, border: Border.all(color: p.borde)),
              child: inicial == null
                  ? Icon(Icons.person_outline_rounded, size: 20, color: p.texto)
                  : Text(inicial, style: Theme.of(context).textTheme.cuerpoFuerte, textScaler: TextScaler.noScaling),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de una pantalla raíz: título (y subtítulo) con el avatar a
/// la derecha, sin flecha ←.
class EncabezadoRaiz extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final String? nombre;
  final VoidCallback alAbrirAjustes;

  const EncabezadoRaiz({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.nombre,
    required this.alAbrirAjustes,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(titulo, style: textos.titulo)),
                if (subtitulo != null) Text(subtitulo!, style: textos.etiqueta),
              ],
            ),
          ),
          AvatarAjustes(nombre: nombre, onTap: alAbrirAjustes),
        ],
      ),
    );
  }
}
