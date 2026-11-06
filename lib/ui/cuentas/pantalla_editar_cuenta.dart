import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../domain/modelos/cuenta.dart';
import '../comun/formato_dinero.dart';
import '../comun/popscope_descartar.dart';
import '../comun/tema.dart';

/// Alta o edición de una cuenta (spec-app-finanzas-v2.md §7.3.1). El saldo
/// solo se pide al crearla o al empezar a llevarlo; después se corrige con
/// "Ajustar saldo", que deja rastro.
class PantallaEditarCuenta extends StatefulWidget {
  final CuentaRepositorio cuentaRepositorio;
  final Cuenta? existente;

  const PantallaEditarCuenta({super.key, required this.cuentaRepositorio, this.existente});

  @override
  State<PantallaEditarCuenta> createState() => _PantallaEditarCuentaState();
}

class _PantallaEditarCuentaState extends State<PantallaEditarCuenta> {
  late final _nombre = TextEditingController(text: widget.existente?.nombre ?? '');
  late final _emoji = TextEditingController(text: widget.existente?.emoji ?? '💳');
  final _saldo = TextEditingController();
  late final _limite = TextEditingController(
    text: widget.existente?.limite == null ? '' : textoEditableDeDinero(widget.existente!.limite!),
  );
  late TipoCuenta _tipo = widget.existente?.tipo ?? TipoCuenta.debito;

  /// En efectivo y crédito llevar saldo es opcional: "traigo $800",
  /// "debo $3,000".
  late bool _llevaSaldoElegido = widget.existente?.llevaSaldo ?? false;
  String? _error;
  bool _guardando = false;

  /// El efectivo base no cambia de tipo: es "el efectivo".
  bool get _tipoFijo => widget.existente?.id == idCuentaEfectivo;

  bool get _llevaSaldo => switch (_tipo) {
        TipoCuenta.debito => true,
        TipoCuenta.credito || TipoCuenta.efectivo => _llevaSaldoElegido,
      };

  /// Pedir saldo: al crear, o si antes no llevaba (o era de otro tipo) y
  /// ahora sí. En crédito lo que se pide es lo que se debe.
  bool get _pideSaldo {
    final previa = widget.existente;
    return _llevaSaldo && (previa == null || !previa.llevaSaldo || (previa.tipo == TipoCuenta.credito) != _esCredito);
  }

  bool get _esCredito => _tipo == TipoCuenta.credito;

  @override
  void dispose() {
    _nombre.dispose();
    _emoji.dispose();
    _saldo.dispose();
    _limite.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ponle un nombre, por ejemplo "BBVA débito".');
      return;
    }
    Dinero? saldo;
    if (_pideSaldo) {
      saldo = _saldo.text.trim().isEmpty ? const Dinero.cero() : Dinero.intentarDesdeTexto(_saldo.text);
      if (saldo == null) {
        setState(() => _error = 'Escribe el saldo con números, como 2500.00.');
        return;
      }
      // En crédito el saldo es negativo mientras se debe (saldos.dart).
      if (_esCredito) saldo = Dinero(-saldo.centavos);
    }
    Dinero? limite;
    if (_esCredito && _llevaSaldo && _limite.text.trim().isNotEmpty) {
      limite = Dinero.intentarDesdeTexto(_limite.text);
      if (limite == null) {
        setState(() => _error = 'Escribe el límite con números, como 30,000.');
        return;
      }
    }
    setState(() => _guardando = true);
    final ahora = DateTime.now();
    final previa = widget.existente;
    final emoji = _emoji.text.trim().isEmpty ? '💳' : _emoji.text.trim();
    final cuenta = previa == null
        ? Cuenta(
            id: const Uuid().v4(),
            nombre: nombre,
            emoji: emoji,
            tipo: _tipo,
            llevaSaldo: _llevaSaldo,
            saldoInicial: saldo ?? const Dinero.cero(),
            fechaSaldoInicial: ahora,
            limite: limite,
          )
        : previa.copyWith(
            nombre: nombre,
            emoji: emoji,
            tipo: _tipo,
            llevaSaldo: _llevaSaldoElegido,
            saldoInicial: saldo,
            fechaSaldoInicial: saldo == null ? null : ahora,
            limite: () => limite,
          );
    await widget.cuentaRepositorio.guardar(cuenta);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => !_guardando && (_nombre.text != (widget.existente?.nombre ?? '') || _saldo.text.isNotEmpty),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.existente == null ? 'Nueva cuenta' : 'Editar cuenta')),
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
                      autofocus: widget.existente == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'BBVA débito'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Tipo', style: TextStyle(color: ColoresApp.medio)),
              const SizedBox(height: 8),
              SegmentedButton<TipoCuenta>(
                segments: [
                  for (final t in TipoCuenta.values) ButtonSegment(value: t, label: Text(t.etiqueta)),
                ],
                selected: {_tipo},
                onSelectionChanged: _tipoFijo ? null : (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_tipo) {
                  TipoCuenta.debito => 'Cada gasto con esta tarjeta se descuenta de su saldo, y puedes registrarle abonos.',
                  TipoCuenta.credito => 'Verás cuánto llevas gastado con ella en el ciclo y, si quieres, cuánto debes.',
                  TipoCuenta.efectivo => 'Si quieres, lleva la cuenta de cuánto traes.',
                },
                style: textos.bodySmall,
              ),
              if (_tipo != TipoCuenta.debito) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_esCredito ? 'Llevar lo que debes' : 'Llevar saldo'),
                  subtitle: Text(
                    _esCredito ? 'Cada gasto lo sube; tus pagos lo bajan' : 'Por ejemplo, "traigo \$800"',
                  ),
                  value: _llevaSaldoElegido,
                  onChanged: (v) => setState(() => _llevaSaldoElegido = v),
                ),
              ],
              if (_pideSaldo) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _saldo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: formateadoresDeMonto,
                  decoration: InputDecoration(
                    labelText: _esCredito ? '¿Cuánto debes hoy?' : '¿Cuánto tienes hoy?',
                    prefixText: '\$ ',
                    helperText: _esCredito
                        ? 'Lo de tu app del banco. Los gastos de antes de hoy no se suman.'
                        : 'Los gastos de antes de hoy no se descuentan.',
                  ),
                ),
              ],
              if (_esCredito && _llevaSaldo) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _limite,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: formateadoresDeMonto,
                  decoration: const InputDecoration(
                    labelText: 'Límite de crédito (opcional)',
                    prefixText: '\$ ',
                    helperText: 'Para ver cuánto te queda disponible.',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: ColoresApp.coralTexto)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}
