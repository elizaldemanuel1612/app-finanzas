import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/firebase/servicio_auth.dart';
import '../../data/nube/errores_respaldo.dart';
import '../../data/seguridad/candado.dart';
import '../../domain/seguridad/politica_bloqueo.dart';
import '../../plataforma/biometria.dart';
import '../comun/marca.dart';
import '../comun/tema.dart';
import 'captura_pin.dart';
import 'pantalla_crear_pin.dart';

/// Lo primero que se ve al abrir la app (spec-app-finanzas-v2.md §7.3):
/// Face ID / huella, PIN o contraseña, según lo que eligió el usuario. Una
/// vez por semana pide el PIN aunque use otro método. "¿Olvidaste tu PIN?"
/// confirma la cuenta de Google (el correo del usuario) y deja crear uno
/// nuevo.
class PantallaDesbloqueo extends StatefulWidget {
  final Candado candado;
  final ServicioAuth servicioAuth;
  final VoidCallback alDesbloquear;

  /// Para pruebas: sin biometría real.
  final Future<bool> Function()? biometriaDisponible;
  final Future<bool> Function()? autenticarBiometria;

  const PantallaDesbloqueo({
    super.key,
    required this.candado,
    required this.servicioAuth,
    required this.alDesbloquear,
    this.biometriaDisponible,
    this.autenticarBiometria,
  });

  @override
  State<PantallaDesbloqueo> createState() => _PantallaDesbloqueoState();
}

class _PantallaDesbloqueoState extends State<PantallaDesbloqueo> {
  EstadoCandado? _estado;
  bool _hayBiometria = false;
  String _nombreBiometria = 'Face ID';
  MetodoDesbloqueo? _usando;
  String? _error;
  bool _recuperando = false;
  Timer? _reloj;
  final _contrasena = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar(primeraVez: true);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool primeraVez = false}) async {
    final estado = await widget.candado.estado();
    final hay = await (widget.biometriaDisponible ?? Biometria.disponible)();
    final nombre = hay && widget.biometriaDisponible == null ? await Biometria.nombre() : 'Face ID';
    if (!mounted) return;
    setState(() {
      _estado = estado;
      _hayBiometria = hay;
      _nombreBiometria = nombre;
      _usando ??= _metodoInicial(estado, hay);
    });
    _programarReloj(estado);
    if (primeraVez && _usando == MetodoDesbloqueo.biometria) await _biometria();
  }

  /// La semana del PIN manda; luego lo que eligió el usuario, si se puede.
  MetodoDesbloqueo _metodoInicial(EstadoCandado e, bool hayBiometria) {
    if (e.tocaPin) return MetodoDesbloqueo.pin;
    if (e.metodo == MetodoDesbloqueo.biometria && !hayBiometria) return MetodoDesbloqueo.pin;
    if (e.metodo == MetodoDesbloqueo.contrasena && !e.tieneContrasena) return MetodoDesbloqueo.pin;
    return e.metodo;
  }

  /// Mientras haya que esperar, refresca cada segundo para mostrar cuánto falta.
  void _programarReloj(EstadoCandado e) {
    _reloj?.cancel();
    if (e.esperarHasta == null) return;
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) async {
      final nuevo = await widget.candado.estado();
      if (!mounted) return;
      setState(() => _estado = nuevo);
      if (nuevo.esperarHasta == null) _reloj?.cancel();
    });
  }

  Future<void> _biometria() async {
    final bien = await (widget.autenticarBiometria ?? Biometria.autenticar)();
    if (!mounted) return;
    if (bien) {
      await widget.candado.registrarBiometria();
      widget.alDesbloquear();
    } else {
      setState(() => _error = 'No te reconocí. Usa tu PIN.');
    }
  }

  Future<void> _probarPin(String pin) async {
    final bien = await widget.candado.probarPin(pin);
    if (!mounted) return;
    if (bien) {
      widget.alDesbloquear();
      return;
    }
    await _alFallar('PIN incorrecto.');
  }

  Future<void> _probarContrasena() async {
    final bien = await widget.candado.probarContrasena(_contrasena.text);
    if (!mounted) return;
    if (bien) {
      widget.alDesbloquear();
      return;
    }
    _contrasena.clear();
    await _alFallar('Contraseña incorrecta.');
  }

  Future<void> _alFallar(String mensaje) async {
    final estado = await widget.candado.estado();
    if (!mounted) return;
    setState(() {
      _estado = estado;
      _error = estado.requiereRecuperar ? null : mensaje;
    });
    _programarReloj(estado);
  }

  /// La ventana de Google sale directo del toque (Safari la bloquea si no).
  void _recuperar() {
    final confirmacion = widget.servicioAuth.reautenticar();
    setState(() => _recuperando = true);
    confirmacion.then((_) async {
      await widget.candado.reiniciar();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PopScope(
            canPop: false,
            child: PantallaCrearPin(
              candado: widget.candado,
              explicacion: 'Tu cuenta quedó confirmada. Elige un PIN nuevo.',
              alTerminar: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
      widget.alDesbloquear();
    }, onError: (Object e) {
      if (!mounted) return;
      setState(() => _recuperando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo confirmar tu cuenta. ${describirErrorRespaldo(e)}')),
      );
    });
  }

  void _preguntarRecuperar() {
    showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Olvidaste tu PIN?'),
        content: Text(
          'Confirma tu cuenta de Google (${widget.servicioAuth.usuarioActual?.email ?? 'tu correo'}) '
          'y crea un PIN nuevo. Tus datos no se tocan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(contexto);
              _recuperar();
            },
            child: const Text('Confirmar con Google'),
          ),
        ],
      ),
    );
  }

  String _cuantoFalta(DateTime hasta) {
    final falta = hasta.difference(DateTime.now());
    if (falta.inMinutes >= 1) return '${falta.inMinutes + 1} min';
    return '${falta.inSeconds + 1} s';
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    final textos = Theme.of(context).textTheme;
    if (estado == null || _recuperando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final esperando = estado.esperarHasta;
    final usando = _usando!;
    final aviso = estado.requiereRecuperar
        ? 'Demasiados intentos. Para entrar, confirma tu cuenta de Google.'
        : esperando != null
            ? 'Demasiados intentos. Vuelve a intentar en ${_cuantoFalta(esperando)}.'
            : _error;

    final Widget centro = switch (usando) {
      MetodoDesbloqueo.pin || MetodoDesbloqueo.biometria when estado.requiereRecuperar => const SizedBox.shrink(),
      MetodoDesbloqueo.contrasena => Column(
          children: [
            Text('Escribe tu contraseña', style: textos.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _contrasena,
              obscureText: true,
              autofocus: true,
              enabled: esperando == null && !estado.requiereRecuperar,
              onSubmitted: (_) => _probarContrasena(),
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 8),
            if (aviso != null) Text(aviso, style: textos.bodySmall?.copyWith(color: ColoresApp.coralTexto)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: esperando == null && !estado.requiereRecuperar ? _probarContrasena : null,
              child: const Text('Entrar'),
            ),
          ],
        ),
      MetodoDesbloqueo.biometria => Column(
          children: [
            Icon(Icons.face_retouching_natural, size: 56, color: ColoresApp.azul),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _biometria, child: Text('Usar $_nombreBiometria')),
            if (aviso != null) ...[
              const SizedBox(height: 12),
              Text(aviso, style: textos.bodySmall?.copyWith(color: ColoresApp.coralTexto)),
            ],
          ],
        ),
      MetodoDesbloqueo.pin => CapturaPin(
          titulo: 'Escribe tu PIN',
          subtitulo: estado.tocaPin && estado.metodo != MetodoDesbloqueo.pin
              ? 'Una vez por semana te lo pedimos para que no lo olvides.'
              : null,
          error: aviso,
          habilitado: esperando == null,
          alCompletar: _probarPin,
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmblemaApp(tamano: 64),
                  const SizedBox(height: 20),
                  if (estado.requiereRecuperar)
                    Text(aviso!, textAlign: TextAlign.center, style: textos.bodySmall?.copyWith(color: ColoresApp.coralTexto)),
                  centro,
                  const SizedBox(height: 16),
                  if (!estado.tocaPin && usando != MetodoDesbloqueo.pin)
                    TextButton(
                      onPressed: () => setState(() {
                        _usando = MetodoDesbloqueo.pin;
                        _error = null;
                      }),
                      child: const Text('Usar mi PIN'),
                    ),
                  if (!estado.tocaPin &&
                      usando == MetodoDesbloqueo.pin &&
                      estado.metodo == MetodoDesbloqueo.biometria &&
                      _hayBiometria)
                    TextButton(
                      onPressed: () {
                        setState(() => _usando = MetodoDesbloqueo.biometria);
                        _biometria();
                      },
                      child: Text('Usar $_nombreBiometria'),
                    ),
                  if (!estado.tocaPin &&
                      usando == MetodoDesbloqueo.pin &&
                      estado.metodo == MetodoDesbloqueo.contrasena &&
                      estado.tieneContrasena)
                    TextButton(
                      onPressed: () => setState(() => _usando = MetodoDesbloqueo.contrasena),
                      child: const Text('Usar mi contraseña'),
                    ),
                  TextButton(
                    onPressed: _preguntarRecuperar,
                    child: Text(estado.requiereRecuperar ? 'Confirmar mi cuenta de Google' : '¿Olvidaste tu PIN?'),
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
