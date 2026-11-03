import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../data/seguridad/candado.dart';
import '../../domain/seguridad/politica_bloqueo.dart';
import '../../plataforma/biometria.dart';
import '../comun/tema.dart';
import 'pantalla_crear_pin.dart';

/// Ajustes → Seguridad (spec-app-finanzas-v2.md §7.3): con qué se desbloquea
/// la app, cambiar el PIN y crear o cambiar la contraseña.
class PantallaSeguridad extends StatefulWidget {
  final Candado candado;

  const PantallaSeguridad({super.key, required this.candado});

  @override
  State<PantallaSeguridad> createState() => _PantallaSeguridadState();
}

class _PantallaSeguridadState extends State<PantallaSeguridad> {
  EstadoCandado? _estado;
  bool _hayBiometria = false;
  String _nombreBiometria = 'Face ID';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final estado = await widget.candado.estado();
    final hay = await Biometria.disponible();
    final nombre = hay ? await Biometria.nombre() : 'Face ID';
    if (!mounted) return;
    setState(() {
      _estado = estado;
      _hayBiometria = hay;
      _nombreBiometria = nombre;
    });
  }

  Future<void> _elegir(MetodoDesbloqueo metodo) async {
    if (metodo == MetodoDesbloqueo.biometria) {
      // Que funcione antes de depender de ella.
      if (!await Biometria.autenticar()) return;
    }
    if (metodo == MetodoDesbloqueo.contrasena && !_estado!.tieneContrasena) {
      if (!await _definirContrasena()) return;
    }
    await widget.candado.elegirMetodo(metodo);
    await _cargar();
  }

  Future<void> _cambiarPin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (contexto) => PantallaCrearPin(
          candado: widget.candado,
          pedirActual: true,
          alTerminar: () {
            Navigator.of(contexto).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listo, tu PIN cambió.')));
          },
        ),
      ),
    );
    await _cargar();
  }

  /// `true` si quedó guardada.
  Future<bool> _definirContrasena() async {
    final guardada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoContrasena(candado: widget.candado),
    );
    await _cargar();
    return guardada == true;
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: estado == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Desbloquear la app con', style: textos.titleMedium),
                const SizedBox(height: 8),
                RadioGroup<MetodoDesbloqueo>(
                  groupValue: estado.metodo,
                  onChanged: (m) {
                    if (m != null) _elegir(m);
                  },
                  child: Column(
                    children: [
                      RadioListTile<MetodoDesbloqueo>(
                        value: MetodoDesbloqueo.biometria,
                        enabled: _hayBiometria,
                        title: Text(_hayBiometria ? _nombreBiometria : 'Face ID o huella'),
                        subtitle: Text(_hayBiometria ? 'El más rápido' : 'Solo en la app del teléfono'),
                      ),
                      const RadioListTile<MetodoDesbloqueo>(
                        value: MetodoDesbloqueo.pin,
                        title: Text('PIN de 6 números'),
                      ),
                      const RadioListTile<MetodoDesbloqueo>(
                        value: MetodoDesbloqueo.contrasena,
                        title: Text('Contraseña'),
                        subtitle: Text('Letras y números'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu PIN siempre está de respaldo, y una vez por semana te lo pedimos para que no lo olvides. '
                  'Si lo olvidas, lo recuperas confirmando tu cuenta de Google.',
                  style: textos.bodySmall,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.pin_outlined, color: ColoresApp.tinta),
                        title: const Text('Cambiar PIN'),
                        trailing: Icon(Icons.chevron_right, color: ColoresApp.medio),
                        onTap: _cambiarPin,
                      ),
                      ListTile(
                        leading: Icon(Icons.password_rounded, color: ColoresApp.tinta),
                        title: Text(estado.tieneContrasena ? 'Cambiar contraseña' : 'Crear contraseña'),
                        trailing: Icon(Icons.chevron_right, color: ColoresApp.medio),
                        onTap: _definirContrasena,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DialogoContrasena extends StatefulWidget {
  final Candado candado;

  const _DialogoContrasena({required this.candado});

  @override
  State<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<_DialogoContrasena> {
  final _una = TextEditingController();
  final _otra = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _una.dispose();
    _otra.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    switch (validarContrasenaNueva(_una.text)) {
      case Falla(:final mensaje):
        setState(() => _error = mensaje);
        return;
      case Exito():
    }
    if (_una.text != _otra.text) {
      setState(() => _error = 'No coinciden.');
      return;
    }
    await widget.candado.definirContrasena(_una.text);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tu contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _una,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otra,
            obscureText: true,
            onSubmitted: (_) => _guardar(),
            decoration: InputDecoration(labelText: 'Repítela', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
