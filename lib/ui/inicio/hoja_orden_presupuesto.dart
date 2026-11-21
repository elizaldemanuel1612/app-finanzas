import 'package:flutter/material.dart';

import '../../domain/modelos/categoria.dart';
import '../../domain/rollups/orden_categorias.dart';
import '../comun/hoja.dart';
import '../comun/tema.dart';

/// Lo que eligió el usuario; `null` si cerró la hoja sin cambiar nada.
typedef EleccionOrden = ({OrdenPresupuesto orden, List<String> propio});

/// Hoja "Ordenar presupuesto" de Inicio (spec-app-finanzas-v2.md §5.6.4).
/// Tocar un criterio lo aplica y cierra; "Mi orden" abre la lista para
/// arrastrar, que se guarda con su botón. [actuales] es la lista tal como se
/// ve ahora: de ahí arranca "Mi orden" la primera vez.
Future<EleccionOrden?> mostrarHojaOrdenPresupuesto(
  BuildContext context, {
  required OrdenPresupuesto orden,
  required List<CategoriaVariable> actuales,
  required List<String> ordenPropio,
}) =>
    mostrarHoja<EleccionOrden>(
      context,
      desplazable: false,
      builder: (_) => _HojaOrden(orden: orden, actuales: actuales, ordenPropio: ordenPropio),
    );

class _HojaOrden extends StatefulWidget {
  final OrdenPresupuesto orden;
  final List<CategoriaVariable> actuales;
  final List<String> ordenPropio;

  const _HojaOrden({required this.orden, required this.actuales, required this.ordenPropio});

  @override
  State<_HojaOrden> createState() => _HojaOrdenState();
}

class _HojaOrdenState extends State<_HojaOrden> {
  late bool _acomodando = widget.orden == OrdenPresupuesto.propio;

  /// "Mi orden": lo ya guardado (con lo nuevo al final) o, la primera vez,
  /// lo que el usuario ve ahora mismo.
  late final List<CategoriaVariable> _propias = widget.ordenPropio.isEmpty
      ? [...widget.actuales]
      : ordenarPresupuesto(
          widget.actuales,
          const {},
          orden: OrdenPresupuesto.propio,
          avanceCiclo: 0,
          ordenPropio: widget.ordenPropio,
        );

  static const _opciones = [
    (OrdenPresupuesto.atencion, 'Lo que necesita atención', 'Las que te pasaste o van rápido, arriba'),
    (OrdenPresupuesto.propio, 'Mi orden', 'Acomódalas como tú quieras'),
    (OrdenPresupuesto.masGastado, 'Lo que más llevas gastado', 'De mayor a menor en este ciclo'),
    (OrdenPresupuesto.nombre, 'Por nombre', 'De la A a la Z'),
  ];

  void _elegir(OrdenPresupuesto o) {
    if (o == OrdenPresupuesto.propio) {
      setState(() => _acomodando = true);
      return;
    }
    Navigator.of(context).pop<EleccionOrden>((orden: o, propio: widget.ordenPropio));
  }

  void _guardarPropio() => Navigator.of(context).pop<EleccionOrden>(
        (orden: OrdenPresupuesto.propio, propio: [for (final c in _propias) c.id]),
      );

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    final seleccion = _acomodando ? OrdenPresupuesto.propio : widget.orden;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ordenar presupuesto', style: textos.seccion),
              const SizedBox(height: 8),
              for (final (o, titulo, detalle) in _opciones)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(titulo),
                  subtitle: Text(detalle),
                  trailing: o == seleccion
                      ? Icon(Icons.check, color: p.accion, semanticLabel: 'Elegido')
                      : null,
                  onTap: () => _elegir(o),
                ),
              if (_acomodando) ...[
                const SizedBox(height: 8),
                Text('Arrastra cada una desde la derecha a su lugar', style: textos.etiqueta),
                const SizedBox(height: 4),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (de, a) => setState(() => _propias.insert(a, _propias.removeAt(de))),
                  children: [
                    for (final (i, c) in _propias.indexed)
                      ListTile(
                        key: ValueKey(c.id),
                        contentPadding: EdgeInsets.zero,
                        leading: ExcludeSemantics(child: Text(c.emoji, style: textos.titulo)),
                        title: Text(c.nombre),
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.drag_handle, color: p.texto2, semanticLabel: 'Mover ${c.nombre}'),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _guardarPropio, child: const Text('Guardar mi orden')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
