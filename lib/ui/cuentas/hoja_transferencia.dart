import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/movimiento_cuenta.dart';
import '../comun/formato_dinero.dart';
import '../comun/tema.dart';

/// Pasar dinero de una cuenta a otra (spec §7.3.1): retirar efectivo,
/// mover entre débitos o pagar la tarjeta de crédito. No es un gasto.
/// `true` si se guardó.
Future<bool?> mostrarHojaTransferencia(
  BuildContext context, {
  required List<Cuenta> cuentas,
  required MovimientoCuentaRepositorio repositorio,
  String? origenId,
  String? destinoId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HojaTransferencia(
      cuentas: [for (final c in cuentas) if (c.activa) c],
      repositorio: repositorio,
      origenId: origenId,
      destinoId: destinoId,
    ),
  );
}

class _HojaTransferencia extends StatefulWidget {
  final List<Cuenta> cuentas;
  final MovimientoCuentaRepositorio repositorio;
  final String? origenId;
  final String? destinoId;

  const _HojaTransferencia({required this.cuentas, required this.repositorio, this.origenId, this.destinoId});

  @override
  State<_HojaTransferencia> createState() => _HojaTransferenciaState();
}

class _HojaTransferenciaState extends State<_HojaTransferencia> {
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  late String? _origen = widget.origenId ?? _primeraDe((c) => c.tipo == TipoCuenta.debito, excepto: widget.destinoId);
  late String? _destino =
      widget.destinoId ?? _primeraDe((c) => c.tipo != TipoCuenta.debito, excepto: _origen);
  String? _error;
  bool _guardando = false;

  /// Por omisión, del débito hacia lo demás (lo más común: retirar efectivo
  /// o pagar la tarjeta).
  String? _primeraDe(bool Function(Cuenta) condicion, {String? excepto}) {
    for (final c in widget.cuentas) {
      if (c.id != excepto && condicion(c)) return c.id;
    }
    for (final c in widget.cuentas) {
      if (c.id != excepto) return c.id;
    }
    return null;
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Cuenta? _cuenta(String? id) => widget.cuentas.where((c) => c.id == id).firstOrNull;

  Future<void> _guardar() async {
    final monto = Dinero.intentarDesdeTexto(_monto.text);
    if (_origen == null || _destino == null || _origen == _destino) {
      setState(() => _error = 'Elige dos cuentas distintas.');
      return;
    }
    if (monto == null || !monto.esPositivo) {
      setState(() => _error = 'Escribe cuánto, mayor a 0.');
      return;
    }
    setState(() => _guardando = true);
    await widget.repositorio.guardar(MovimientoCuenta(
      clientId: const Uuid().v4(),
      cuentaId: _origen!,
      cuentaDestinoId: _destino,
      fecha: DateTime.now(),
      monto: monto,
      tipo: TipoMovimientoCuenta.transferencia,
      entra: false,
      nota: _nota.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _fila(String titulo, String? elegida, ValueChanged<String> alElegir, {String? excepto}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: ColoresApp.medio)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.cuentas)
                if (c.id != excepto)
                  ChoiceChip(
                    label: Text('${c.emoji} ${c.nombre}'),
                    selected: c.id == elegida,
                    onSelected: (_) => alElegir(c.id),
                  ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final destino = _cuenta(_destino);
    final esPago = destino?.tipo == TipoCuenta.credito;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(esPago ? 'Pagar tarjeta' : 'Transferir', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              esPago
                  ? 'Baja el saldo de la cuenta de donde pagas. No cuenta como gasto: tus compras con la tarjeta ya se registraron.'
                  : 'Pasa dinero de una cuenta a otra. No cuenta como gasto.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _fila('De', _origen, (id) => setState(() {
                  _origen = id;
                  if (_destino == id) _destino = _primeraDe((c) => true, excepto: id);
                })),
            const SizedBox(height: 14),
            _fila('A', _destino, (id) => setState(() => _destino = id), excepto: _origen),
            const SizedBox(height: 14),
            TextField(
              controller: _monto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: formateadoresDeMonto,
              decoration: InputDecoration(labelText: '¿Cuánto?', prefixText: '\$ ', errorText: _error),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nota,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(esPago ? 'Registrar pago' : 'Transferir'),
            ),
          ],
        ),
      ),
    );
  }
}
