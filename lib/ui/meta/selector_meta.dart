import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/meta_apartado.dart';
import '../../domain/presupuesto/coherencia_meta.dart';
import '../../domain/presupuesto/sugerencia_meta.dart';
import '../comun/formato_dinero.dart';
import '../comun/tema.dart';

enum _ModoMeta { porcentaje, monto, derivada }

/// Selector compartido de meta de apartado (`app-finanzas-onboarding-v5
/// .html §4`, `-INTERACTIVO.html`): SegmentedButton entre porcentaje del
/// ingreso, monto fijo y "lo que sobre" (meta derivada, `metaApartado ==
/// null`); tarjeta de sugerencia; aviso ámbar cuando los presupuestos ya
/// declarados no caben en la meta elegida.
///
/// Se usa tanto en `PantallaMetaAhorro` (edición desde Ajustes/Inicio) como
/// en el paso 4 del onboarding — por eso no trae `Scaffold` ni botón de
/// guardar: [onCambio] notifica la meta vigente en cada cambio y quien lo
/// envuelve decide cuándo persistirla.
class SelectorMeta extends StatefulWidget {
  final Dinero ingresoBase;
  final List<CategoriaFija> fijas;
  final List<CategoriaVariable> variables;
  final MetaApartado? metaInicial;
  final ValueChanged<MetaApartado?> onCambio;
  final VoidCallback? onIrACategorias;

  const SelectorMeta({
    super.key,
    required this.ingresoBase,
    required this.fijas,
    required this.variables,
    required this.metaInicial,
    required this.onCambio,
    this.onIrACategorias,
  });

  @override
  State<SelectorMeta> createState() => _SelectorMetaState();
}

class _SelectorMetaState extends State<SelectorMeta> {
  late _ModoMeta _modo;
  late int _porcentaje;
  late final TextEditingController _montoControlador;

  @override
  void initState() {
    super.initState();
    final inicial = widget.metaInicial;
    switch (inicial) {
      case MetaPorPorcentaje(:final porcentaje):
        _modo = _ModoMeta.porcentaje;
        _porcentaje = porcentaje;
        _montoControlador = TextEditingController();
      case MetaPorMonto(:final monto):
        _modo = _ModoMeta.monto;
        _porcentaje = 0;
        _montoControlador = TextEditingController(text: textoEditableDeDinero(monto));
      case null:
        _modo = _ModoMeta.derivada;
        _porcentaje = 0;
        _montoControlador = TextEditingController();
    }
  }

  @override
  void dispose() {
    _montoControlador.dispose();
    super.dispose();
  }

  Dinero get _totalFijas => Dinero.suma(widget.fijas.map((f) => f.montoFijoCentavos));

  MetaApartado? get _metaActual {
    switch (_modo) {
      case _ModoMeta.porcentaje:
        return MetaPorPorcentaje(_porcentaje);
      case _ModoMeta.monto:
        final monto = Dinero.intentarDesdeTexto(_montoControlador.text);
        return monto == null ? null : MetaPorMonto(monto);
      case _ModoMeta.derivada:
        return null;
    }
  }

  /// Lo que sobraría de tus categorías si la meta fuera "lo que sobre" —
  /// solo tiene sentido pintarlo en ese modo, [_bloqueDerivada] es el único
  /// que lo usa.
  Dinero get _montoSiDerivada => widget.ingresoBase -
      Dinero.suma([
        ...widget.fijas.map((f) => f.montoFijoCentavos),
        ...widget.variables.map((v) => v.presupuestoMensualCentavos),
      ]);

  void _notificar() => widget.onCambio(_metaActual);

  void _cambiarModo(_ModoMeta modo) {
    setState(() => _modo = modo);
    _notificar();
  }

  void _usarSugerencia() {
    final sugerencia = sugerirPorcentaje(ingresoBase: widget.ingresoBase, totalFijas: _totalFijas);
    setState(() {
      _modo = _ModoMeta.porcentaje;
      _porcentaje = sugerencia.porcentaje;
    });
    _notificar();
  }

  void _bajarMetaA(int porcentaje) {
    setState(() {
      _modo = _ModoMeta.porcentaje;
      _porcentaje = porcentaje;
    });
    _notificar();
  }

  @override
  Widget build(BuildContext context) {
    final metaActual = _metaActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_ModoMeta>(
          segments: const [
            ButtonSegment(value: _ModoMeta.porcentaje, label: Text('% de lo que entra')),
            ButtonSegment(value: _ModoMeta.monto, label: Text('Monto fijo')),
            ButtonSegment(value: _ModoMeta.derivada, label: Text('Lo que sobre')),
          ],
          selected: {_modo},
          onSelectionChanged: (seleccion) => _cambiarModo(seleccion.first),
        ),
        const SizedBox(height: 20),
        if (_modo == _ModoMeta.porcentaje) _bloquePorcentaje(context),
        if (_modo == _ModoMeta.monto) _bloqueMonto(context),
        if (_modo == _ModoMeta.derivada) _bloqueDerivada(context, _montoSiDerivada),
        const SizedBox(height: 16),
        _tarjetaSugerencia(context),
        if (metaActual != null) ...[
          const SizedBox(height: 16),
          _avisoSiNoCabe(context, metaActual),
        ],
      ],
    );
  }

  Widget _bloquePorcentaje(BuildContext context) {
    final apartado = Dinero((widget.ingresoBase.centavos * _porcentaje + 50) ~/ 100);
    final gastar = widget.ingresoBase - apartado;
    return Column(
      children: [
        Text(
          apartado.formateado(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        Text(
          '$_porcentaje% de tus ingresos',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: _porcentaje.toDouble(),
          min: 0,
          max: 70,
          divisions: 14,
          label: '$_porcentaje%',
          onChanged: (v) {
            setState(() => _porcentaje = v.round());
            _notificar();
          },
        ),
        Row(
          children: [
            Expanded(
              child: _Split(etiqueta: 'Para apartar', monto: apartado, color: ColoresApp.verdeTexto),
            ),
            Expanded(child: _Split(etiqueta: 'Para gastar', monto: gastar)),
          ],
        ),
      ],
    );
  }

  Widget _bloqueMonto(BuildContext context) {
    return TextField(
      controller: _montoControlador,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Cuánto quieres apartar cada ciclo'),
      onChanged: (_) => _notificar(),
    );
  }

  Widget _bloqueDerivada(BuildContext context, Dinero montoMeta) {
    return Column(
      children: [
        Text(
          montoMeta.formateado(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        Text(
          'Lo que quede después de tus categorías fijas y variables',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _tarjetaSugerencia(BuildContext context) {
    final sugerencia = sugerirPorcentaje(ingresoBase: widget.ingresoBase, totalFijas: _totalFijas);
    final montoSugerido = MetaPorPorcentaje(sugerencia.porcentaje).montoPara(widget.ingresoBase);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.violetaSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '¿No sabes cuánto? Te sugiero empezar con ${sugerencia.porcentaje}% '
              '(~${montoSugerido.formateado()}) e ir subiendo.',
              style: const TextStyle(color: ColoresApp.tinta, fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: _usarSugerencia, child: const Text('Usar sugerencia')),
        ],
      ),
    );
  }

  Widget _avisoSiNoCabe(BuildContext context, MetaApartado meta) {
    final evaluacion = evaluarMeta(
      ingresoBase: widget.ingresoBase,
      metaBase: meta.montoPara(widget.ingresoBase),
      fijas: widget.fijas,
      variables: widget.variables,
    );
    if (evaluacion.estado != EstadoCoherenciaMeta.noCabe) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.ambarSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tus presupuestos se pasan por ${evaluacion.excedente.absoluto.formateado()} '
            'de lo que esta meta deja disponible. Con ellos tal cual están, solo apartarías '
            '${evaluacion.porcentajeSiRespetaPresupuestos}%.',
            style: const TextStyle(color: ColoresApp.tinta, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _bajarMetaA(evaluacion.porcentajeSiRespetaPresupuestos),
                child: Text('Bajar la meta a ${evaluacion.porcentajeSiRespetaPresupuestos}%'),
              ),
              if (widget.onIrACategorias != null)
                TextButton(onPressed: widget.onIrACategorias, child: const Text('Ir a Categorías')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  final String etiqueta;
  final Dinero monto;
  final Color? color;

  const _Split({required this.etiqueta, required this.monto, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
        Text(
          monto.formateado(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
