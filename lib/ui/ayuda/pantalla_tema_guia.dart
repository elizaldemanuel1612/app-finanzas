import 'package:flutter/material.dart';

import 'bloques_guia.dart';
import 'contenido_guia.dart';
import 'modelo_guia.dart';
import '../comun/tema.dart';

/// Un tema de la guía, leído de corrido: medallón + resumen, sus bloques
/// de contenido y una navegación ← Anterior / Siguiente → al pie que
/// recorre [temasEnOrden] — así el índice temático también sirve como
/// manual leído de principio a fin.
class PantallaTemaGuia extends StatelessWidget {
  final TemaGuia tema;

  const PantallaTemaGuia({super.key, required this.tema});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final orden = temasEnOrden;
    final indice = orden.indexWhere((t) => t.id == tema.id);
    final anterior = indice > 0 ? orden[indice - 1] : null;
    final siguiente = indice >= 0 && indice < orden.length - 1 ? orden[indice + 1] : null;

    return Scaffold(
      appBar: AppBar(title: Text(tema.titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                child: ExcludeSemantics(child: Text(tema.emoji, style: theme.headlineMedium)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(tema.resumen, style: theme.bodySmall)),
            ],
          ),
          const Divider(height: 32),
          for (final bloque in tema.bloques) BloqueGuiaWidget(bloque),
          const SizedBox(height: 12),
          Row(
            children: [
              if (anterior != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => PantallaTemaGuia(tema: anterior)),
                    ),
                    child: const Text('← Anterior'),
                  ),
                ),
              if (anterior != null && siguiente != null) const SizedBox(width: 12),
              if (siguiente != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => PantallaTemaGuia(tema: siguiente)),
                    ),
                    child: const Text('Siguiente →'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
