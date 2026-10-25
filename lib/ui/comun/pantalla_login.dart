import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/firebase/servicio_auth.dart';
import 'marca.dart';
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
    final textos = Theme.of(context).textTheme;
    // Fondo oscuro: íconos de la barra de estado en blanco.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: ColoresApp.azul,
      body: FondoMontanas(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                const Center(child: EmblemaApp(tamano: 128)),
                const SizedBox(height: 28),
                Text(
                  'App de finanzas',
                  textAlign: TextAlign.center,
                  style: textos.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu cuenta protege tus datos y los sincroniza entre '
                  'tus dispositivos.',
                  textAlign: TextAlign.center,
                  style: textos.bodyMedium?.copyWith(color: const Color(0xFFC9D1E3)),
                ),
                const Spacer(flex: 3),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ColoresApp.coralSuave,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresApp.coralTexto),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ColoresApp.azul,
                    disabledBackgroundColor: Colors.white70,
                  ),
                  onPressed: _entrando ? null : _entrarConGoogle,
                  child: Text(_entrando ? 'Entrando…' : 'Continuar con Google'),
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
