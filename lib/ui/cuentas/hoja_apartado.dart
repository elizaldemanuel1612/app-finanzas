import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../domain/cuentas/apartados.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/movimiento_cuenta.dart';
import '../comun/formato_dinero.dart';
import '../comun/hoja.dart';
import '../comun/tema.dart';

const _uuid = Uuid();

/// Emojis para elegir rápido; el primero va por omisión.
const _emojis = ['🎯', '✈️', '🛟', '🏠', '🚗', '🎓', '🎁', '💍', '🩺', '🐶'];

/// Crea un apartado dentro de [padre] (spec-app-finanzas-v2.md §7.3.5):
/// nombre, emoji y, si quiere, lo que pasa de una vez desde [padre]. `true`
/// si se creó.
Future<bool?> mostrarHojaNuevoApartado(
  BuildContext context, {
  required Cuenta padre,
  required Dinero? disponible,
  required CuentaRepositorio cuentaRepositorio,
  required MovimientoCuentaRepositorio movimientoCuentaRepositorio,
}) =>
    mostrarHoja<bool>(
      context,
      builder: (_) => _HojaNuevoApartado(
        padre: padre,
        disponible: disponible,
        cuentaRepositorio: cuentaRepositorio,
        movimientoCuentaRepositorio: movimientoCuentaRepositorio,
      ),
    );

class _HojaNuevoApartado extends StatefulWidget {
  final Cuenta padre;
  final Dinero? disponible;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;

  const _HojaNuevoApartado({
    required this.padre,
    required this.disponible,
    required this.cuentaRepositorio,
    required this.movimientoCuentaRepositorio,
  });

  @override
  State<_HojaNuevoApartado> createState() => _HojaNuevoApartadoState();
}

class _HojaNuevoApartadoState extends State<_HojaNuevoApartado> {
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  String _emoji = _emojis.first;
  String? _error;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ponle un nombre, por ejemplo "Viaje".');
      return;
    }
    final texto = _monto.text.replaceAll(RegExp(r'[\$\s]'), '');
    final monto = texto.isEmpty ? const Dinero.cero() : Dinero.intentarDesdeTexto(texto);
    if (monto == null || monto.esNegativo) {
      setState(() => _error = 'Escribe cuánto guardas, por ejemplo 2,000.');
      return;
    }
    final apartado = nuevoApartado(
      padre: widget.padre,
      id: _uuid.v4(),
      nombre: nombre,
      emoji: _emoji,
      ahora: DateTime.now(),
    )!;
    setState(() => _guardando = true);
    await widget.cuentaRepositorio.guardar(apartado);
    if (monto.esPositivo) {
      await widget.movimientoCuentaRepositorio.guardar(MovimientoCuenta(
        clientId: _uuid.v4(),
        cuentaId: widget.padre.id,
        cuentaDestinoId: apartado.id,
        fecha: DateTime.now(),
        monto: monto,
        tipo: TipoMovimientoCuenta.transferencia,
        entra: false,
      ));
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final disponible = widget.disponible;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nuevo apartado en ${widget.padre.nombre}', style: textos.seccion),
            const SizedBox(height: 4),
            Text(
              'Separa dinero para algo, como en tu banco. Lo que guardes deja de estar disponible en '
              '${widget.padre.nombre}, pero sigue siendo tuyo.',
              style: textos.etiqueta,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Viaje, fondo de emergencia…'),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _emojis)
                  ChoiceChip(
                    label: Text(e),
                    selected: _emoji == e,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _monto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: formateadoresDeMonto,
              decoration: InputDecoration(
                labelText: '¿Cuánto guardas ahora? (opcional)',
                prefixText: r'$ ',
                helperText: disponible == null ? null : 'Tienes ${enPesos(disponible)} disponibles en ${widget.padre.nombre}.',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: textos.etiqueta.copyWith(color: ColoresApp.actual.peligroTexto)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _guardando ? null : _guardar, child: const Text('Crear apartado')),
          ],
        ),
      ),
    );
  }
}
