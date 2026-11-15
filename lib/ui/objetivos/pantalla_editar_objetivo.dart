import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/objetivo_repositorio.dart';
import '../../domain/cuentas/apartados.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/objetivo.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/popscope_descartar.dart';
import '../comun/tema.dart';
import '../cuentas/pantalla_editar_cuenta.dart';

/// Alta o edición de un objetivo de ahorro (spec-app-finanzas-v2.md
/// §7.3.3): nombre, cuánto, en qué cuenta de ahorro se junta y, si se
/// quiere, para cuándo.
class PantallaEditarObjetivo extends StatefulWidget {
  final ObjetivoRepositorio objetivoRepositorio;
  final CuentaRepositorio cuentaRepositorio;
  final Objetivo? existente;

  /// Para un objetivo nuevo desde una sugerencia ("✈️ Viaje"): llena el
  /// emoji y el nombre; el usuario pone monto, cuenta y fecha.
  final ({String emoji, String nombre})? sugerencia;

  const PantallaEditarObjetivo({
    super.key,
    required this.objetivoRepositorio,
    required this.cuentaRepositorio,
    this.existente,
    this.sugerencia,
  });

  @override
  State<PantallaEditarObjetivo> createState() => _PantallaEditarObjetivoState();
}

class _PantallaEditarObjetivoState extends State<PantallaEditarObjetivo> {
  late final _nombre = TextEditingController(text: widget.existente?.nombre ?? widget.sugerencia?.nombre ?? '');
  late final _emoji = TextEditingController(text: widget.existente?.emoji ?? widget.sugerencia?.emoji ?? '🎯');
  late final _monto = TextEditingController(
    text: widget.existente == null ? '' : textoEditableDeDinero(widget.existente!.monto),
  );
  late DateTime? _fecha = widget.existente?.fechaLimite;
  late String? _cuentaId = widget.existente?.cuentaId;

  /// Las cuentas de ahorro activas; `null` mientras cargan.
  List<Cuenta>? _cuentas;

  /// Todas, para nombrar un apartado con su cuenta ("Viaje · BBVA").
  List<Cuenta> _todas = const [];
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _emoji.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _cargarCuentas() async {
    final todas = await widget.cuentaRepositorio.listarTodas();
    if (!mounted) return;
    setState(() {
      _todas = todas;
      _cuentas = [
        for (final c in todas)
          if (c.tipo == TipoCuenta.ahorro && (c.activa || c.id == _cuentaId)) c,
      ];
      // Con una sola cuenta de ahorro no hay nada que elegir.
      _cuentaId ??= _cuentas!.length == 1 ? _cuentas!.single.id : null;
    });
  }

  Future<void> _crearCuenta() async {
    final antes = {for (final c in _cuentas ?? const <Cuenta>[]) c.id};
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaEditarCuenta(
          cuentaRepositorio: widget.cuentaRepositorio,
          tipoInicial: TipoCuenta.ahorro,
        ),
      ),
    );
    if (creada != true) return;
    await _cargarCuentas();
    if (!mounted) return;
    final nueva = _cuentas!.where((c) => !antes.contains(c.id)).firstOrNull;
    if (nueva != null) setState(() => _cuentaId = nueva.id);
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha != null && _fecha!.isAfter(hoy) ? _fecha! : DateTime(hoy.year, hoy.month + 6, hoy.day),
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 40),
      helpText: '¿Para cuándo lo quieres?',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar({bool? activo}) async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ponle un nombre, por ejemplo "Fondo de emergencia".');
      return;
    }
    final monto = Dinero.intentarDesdeTexto(_monto.text);
    if (monto == null || !monto.esPositivo) {
      setState(() => _error = 'Escribe cuánto quieres juntar, como 50,000.');
      return;
    }
    final cuentaId = _cuentaId;
    if (cuentaId == null) {
      setState(() => _error = 'Elige en qué cuenta de ahorro lo vas a juntar.');
      return;
    }
    setState(() => _guardando = true);
    final emoji = _emoji.text.trim().isEmpty ? '🎯' : _emoji.text.trim();
    final previo = widget.existente;
    final objetivo = previo == null
        ? Objetivo(
            id: const Uuid().v4(),
            nombre: nombre,
            emoji: emoji,
            monto: monto,
            cuentaId: cuentaId,
            creado: DateTime.now(),
            fechaLimite: _fecha,
          )
        : previo.copyWith(
            nombre: nombre,
            emoji: emoji,
            monto: monto,
            cuentaId: cuentaId,
            fechaLimite: () => _fecha,
            activo: activo,
          );
    await widget.objetivoRepositorio.guardar(objetivo);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cuentas = _cuentas;
    final previo = widget.existente;
    return PopScopeDescartar(
      hayCambiosSinGuardar: () =>
          !_guardando && (_nombre.text != (previo?.nombre ?? '') || (previo == null && _monto.text.isNotEmpty)),
      child: Scaffold(
        appBar: AppBar(title: Text(previo == null ? 'Nuevo objetivo' : 'Editar objetivo')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _emoji,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Ícono'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nombre,
                      autofocus: previo == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: '¿Para qué ahorras?', hintText: 'Fondo de emergencia'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: formateadoresDeMonto,
                decoration: const InputDecoration(labelText: '¿Cuánto quieres juntar?', prefixText: r'$ '),
              ),
              const SizedBox(height: 20),
              Text('¿Dónde lo juntas?', style: TextStyle(color: ColoresApp.medio)),
              const SizedBox(height: 8),
              if (cuentas == null)
                const LinearProgressIndicator()
              else if (cuentas.isEmpty)
                Text(
                  'Necesitas una cuenta de ahorro o inversión, o un apartado en tu débito: el avance del objetivo '
                  'es lo que haya en ella. Los apartados se crean desde el detalle de la cuenta.',
                  style: textos.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in cuentas)
                      ChoiceChip(
                        label: Text('${c.emoji} ${nombreConCuenta(c, _todas)}'),
                        selected: c.id == _cuentaId,
                        onSelected: (_) => setState(() => _cuentaId = c.id),
                      ),
                  ],
                ),
              if (cuentas != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _crearCuenta,
                    icon: const Icon(Icons.add),
                    label: Text(cuentas.isEmpty ? 'Crear cuenta de ahorro' : 'Otra cuenta de ahorro'),
                  ),
                ),
              if (cuentas != null && cuentas.isNotEmpty)
                Text(
                  'El avance es el saldo de esa cuenta. Si varios objetivos comparten cuenta, se llenan en orden.',
                  style: textos.labelSmall,
                ),
              const SizedBox(height: 20),
              Text('¿Para cuándo? (opcional)', style: TextStyle(color: ColoresApp.medio)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirFecha,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_fecha == null ? 'Elegir fecha' : '${fechaCorta(_fecha!)} ${_fecha!.year}'),
                    ),
                  ),
                  if (_fecha != null)
                    IconButton(
                      onPressed: () => setState(() => _fecha = null),
                      icon: const Icon(Icons.close),
                      tooltip: 'Sin fecha',
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Con fecha te decimos cuánto apartar por ciclo para llegar a tiempo.',
                style: textos.labelSmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: ColoresApp.coralTexto)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
              if (previo != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _guardando ? null : () => _guardar(activo: !previo.activo),
                  child: Text(previo.activo ? 'Archivar objetivo' : 'Volver a activarlo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
