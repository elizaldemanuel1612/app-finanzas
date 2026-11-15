import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/presupuesto/traslado_sobrante.dart';
import '../comun/formato_dinero.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';

/// Lo que eligió el usuario; `null` si cerró la hoja sin decidir.
typedef DecisionTraslado = ({Set<String> elegidas, bool recordar});

/// Hoja de "¿Pasas lo que sobró a este ciclo?" (addendum-v3 §2.5.2): una
/// casilla por variable con sobrante, nada marcado por omisión salvo lo
/// recordado, y el efecto en lo que apartas antes de decidir.
Future<DecisionTraslado?> mostrarHojaTraslado(
  BuildContext context, {
  required List<SobranteCategoria> sobrantes,
  required Set<String> preseleccion,
}) =>
    showModalBottomSheet<DecisionTraslado>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HojaTraslado(sobrantes: sobrantes, preseleccion: preseleccion),
    );

class _HojaTraslado extends StatefulWidget {
  final List<SobranteCategoria> sobrantes;
  final Set<String> preseleccion;
  const _HojaTraslado({required this.sobrantes, required this.preseleccion});

  @override
  State<_HojaTraslado> createState() => _HojaTrasladoState();
}

class _HojaTrasladoState extends State<_HojaTraslado> {
  late final Set<String> _elegidas = {...widget.preseleccion};
  late bool _recordar = widget.preseleccion.isNotEmpty;

  Dinero get _total => Dinero(widget.sobrantes
      .where((s) => _elegidas.contains(s.categoria.id))
      .fold<int>(0, (t, s) => t + s.sobrante.centavos));

  void _alternar(String id) => setState(() => _elegidas.contains(id) ? _elegidas.remove(id) : _elegidas.add(id));

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    final n = widget.sobrantes.length;
    final total = _total;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(n == 1 ? 'Te sobró en una categoría' : 'Te sobró en $n categorías', style: textos.seccion),
              const SizedBox(height: 4),
              Text(
                'Elige si pasas algo a este ciclo. Solo se suma a este ciclo; tu presupuesto de siempre no cambia.',
                style: textos.etiqueta,
              ),
              const SizedBox(height: 12),
              TarjetaApp.lista(renglones: [
                // Todo el renglón marca la casilla; la casilla va centrada
                // a la derecha, sin la flecha de "abrir".
                for (final s in widget.sobrantes)
                  CheckboxListTile(
                    value: _elegidas.contains(s.categoria.id),
                    onChanged: (_) => _alternar(s.categoria.id),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    secondary: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                      child: ExcludeSemantics(
                        child: Text(s.categoria.emoji, style: textos.cuerpo, textScaler: TextScaler.noScaling),
                      ),
                    ),
                    title: Text(s.categoria.nombre, style: textos.cuerpoFuerte),
                    subtitle: Text('Sobraron ${enPesos(s.sobrante)}', style: textos.etiqueta),
                  ),
              ]),
              if (total.esPositivo) ...[
                const SizedBox(height: 10),
                Text(
                  'Apartarías hasta ${enPesos(total)} menos este ciclo.',
                  style: textos.etiqueta.copyWith(color: p.atencionTexto),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordar mi elección'),
                subtitle: const Text('La próxima vez vendrán marcadas las mismas'),
                value: _recordar,
                onChanged: (v) => setState(() => _recordar = v),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: total.esPositivo
                    ? () => Navigator.of(context).pop((elegidas: {..._elegidas}, recordar: _recordar))
                    : null,
                child: Text(total.esPositivo ? 'Trasladar ${enPesos(total)}' : 'Elige qué trasladar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop((elegidas: <String>{}, recordar: _recordar)),
                child: const Text('No trasladar nada'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
