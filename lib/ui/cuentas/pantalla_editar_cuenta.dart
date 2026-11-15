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

  /// Al crear: el tipo ya elegido (por ejemplo, ahorro desde el cierre del ciclo).
  final TipoCuenta? tipoInicial;

  const PantallaEditarCuenta({super.key, required this.cuentaRepositorio, this.existente, this.tipoInicial});

  @override
  State<PantallaEditarCuenta> createState() => _PantallaEditarCuentaState();
}

class _PantallaEditarCuentaState extends State<PantallaEditarCuenta> {
  late final _nombre = TextEditingController(text: widget.existente?.nombre ?? '');
  late final _emoji = TextEditingController(
    text: widget.existente?.emoji ?? (widget.tipoInicial == TipoCuenta.ahorro ? '🌱' : '💳'),
  );
  final _saldo = TextEditingController();
  late final _limite = TextEditingController(
    text: widget.existente?.limite == null ? '' : textoEditableDeDinero(widget.existente!.limite!),
  );
  late final _diaCorte = TextEditingController(text: widget.existente?.diaCorte?.toString() ?? '');
  late final _diaPago = TextEditingController(text: widget.existente?.diaPago?.toString() ?? '');
  late TipoCuenta _tipo = widget.existente?.tipo ?? widget.tipoInicial ?? TipoCuenta.debito;

  /// En efectivo y crédito llevar saldo es opcional: "traigo $800",
  /// "debo $3,000".
  late bool _llevaSaldoElegido = widget.existente?.llevaSaldo ?? false;
  String? _error;
  bool _guardando = false;

  /// El efectivo base no cambia de tipo: es "el efectivo".
  bool get _tipoFijo => widget.existente?.id == idCuentaEfectivo;

  bool get _llevaSaldo => _tipo.siempreLlevaSaldo || _llevaSaldoElegido;

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
    _diaCorte.dispose();
    _diaPago.dispose();
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
    // Corte y fecha de pago (spec §7.3.1): opcionales, pero van juntos.
    int? diaCorte;
    int? diaPago;
    if (_esCredito) {
      int? leerDia(TextEditingController c) {
        final n = int.tryParse(c.text.trim());
        return n != null && n >= 1 && n <= 31 ? n : null;
      }

      final hayCorte = _diaCorte.text.trim().isNotEmpty;
      final hayPago = _diaPago.text.trim().isNotEmpty;
      if (hayCorte || hayPago) {
        diaCorte = leerDia(_diaCorte);
        diaPago = leerDia(_diaPago);
        if (diaCorte == null || diaPago == null) {
          setState(() => _error = 'Escribe los dos días, del 1 al 31: el de corte y el límite de pago.');
          return;
        }
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
            diaCorte: diaCorte,
            diaPago: diaPago,
          )
        : previa.copyWith(
            nombre: nombre,
            emoji: emoji,
            tipo: _tipo,
            llevaSaldo: _llevaSaldoElegido,
            saldoInicial: saldo,
            fechaSaldoInicial: saldo == null ? null : ahora,
            limite: () => limite,
            diaCorte: () => diaCorte,
            diaPago: () => diaPago,
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
                // Sin la palomita: con cuatro tipos no cabría en un teléfono angosto.
                showSelectedIcon: false,
                onSelectionChanged: _tipoFijo
                    ? null
                    : (s) => setState(() {
                          _tipo = s.first;
                          // El emoji de fábrica sigue al tipo; uno elegido a mano se respeta.
                          if (_emoji.text == '💳' && _tipo == TipoCuenta.ahorro) _emoji.text = '🌱';
                          if (_emoji.text == '🌱' && _tipo != TipoCuenta.ahorro) _emoji.text = '💳';
                        }),
              ),
              const SizedBox(height: 8),
              Text(
                switch (_tipo) {
                  TipoCuenta.debito => 'Cada gasto con esta tarjeta se descuenta de su saldo, y puedes registrarle abonos.',
                  TipoCuenta.credito => 'Verás cuánto llevas gastado con ella en el ciclo y, si quieres, cuánto debes.',
                  TipoCuenta.efectivo => 'Si quieres, lleva la cuenta de cuánto traes.',
                  TipoCuenta.ahorro =>
                    'Tu ahorro o una inversión (fondo, CETES, afore…). No se paga con ella: le transfieres lo que '
                        'apartas y ajustas su valor cuando cambie. Cuenta para tu patrimonio.',
                },
                style: textos.bodySmall,
              ),
              if (!_tipo.siempreLlevaSaldo) ...[
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
                        : _tipo == TipoCuenta.ahorro
                            ? 'Lo que vale hoy, según tu banco o casa de bolsa.'
                            : 'Los gastos de antes de hoy no se descuentan.',
                    helperMaxLines: 2,
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
              if (_esCredito) ...[
                const SizedBox(height: 20),
                Text('Corte y pago (opcional)', style: textos.cuerpoFuerte),
                const SizedBox(height: 4),
                Text(
                  'Vienen en tu estado de cuenta. Con ellos te avisamos cuánto pagar y antes de qué día.',
                  style: textos.etiqueta,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _diaCorte,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Día de corte', hintText: '5'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _diaPago,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Día límite de pago', hintText: '25'),
                      ),
                    ),
                  ],
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
