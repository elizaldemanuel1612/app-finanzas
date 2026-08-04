import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/firebase/servicio_auth.dart';
import 'data/repositorios/local/categoria_repositorio_archivo.dart';
import 'data/repositorios/local/movimiento_repositorio_archivo.dart';
import 'data/repositorios/local/perfil_repositorio_archivo.dart';
import 'data/repositorios/local/reglas_aprendidas_repositorio_archivo.dart';
import 'domain/modelos/perfil.dart';
import 'firebase_options.dart';
import 'ui/comun/pantalla_configuracion_inicial.dart';
import 'ui/comun/pantalla_login.dart';
import 'ui/comun/tema.dart';
import 'ui/inicio/pantalla_inicio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La captura sigue siendo 100% local (data/repositorios/local/) — esto
  // solo conecta el proyecto para lo que viene después (Auth, Firestore).
  // Si falla (sin red, o algo mal configurado), la app sigue funcionando:
  // nada del flujo de captura depende de esto todavía.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await ServicioAuth.inicializar();
  } catch (e) {
    debugPrint('Firebase/Auth no se pudo inicializar: $e');
  }
  runApp(const AppFinanzas());
}

class AppFinanzas extends StatelessWidget {
  const AppFinanzas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Finanzas',
      theme: construirTema(),
      home: const _CompuertaAuth(),
    );
  }
}

/// Muestra el login mientras no haya sesión, y el contenido real de la app
/// en cuanto Firebase Auth confirme un usuario (paquete-construccion-final
/// .md §3: Google en ambas plataformas).
class _CompuertaAuth extends StatefulWidget {
  const _CompuertaAuth();

  @override
  State<_CompuertaAuth> createState() => _CompuertaAuthState();
}

class _CompuertaAuthState extends State<_CompuertaAuth> {
  final _servicioAuth = ServicioAuth();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _servicioAuth.cambiosDeUsuario,
      initialData: _servicioAuth.usuarioActual,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) {
          return PantallaLogin(servicioAuth: _servicioAuth);
        }
        return const _ContenidoApp();
      },
    );
  }
}

/// Arma los repositorios locales (interinos hasta que haya sincronización
/// real con Firestore, ver data/repositorios/local/) y decide si mostrar
/// la configuración inicial o la app.
class _ContenidoApp extends StatefulWidget {
  const _ContenidoApp();

  @override
  State<_ContenidoApp> createState() => _ContenidoAppState();
}

class _ContenidoAppState extends State<_ContenidoApp> {
  late final CategoriaRepositorioArchivo _categoriaRepositorio;
  late final MovimientoRepositorioArchivo _movimientoRepositorio;
  late final PerfilRepositorioArchivo _perfilRepositorio;
  late final ReglasAprendidasRepositorioArchivo _reglasAprendidasRepositorio;
  Future<Perfil?>? _perfil;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final directorio = await getApplicationDocumentsDirectory();
    _categoriaRepositorio =
        CategoriaRepositorioArchivo(File('${directorio.path}/categorias.json'));
    _movimientoRepositorio =
        MovimientoRepositorioArchivo(File('${directorio.path}/movimientos.json'));
    _perfilRepositorio = PerfilRepositorioArchivo(File('${directorio.path}/perfil.json'));
    _reglasAprendidasRepositorio =
        ReglasAprendidasRepositorioArchivo(File('${directorio.path}/reglas_aprendidas.json'));
    setState(() {
      _perfil = _perfilRepositorio.obtener();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FutureBuilder<Perfil?>(
      future: _perfil,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final perfil = snapshot.data;
        if (perfil == null) {
          return PantallaConfiguracionInicial(
            perfilRepositorio: _perfilRepositorio,
            alTerminar: () => setState(() {
              _perfil = _perfilRepositorio.obtener();
            }),
          );
        }
        return PantallaInicio(
          perfil: perfil,
          categoriaRepositorio: _categoriaRepositorio,
          movimientoRepositorio: _movimientoRepositorio,
          reglasAprendidasRepositorio: _reglasAprendidasRepositorio,
        );
      },
    );
  }
}
