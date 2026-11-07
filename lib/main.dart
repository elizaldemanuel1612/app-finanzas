import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'data/almacenamiento/archivo_texto_navegador.dart';
import 'data/firebase/servicio_auth.dart';
import 'data/nube/errores_respaldo.dart';
import 'data/nube/respaldo_drive.dart';
import 'data/nube/servicio_nube.dart';
import 'data/repositorios/local/almacen_local.dart';
import 'domain/modelos/perfil.dart';
import 'domain/sincronizacion/fusion.dart';
import 'firebase_options.dart';
import 'data/seguridad/candado.dart';
import 'plataforma/derivar_clave.dart';
import 'domain/seguridad/politica_bloqueo.dart';
import 'ui/seguridad/pantalla_crear_pin.dart';
import 'ui/seguridad/pantalla_desbloqueo.dart';
import 'ui/comun/apariencia.dart';
import 'ui/comun/marca.dart';
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
  // solo conecta el proyecto para el inicio de sesión (Auth); el respaldo
  // opcional vive en el Drive del propio usuario (spec §4.2.1).
  // Si falla (sin red, o algo mal configurado), la app sigue funcionando:
  // nada del flujo de captura depende de esto todavía.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await ServicioAuth.inicializar();
  } catch (e) {
    debugPrint('Firebase/Auth no se pudo inicializar: $e');
  }
  await AparienciaApp.cargar();
  runApp(const AppFinanzas());
}

/// Para poner la pantalla de desbloqueo encima de lo que esté abierto al
/// volver a la app (spec §7.3).
final llaveNavegador = GlobalKey<NavigatorState>();

/// Último toque en la app: el bloqueo cuenta la inactividad desde aquí, no
/// desde que la app se ocultó (spec §7.3).
DateTime _ultimaActividad = DateTime.now();

class AppFinanzas extends StatelessWidget {
  const AppFinanzas({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Apariencia>(
      valueListenable: AparienciaApp.actual,
      builder: (context, apariencia, _) => MaterialApp(
        navigatorKey: llaveNavegador,
        title: nombreApp,
        theme: construirTema(Paleta.clara),
        darkTheme: construirTema(Paleta.oscura),
        themeMode: apariencia.modo,
        // Sin animación: los colores de `ColoresApp` cambian de golpe, y un
        // tema a medio camino los dejaría desfasados durante el cruce.
        themeAnimationDuration: Duration.zero,
        // Fijo, no el del sistema — mismo criterio que la moneda (es_MX):
        // las cifras y el calendario no deben cambiar de formato entre equipos.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('es', 'MX')],
        locale: const Locale('es', 'MX'),
        // El teclado numérico de iOS no trae tecla para cerrarse (el de
        // Android sí) y tapa "Listo" en las pantallas de captura: tocar fuera
        // de un campo lo cierra, como en las apps nativas. Los toques sobre
        // botones y chips los ganan ellos, así que no se pierden.
        builder: (context, child) => SincronizarPaleta(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _ultimaActividad = DateTime.now(),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child,
            ),
          ),
        ),
        home: const _CompuertaAuth(),
      ),
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

  /// Un solo flujo para toda la vida de la compuerta. `authStateChanges()`
  /// devuelve un `Stream` nuevo en cada llamada: pedirlo en `build` hacía
  /// que cualquier reconstrucción completa (el cambio de paleta de
  /// `SincronizarPaleta`, o el claro/oscuro que iOS alterna al tomar la
  /// foto de la app en segundo plano) reiniciara el `StreamBuilder` a
  /// "esperando", desmontara `_ContenidoApp` y lo volviera a montar
  /// bloqueado: el PIN se pedía dos veces seguidas (spec §7.3).
  late final _cambiosDeUsuario = _servicioAuth.cambiosDeUsuario;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _cambiosDeUsuario,
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

/// Arma los repositorios locales (la fuente de verdad, §4.1; el respaldo en
/// Drive solo copia, ver data/nube/) y decide si mostrar
/// la configuración inicial o la app.
class _ContenidoApp extends StatefulWidget {
  final ServicioAuth servicioAuth;

  const _ContenidoApp({required this.servicioAuth});

  @override
  State<_ContenidoApp> createState() => _ContenidoAppState();
}

class _ContenidoAppState extends State<_ContenidoApp> with WidgetsBindingObserver {
  late final AlmacenLocal _almacenLocal;
  ServicioNube? _nube;
  Future<Perfil?>? _perfil;

  /// Hay respaldo en el Drive del usuario y este dispositivo está vacío: se ofrece
  /// restaurarlo antes del registro inicial (spec §4.2.1).
  bool _ofrecerRestaurar = false;
  bool _restaurando = false;

  /// Avisa a Inicio que la sincronización cambió datos y debe recargar.
  final _datosCambiaron = ValueNotifier<int>(0);

  /// Bloqueo de la app (spec §7.3). Arranca bloqueada; sin PIN, lo primero
  /// es crearlo.
  late final Candado _candado;
  bool _tienePin = false;
  bool _bloqueada = true;
  bool _bloqueoEncima = false;
  bool _salio = false;
  bool _candadoListo = false;
  DateTime? _actividadAnotada;
  Timer? _anotador;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anotador = Timer.periodic(const Duration(seconds: 15), (_) => _anotarActividad());
    _inicializar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anotador?.cancel();
    _datosCambiaron.dispose();
    super.dispose();
  }

  /// Sincroniza al volver a la app y al salir de ella, si el respaldo está
  /// activo (spec §4.2.1). Nunca bloquea ni falla en voz alta.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed || estado == AppLifecycleState.paused) {
      _sincronizarEnSegundoPlano();
    }
    if ((estado == AppLifecycleState.paused || estado == AppLifecycleState.hidden) && !_bloqueada) {
      _salio = true;
      _anotarActividad();
    }
    if (estado == AppLifecycleState.resumed && _salio) {
      _salio = false;
      if (debeBloquearAlVolver(ultimaActividad: _ultimaActividad, ahora: DateTime.now())) _bloquearEncima();
    }
  }

  /// Desbloqueo encima de lo que haya abierto (una captura a medias, por
  /// ejemplo), para que nada se pierda al volver.
  void _bloquearEncima() {
    final navegador = llaveNavegador.currentState;
    if (_bloqueada || _bloqueoEncima || !_tienePin || navegador == null) return;
    _bloqueoEncima = true;
    navegador.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (contexto) => PopScope(
          canPop: false,
          child: PantallaDesbloqueo(
            candado: _candado,
            servicioAuth: widget.servicioAuth,
            alDesbloquear: () {
              _bloqueoEncima = false;
              _alDesbloquear();
              Navigator.of(contexto).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _prepararCandado() async {
    _candado = Candado(_almacenLocal.candado, derivar: derivarClave);
    _tienePin = (await _candado.estado()).tienePin;
    // Si el sistema cerró o recargó la app hace poco (Safari en el iPhone lo
    // hace al quedarse sin memoria, por ejemplo al abrir el teclado), cuenta
    // como volver a ella: no se pide el desbloqueo antes de 2 minutos.
    final ultima = await _candado.ultimaActividad();
    if (_tienePin && ultima != null && !debeBloquearAlVolver(ultimaActividad: ultima, ahora: DateTime.now())) {
      _bloqueada = false;
      _ultimaActividad = ultima;
    }
    _actividadAnotada = ultima;
    _candadoListo = true;
  }

  void _alDesbloquear() {
    _ultimaActividad = DateTime.now();
    _anotarActividad();
  }

  /// Guarda el último toque (a lo más cada 15 s y al salir), solo con la app
  /// desbloqueada: tocar la pantalla del PIN no cuenta.
  void _anotarActividad() {
    if (!_candadoListo || _bloqueada || _bloqueoEncima || !_tienePin) return;
    final ultima = _ultimaActividad;
    if (ultima == _actividadAnotada) return;
    _actividadAnotada = ultima;
    _candado.anotarActividad(ultima).catchError((_) {});
  }

  Future<void> _sincronizarEnSegundoPlano() async {
    final nube = _nube;
    if (nube == null) return;
    if (await nube.sincronizarSiActiva() && mounted) _datosCambiaron.value++;
  }

  Future<void> _restaurar() async {
    setState(() => _restaurando = true);
    try {
      await _nube!.activar(ModoFusion.usarNube);
    } catch (e) {
      debugPrint('Restaurar respaldo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describirErrorRespaldo(e)), duration: const Duration(seconds: 8)),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _restaurando = false;
      _ofrecerRestaurar = false;
      _perfil = _almacenLocal.perfil.obtener();
    });
  }

  Future<void> _inicializar() async {
    // El uid se lee aquí, antes del primer `await` — en el mismo tick
    // síncrono en el que `_CompuertaAuth` decidió construir `_ContenidoApp`
    // porque había un usuario. Leerlo después de un `await` (como estaba
    // antes) deja una ventana real donde un cierre de sesión concurrente
    // vuelve `usuarioActual` null y `!.uid` truena con un null-check.
    final uid = widget.servicioAuth.usuarioActual!.uid;
    if (kIsWeb) {
      // En la web no hay archivos: almacenamiento del navegador, separado
      // por cuenta igual que en el teléfono (spec §4.2.2).
      _almacenLocal = almacenEnNavegador(uid);
      await _prepararCandado();
      await _prepararNube();
      return;
    }
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
    await _prepararCandado();
    await _prepararNube();
  }

  /// Arma el respaldo en el Drive del usuario. Si este dispositivo no tiene
  /// datos y hay respaldo (y el permiso ya está concedido), se ofrece
  /// restaurarlo; si los tiene y el respaldo está activo, se sincroniza en
  /// segundo plano. Sin red o sin permiso, la app sigue igual (regla #17).
  Future<void> _prepararNube() async {
    final auth = widget.servicioAuth;
    _nube = ServicioNube(
      almacen: _almacenLocal,
      remoto: RespaldoDrive(token: auth.tokenDrive, invalidar: auth.invalidarTokenDrive),
    );
    final perfilLocal = await _almacenLocal.perfil.obtener();
    var ofrecer = false;
    if (perfilLocal == null && _nube != null) {
      try {
        ofrecer = await _nube!.hayRespaldoEnNube();
      } catch (_) {
        ofrecer = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _ofrecerRestaurar = ofrecer;
      _perfil = Future.value(perfilLocal);
    });
    if (perfilLocal != null) _sincronizarEnSegundoPlano();
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
    if (!_tienePin) {
      return PantallaCrearPin(
        candado: _candado,
        explicacion: 'Tu información financiera queda protegida aunque alguien tome tu teléfono. '
            'Después puedes usar Face ID, huella o contraseña.',
        alTerminar: () {
          setState(() {
            _tienePin = true;
            _bloqueada = false;
          });
          _alDesbloquear();
        },
      );
    }
    if (_bloqueada) {
      return PantallaDesbloqueo(
        candado: _candado,
        servicioAuth: widget.servicioAuth,
        alDesbloquear: () {
          setState(() => _bloqueada = false);
          _alDesbloquear();
        },
      );
    }
    return FutureBuilder<Perfil?>(
      future: _perfil,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final perfil = snapshot.data;
        if (perfil == null && _ofrecerRestaurar) {
          return _PantallaRestaurar(
            correo: widget.servicioAuth.usuarioActual?.email ?? '',
            restaurando: _restaurando,
            alRestaurar: _restaurar,
            alEmpezarDeCero: () => setState(() => _ofrecerRestaurar = false),
          );
        }
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
          recargar: _datosCambiaron,
        );
      },
    );
  }
}

/// Dispositivo nuevo con respaldo en el Drive del usuario (spec §4.2.1).
class _PantallaRestaurar extends StatelessWidget {
  final String correo;
  final bool restaurando;
  final VoidCallback alRestaurar;
  final VoidCallback alEmpezarDeCero;

  const _PantallaRestaurar({
    required this.correo,
    required this.restaurando,
    required this.alRestaurar,
    required this.alEmpezarDeCero,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: EmblemaApp(tamano: 104)),
              const SizedBox(height: 28),
              Text('Encontramos tu respaldo', textAlign: TextAlign.center, style: textos.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Tu Google Drive ($correo) tiene una copia de tus datos. ¿La traemos a este dispositivo?',
                textAlign: TextAlign.center,
                style: textos.bodySmall,
              ),
              const Spacer(),
              if (restaurando)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(onPressed: alRestaurar, child: const Text('Restaurar mis datos')),
                const SizedBox(height: 10),
                TextButton(onPressed: alEmpezarDeCero, child: const Text('Empezar de cero')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
