import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../domain/presupuesto/rebalanceo.dart';
import '../comun/formato_dinero.dart';
import '../comun/popscope_descartar.dart';
import '../comun/tema.dart';

/// addendum-v3-ajuste-y-ux.md §2.5: el usuario decide, renglón por renglón,
/// cuánto mover de cada candidata — nunca un reparto automático. El
/// resultado es un ajuste **temporal**, vigente solo para [ciclo]: nunca
/// toca el presupuesto base de ninguna categoría
/// (`domain/presupuesto/ajuste_presupuesto_ciclo.dart`).
class PantallaMoverPresupuesto extends StatefulWidget {
  final Rebalanceo rebalanceo;
  final Ciclo ciclo;
  final AjustePresupuestoCicloRepositorio ajustePresupuestoCicloRepositorio;

  const PantallaMoverPresupuesto({
    super.key,
    required this.rebalanceo,
    required this.ciclo,
    required this.ajustePresupuestoCicloRepositorio,
  });

  @override
  State<PantallaMoverPresupuesto> createState() =>
      _PantallaMoverPresupuestoState();
}

class _PantallaMoverPresupuestoState extends State<PantallaMoverPresupuesto> {
  late final List<TextEditingController> _controladores = [
    for (final _ in widget.rebalanceo.candidatas) TextEditingController(),
  ];
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hayCambiosSinGuardar =>
      _controladores.any((c) => c.text.trim().isNotEmpty);

  Dinero _montoDe(int indice) =>
      Dinero.intentarDesdeTexto(_controladores[indice].text) ??
      const Dinero.cero();

  Dinero get _sumaIngresada =>
      Dinero.suma(_controladores.map((c) => Dinero.intentarDesdeTexto(c.text) ?? const Dinero.cero()));

  Dinero get _faltaPorCubrir => widget.rebalanceo.faltante - _sumaIngresada;

  Future<void> _guardar() async {
    final movimientos = <MovimientoRebalanceo>[];
    for (var i = 0; i < widget.rebalanceo.candidatas.length; i++) {
      final monto = _montoDe(i);
      if (monto.esPositivo) {
        movimientos.add(
          MovimientoRebalanceo(
            categoriaOrigenId: widget.rebalanceo.candidatas[i].categoria.id,
            monto: monto,
          ),
        );
      }
    }

    final resultado = construirAjustesDeRebalanceo(
      rebalanceo: widget.rebalanceo,
      movimientos: movimientos,
      cicloId: widget.ciclo.id,
      cuando: DateTime.now(),
      dispositivo: 'app',
    );
    if (resultado case Falla(:final mensaje)) {
      setState(() => _error = mensaje);
      return;
    }

    setState(() {
      _error = null;
      _guardando = true;
    });
    await widget.ajustePresupuestoCicloRepositorio.agregarLote(
      resultado.valorOLanza,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final faltaPorCubrir = _faltaPorCubrir;
    final cubierto = !faltaPorCubrir.esPositivo;

    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mover presupuesto')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Falta cubrir ${widget.rebalanceo.faltante.formateado()} este ciclo. '
              'Decide cuánto mover de cada categoría.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cubierto ? ColoresApp.verdeSuave : ColoresApp.fondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cubierto ? 'Cubierto' : 'Falta por cubrir',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cubierto
                          ? ColoresApp.verdeTexto
                          : ColoresApp.medio,
                    ),
                  ),
                  Text(
                    cubierto && faltaPorCubrir.esNegativo
                        ? '+${faltaPorCubrir.absoluto.formateado()} de más'
                        : faltaPorCubrir.formateado(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cubierto
                          ? ColoresApp.verdeTexto
                          : ColoresApp.tinta,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < widget.rebalanceo.candidatas.length; i++) ...[
              _TarjetaCandidata(
                candidata: widget.rebalanceo.candidatas[i],
                controlador: _controladores[i],
                onCambio: () => setState(() {}),
              ),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: ColoresApp.coralTexto),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _guardando
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCandidata extends StatelessWidget {
  final CandidataRebalanceo candidata;
  final TextEditingController controlador;
  final VoidCallback onCambio;

  const _TarjetaCandidata({
    required this.candidata,
    required this.controlador,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final monto = Dinero.intentarDesdeTexto(controlador.text);
    final excedeHolgura = monto != null && monto > candidata.holgura;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  candidata.categoria.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    candidata.categoria.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Text(
              'hasta ${candidata.holgura.formateado()} disponible',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controlador,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: formateadoresDeMonto,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                prefixText: r'$ ',
                errorText: excedeHolgura
                    ? 'No puede exceder ${candidata.holgura.formateado()}.'
                    : null,
              ),
              onChanged: (_) => onCambio(),
            ),
          ],
        ),
      ),
    );
  }
}
