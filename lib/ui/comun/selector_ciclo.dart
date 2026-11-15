import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/ciclo_de_vida/ciclos_para_consultar.dart';
import 'formato_fecha.dart';
import 'tema.dart';

/// "‹ Ciclo Oct 2026 ▾ ›" con sus fechas, si está cerrado y cuánto se gastó.
/// Las flechas pasan al ciclo anterior o siguiente; tocar el nombre abre la
/// lista de todos. Lo comparten Gastos y Análisis (spec §5.6.2 y §5.7).
class SelectorCiclo extends StatelessWidget {
  /// Del más reciente al más viejo (`ciclosParaConsultar`).
  final List<CicloConsultable> ciclos;
  final String vistoId;
  final String enCursoId;
  final ValueChanged<String> alCambiar;

  const SelectorCiclo({
    super.key,
    required this.ciclos,
    required this.vistoId,
    required this.enCursoId,
    required this.alCambiar,
  });

  String _estado(CicloConsultable c) => c.ciclo.id == enCursoId
      ? 'En curso'
      : c.cerrado
          ? 'Cerrado'
          : 'Sin cerrar';

  /// Hoja con todos los ciclos: más práctico que las flechas cuando hay
  /// mucha historia.
  Future<void> _elegir(BuildContext context) async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (contexto) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('¿Qué ciclo quieres ver?', style: Theme.of(contexto).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in ciclos)
                      ListTile(
                        selected: c.ciclo.id == vistoId,
                        leading: Icon(c.cerrado ? Icons.lock_outline : Icons.lock_open_outlined),
                        title: Text('Ciclo ${c.ciclo.etiquetaConAnio}'),
                        subtitle: Text(
                          '${fechaCorta(c.ciclo.fechaInicio)} – ${fechaCorta(c.ciclo.fechaFin)} · ${_estado(c)}',
                        ),
                        trailing: Text(Dinero(c.totalCentavos).formateado()),
                        onTap: () => Navigator.of(contexto).pop(c.ciclo.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null && elegido != vistoId) alCambiar(elegido);
  }

  @override
  Widget build(BuildContext context) {
    final indice = ciclos.indexWhere((c) => c.ciclo.id == vistoId);
    if (indice < 0) return const SizedBox.shrink();
    final visto = ciclos[indice];
    final textos = Theme.of(context).textTheme;
    final ciclo = visto.ciclo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          // La lista va del más reciente al más viejo: "anterior" es el
          // siguiente índice.
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Ciclo anterior',
            onPressed: indice + 1 < ciclos.length ? () => alCambiar(ciclos[indice + 1].ciclo.id) : null,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _elegir(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visto.cerrado) ...[
                          Icon(Icons.lock_outline, size: 16, color: ColoresApp.medio),
                          const SizedBox(width: 4),
                        ],
                        Flexible(child: Text('Ciclo ${ciclo.etiquetaConAnio}', style: textos.titleMedium)),
                        Icon(Icons.arrow_drop_down, color: ColoresApp.medio),
                      ],
                    ),
                    Text(
                      '${fechaCorta(ciclo.fechaInicio)} – ${fechaCorta(ciclo.fechaFin)} · ${_estado(visto)} · '
                      '${Dinero(visto.totalCentavos).formateado()}',
                      textAlign: TextAlign.center,
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Ciclo siguiente',
            onPressed: indice > 0 ? () => alCambiar(ciclos[indice - 1].ciclo.id) : null,
          ),
        ],
      ),
    );
  }
}
