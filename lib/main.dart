import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'data/firebase/servicio_auth.dart';
import 'data/repositorios/local/almacen_local.dart';
import 'domain/modelos/perfil.dart';
import 'firebase_options.dart';
import 'ui/comun/pantalla_login.dart';
import 'ui/comun/tema.dart';
import 'ui/inicio/pantalla_inicio.dart';
import 'ui/onboarding/pantalla_onboarding.dart';

const _licenciasFuentes = {
  'Outfit': 'assets/fuentes/OFL-Outfit.txt',
  'PlusJakartaSans': 'assets/fuentes/OFL-PlusJakartaSans.txt',
};

/// Registra el SIL OFL 1.1 de Outfit y Plus Jakarta Sans (Fase 6, Bloque 3)
/// en la página "Licencias de código abierto" de la app — obligatorio por
/// los términos de esa licencia, no cosmético.
void _registrarLicenciasDeFuentes() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in _licenciasFuentes.entries) {
      final texto = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], texto);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registrarLicenciasDeFuentes();
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
      title: 'FinVita',
      theme: construirTema(),
      // Fijo, no el del sistema — mismo criterio que la moneda (es_MX):
      // las cifras y el calendario no deben cambiar de formato entre equipos.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es', 'MX')],
      locale: const Locale('es', 'MX'),
      // El teclado numérico de iOS no trae tecla para cerrarse (el de
      // Android sí) y tapa "Listo" en las pantallas de captura: tocar fuera
      // de un campo lo cierra, como en las apps nativas. Los toques sobre
      // botones y chips los ganan ellos, así que no se pierden.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
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
        return _ContenidoApp(servicioAuth: _servicioAuth);
      },
    );
  }
}

/// Arma los repositorios locales (interinos hasta que haya sincronización
/// real con Firestore, ver data/repositorios/local/) y decide si mostrar
/// la configuración inicial o la app.
class _ContenidoApp extends StatefulWidget {
  final ServicioAuth servicioAuth;

  const _ContenidoApp({required this.servicioAuth});

  @override
  State<_ContenidoApp> createState() => _ContenidoAppState();
}

class _ContenidoAppState extends State<_ContenidoApp> {
  late final AlmacenLocal _almacenLocal;
  Future<Perfil?>? _perfil;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    // El uid se lee aquí, antes del primer `await` — en el mismo tick
    // síncrono en el que `_CompuertaAuth` decidió construir `_ContenidoApp`
    // porque había un usuario. Leerlo después de un `await` (como estaba
    // antes) deja una ventana real donde un cierre de sesión concurrente
    // vuelve `usuarioActual` null y `!.uid` truena con un null-check.
    final uid = widget.servicioAuth.usuarioActual!.uid;
    final base = await getApplicationDocumentsDirectory();
    // Namespace por cuenta (hallazgo de seguridad, Fase 6): antes los 6 JSON
    // y las fotos de tickets vivían sueltos en `base`, sin distinguir de
    // qué cuenta de Google eran. "Cerrar sesión" preserva los datos a
    // propósito (§ el botón de Ajustes) para volver a entrar con la misma
    // cuenta — pero sin este namespace, CUALQUIER cuenta de Google que
    // iniciara sesión en el mismo dispositivo veía y sobrescribía esos
    // mismos archivos. Cada cuenta ahora vive en `usuarios/<uid>/`, y
    // "Eliminar cuenta" (`AlmacenLocal.borrarTodo`) solo puede alcanzar la
    // carpeta de la cuenta activa, no la de otras cuentas en el mismo
    // dispositivo.
    final directorio = Directory('${base.path}/usuarios/$uid');
    await _migrarDatosDeAntesDeSepararPorCuenta(base, directorio);
    _almacenLocal = AlmacenLocal(directorio);
    setState(() {
      _perfil = _almacenLocal.perfil.obtener();
    });
  }

  /// Migración de una sola vez: adopta los archivos sueltos del esquema
  /// viejo (sin namespace) hacia la primera cuenta que inicie sesión
  /// después de este cambio. No hay forma de saber retroactivamente de qué
  /// cuenta eran esos datos — y preservar el historial ya capturado importa
  /// más que la atribución exacta. Cuentas nuevas después de esta migración
  /// nunca ven estos archivos sueltos, porque quedan renombrados (movidos)
  /// fuera de `base` en cuanto la primera cuenta los adopta.
  Future<void> _migrarDatosDeAntesDeSepararPorCuenta(Directory base, Directory destino) async {
    if (await destino.exists()) return;
    final archivosSueltos = [
      for (final nombre in AlmacenLocal.nombresDeArchivo) File('${base.path}/$nombre'),
    ].where((archivo) => archivo.existsSync()).toList();
    final ticketsSueltos = Directory('${base.path}/tickets');
    final hayTicketsSueltos = await ticketsSueltos.exists();
    if (archivosSueltos.isEmpty && !hayTicketsSueltos) return;

    await destino.create(recursive: true);
    for (final archivo in archivosSueltos) {
      final nombre = archivo.path.replaceAll('\\', '/').split('/').last;
      await archivo.rename('${destino.path}/$nombre');
    }
    if (hayTicketsSueltos) {
      await ticketsSueltos.rename('${destino.path}/tickets');
      // Las rutas de `Movimiento.fotoUrl` guardadas antes de esta migración
      // son absolutas y apuntaban a `base/tickets/...` — mover la carpeta
      // sin esto dejaría esas fotos "rotas" (archivo ya no existe en la
      // ruta que el JSON recuerda).
      await _reescribirRutasDeFotos(base, destino);
    }
  }

  Future<void> _reescribirRutasDeFotos(Directory base, Directory destino) async {
    final archivo = File('${destino.path}/movimientos.json');
    if (!await archivo.exists()) return;
    final contenido = await archivo.readAsString();
    if (contenido.trim().isEmpty) return;
    final items = (jsonDecode(contenido) as List<dynamic>).cast<Map<String, dynamic>>();
    var cambiado = false;
    for (final item in items) {
      final fotoUrl = item['fotoUrl'] as String?;
      if (fotoUrl != null && fotoUrl.startsWith(base.path)) {
        item['fotoUrl'] = fotoUrl.replaceFirst(base.path, destino.path);
        cambiado = true;
      }
    }
    if (!cambiado) return;
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(jsonEncode(items));
    await temporal.rename(archivo.path);
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
          return PantallaOnboarding(
            perfilRepositorio: _almacenLocal.perfil,
            categoriaRepositorio: _almacenLocal.categorias,
            movimientoRepositorio: _almacenLocal.movimientos,
            alTerminar: () => setState(() {
              _perfil = _almacenLocal.perfil.obtener();
            }),
          );
        }
        return PantallaInicio(
          perfil: perfil,
          categoriaRepositorio: _almacenLocal.categorias,
          movimientoRepositorio: _almacenLocal.movimientos,
          reglasAprendidasRepositorio: _almacenLocal.reglasAprendidas,
          cicloRepositorio: _almacenLocal.ciclos,
          ingresoExtraRepositorio: _almacenLocal.ingresosExtra,
          ajustePresupuestoCicloRepositorio: _almacenLocal.ajustesPresupuestoCiclo,
          perfilRepositorio: _almacenLocal.perfil,
          servicioAuth: widget.servicioAuth,
          almacenLocal: _almacenLocal,
        );
      },
    );
  }
}
