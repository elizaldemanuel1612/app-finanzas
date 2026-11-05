import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/guia_rapida.dart';
import '../comun/tema.dart';
import 'hoja_transferencia.dart';
import 'pantalla_detalle_cuenta.dart';
import 'pantalla_editar_cuenta.dart';

/// Ajustes → Tus cuentas (spec-app-finanzas-v2.md §7.3.1): tarjetas y
/// efectivo, con el saldo de las que lo llevan.
class PantallaCuentas extends StatefulWidget {
  final Perfil perfil;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;

  const PantallaCuentas({
    super.key,
    required this.perfil,
    required this.cuentaRepositorio,
    required this.movimientoRepositorio,
    required this.movimientoCuentaRepositorio,
    required this.ingresoExtraRepositorio,
  });

  @override
  State<PantallaCuentas> createState() => _PantallaCuentasState();
}

class _PantallaCuentasState extends State<PantallaCuentas> {
  List<(Cuenta, Dinero?)>? _cuentas;
  Dinero _total = const Dinero.cero();
  bool _verArchivadas = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarGuiaRapidaPrimeraVez(context, GuiaRapida.cuentas));
  }

  Future<void> _cargar() async {
    final cuentas = await widget.cuentaRepositorio.listarTodas();
    final gastos = await widget.movimientoRepositorio.listarTodos();
    final abonos = await widget.movimientoCuentaRepositorio.listarTodos();
    if (!mounted) return;
    setState(() {
      _cuentas = [for (final c in cuentas) (c, saldoDe(c, gastos, abonos))];
      _total = sumaDeSaldos(cuentas, gastos, abonos);
    });
  }

  Future<void> _transferir() async {
    final hecha = await mostrarHojaTransferencia(
      context,
      cuentas: [for (final (c, _) in _cuentas ?? const <(Cuenta, Dinero?)>[]) c],
      repositorio: widget.movimientoCuentaRepositorio,
    );
    if (hecha == true) await _cargar();
  }

  Future<void> _nueva() async {
    final creada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaEditarCuenta(cuentaRepositorio: widget.cuentaRepositorio)),
    );
    if (creada == true) await _cargar();
  }

  Future<void> _abrir(Cuenta cuenta) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalleCuenta(
          cuenta: cuenta,
          perfil: widget.perfil,
          cuentaRepositorio: widget.cuentaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        ),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final cuentas = _cuentas;
    final textos = Theme.of(context).textTheme;
    final activas = [for (final c in cuentas ?? const <(Cuenta, Dinero?)>[]) if (c.$1.activa) c];
    final archivadas = [for (final c in cuentas ?? const <(Cuenta, Dinero?)>[]) if (!c.$1.activa) c];
    return Scaffold(
      appBar: AppBar(title: const Text('Tus cuentas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _nueva,
        tooltip: 'Nueva cuenta',
        child: const Icon(Icons.add),
      ),
      body: cuentas == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total en tus cuentas', style: textos.bodySmall),
                        Text(
                          _total.formateado(),
                          style: textos.displaySmall?.copyWith(color: _total.esNegativo ? ColoresApp.coralTexto : null),
                        ),
                        Text('Suma de las que llevan saldo; las de crédito no entran.', style: textos.labelSmall),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: activas.length < 2 ? null : _transferir,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Transferir o pagar tarjeta'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Al registrar un gasto eliges con cuál pagaste. Las de débito llevan su saldo.',
                  style: textos.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final (c, saldo) in activas) _FilaCuenta(cuenta: c, saldo: saldo, alTocar: () => _abrir(c)),
                if (archivadas.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => setState(() => _verArchivadas = !_verArchivadas),
                    child: Text('${_verArchivadas ? 'Ocultar' : 'Ver'} archivadas (${archivadas.length})'),
                  ),
                  if (_verArchivadas)
                    for (final (c, saldo) in archivadas) _FilaCuenta(cuenta: c, saldo: saldo, alTocar: () => _abrir(c)),
                ],
              ],
            ),
    );
  }
}

class _FilaCuenta extends StatelessWidget {
  final Cuenta cuenta;
  final Dinero? saldo;
  final VoidCallback alTocar;

  const _FilaCuenta({required this.cuenta, required this.saldo, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final s = saldo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: alTocar,
        leading: ExcludeSemantics(child: Text(cuenta.emoji, style: Theme.of(context).textTheme.titleMedium)),
        title: Text(cuenta.nombre),
        subtitle: Text(
          cuenta.tipo == TipoCuenta.debito && !cuenta.llevaSaldo ? 'Débito · define su saldo' : cuenta.tipo.etiqueta,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s != null)
              Text(
                s.formateado(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: s.esNegativo ? ColoresApp.coralTexto : ColoresApp.tinta,
                ),
              ),
            Icon(Icons.chevron_right, color: ColoresApp.medio),
          ],
        ),
      ),
    );
  }
}
