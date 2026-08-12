import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/repositorios/perfil_repositorio.dart';
import '../../domain/modelos/perfil.dart';
import 'popscope_descartar.dart';
import 'tema.dart';

/// Lo mínimo que hace falta para que el resto de la app tenga sentido: el
/// día de corte de tarjeta (insumo de `CalculadoraCiclo`) y el ingreso
/// base. El onboarding real (app-finanzas-onboarding-*.html, con el "toma
/// 2 minutos" y la explicación de la marca de ritmo) es un pase de UX
/// posterior — esto solo desbloquea capturar y ver un ciclo.
class PantallaConfiguracionInicial extends StatefulWidget {
  final PerfilRepositorio perfilRepositorio;
  final VoidCallback alTerminar;

  const PantallaConfiguracionInicial({
    super.key,
    required this.perfilRepositorio,
    required this.alTerminar,
  });

  @override
  State<PantallaConfiguracionInicial> createState() =>
      _PantallaConfiguracionInicialState();
}

class _PantallaConfiguracionInicialState
    extends State<PantallaConfiguracionInicial> {
  final _diaCorteControlador = TextEditingController(text: '12');
  final _ingresoControlador = TextEditingController();
  String? _error;
  bool _guardando = false;

  bool get _hayCambiosSinGuardar =>
      _diaCorteControlador.text != '12' || _ingresoControlador.text.isNotEmpty;

  @override
  void dispose() {
    _diaCorteControlador.dispose();
    _ingresoControlador.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final diaCorte = int.tryParse(_diaCorteControlador.text.trim());
    final ingreso = Dinero.intentarDesdeTexto(_ingresoControlador.text);

    if (diaCorte == null || diaCorte < 1 || diaCorte > 31) {
      setState(
        () => _error = 'El día de corte debe ser un número entre 1 y 31.',
      );
      return;
    }
    if (ingreso == null || !ingreso.esPositivo) {
      setState(() => _error = 'Escribe tu ingreso mensual, ej. 87000.');
      return;
    }

    setState(() {
      _error = null;
      _guardando = true;
    });

    await widget.perfilRepositorio.guardar(
      Perfil(diaCorte: diaCorte, ingresoBaseMensual: ingreso),
    );

    if (!mounted) return;
    widget.alTerminar();
  }

  @override
  Widget build(BuildContext context) {
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Antes de empezar',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dos datos y ya puedes registrar tu primer gasto.',
                    style: TextStyle(color: ColoresApp.medio),
                  ),
                  const SizedBox(height: 32),
                  const Text('¿Qué día corta tu tarjeta?'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _diaCorteControlador,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Ej. 12'),
                  ),
                  const SizedBox(height: 20),
                  const Text('¿Cuánto es tu ingreso mensual?'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ingresoControlador,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: 'Ej. 87000'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: ColoresApp.coralTexto),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(_guardando ? 'Guardando…' : 'Empezar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
