import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/firebase/servicio_auth.dart';
import 'tema.dart';

/// paquete-construccion-final.md §3: Google en ambas plataformas, para que
/// la cuenta sea la misma en iOS y Android. Apple Sign-In se agrega cuando
/// haya una Mac para compilar y probar la app en iOS.
class PantallaLogin extends StatefulWidget {
  final ServicioAuth servicioAuth;

  const PantallaLogin({super.key, required this.servicioAuth});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  bool _entrando = false;
  String? _error;

  Future<void> _entrarConGoogle() async {
    setState(() {
      _entrando = true;
      _error = null;
    });
    try {
      await widget.servicioAuth.iniciarSesionConGoogle();
      // authStateChanges() en main.dart reacciona sola; no hay que navegar.
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        setState(() => _entrando = false);
        return;
      }
      setState(() {
        _error = 'No se pudo entrar con Google (${e.code.name}).';
        _entrando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo entrar con Google. Intenta de nuevo.';
        _entrando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('💰', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'App de finanzas',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.tinta,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu cuenta protege tus datos y los sincroniza entre '
                  'tus dispositivos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.medio),
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ColoresApp.coralTexto),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _entrando ? null : _entrarConGoogle,
                  child: Text(_entrando ? 'Entrando…' : 'Continuar con Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
