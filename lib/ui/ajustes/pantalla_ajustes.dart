import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/seguridad/candado.dart';
import '../../data/firebase/servicio_auth.dart';
import '../../data/repositorios/local/almacen_local.dart';
import '../../domain/ciclo_de_vida/cambio_de_corte.dart';
import '../../domain/exportacion/exportar_csv.dart';
import '../../domain/importacion/plantilla_csv.dart';
import '../../domain/modelos/meta_apartado.dart';
import '../../domain/modelos/perfil.dart';
import '../../data/nube/errores_respaldo.dart';
import '../../data/nube/respaldo_drive.dart';
import '../../data/nube/servicio_nube.dart';
import '../../plataforma/accesos_rapidos.dart';
import '../../plataforma/sesion_siri.dart';
import '../../plataforma/derivar_clave.dart';
import '../ayuda/pantalla_guia.dart';
import '../categorias/pantalla_categorias.dart';
import '../seguridad/pantalla_seguridad.dart';
import '../comun/apariencia.dart';
import '../comun/documento_legal.dart';
import '../comun/formato_fecha.dart';
import '../comun/guia_rapida.dart';
import '../comun/formato_dinero.dart';
import '../comun/renglon_app.dart';
import '../ia/pantalla_asistente.dart';
import '../ia/pantalla_complementos_ia.dart';
import '../ia/servicio_ia_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import '../importacion/pantalla_importar.dart';
import '../meta/pantalla_meta_ahorro.dart';
import 'pantalla_cambiar_corte.dart';
import 'pantalla_nube.dart';
import '../comun/hoja.dart';

/// §8 del paquete: "Ajustes" es donde viven la exportación de datos, los
/// avisos legales y la eliminación de cuenta que ambas tiendas exigen para
/// una app que maneja datos personales (Fase 6, Bloque 2).
class PantallaAjustes extends StatefulWidget {
  final Perfil perfil;
  final ServicioAuth servicioAuth;
  final AlmacenLocal almacenLocal;

  const PantallaAjustes({
    super.key,
    required this.perfil,
    required this.servicioAuth,
    required this.almacenLocal,
  });

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  bool _procesando = false;
  late Perfil _perfil = widget.perfil;

  Future<void> _irACategorias() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCategorias(
          categoriaIngresoRepositorio: widget.almacenLocal.categoriasIngreso,
          categoriaRepositorio: widget.almacenLocal.categorias,
          movimientoRepositorio: widget.almacenLocal.movimientos,
          reglasAprendidasRepositorio: widget.almacenLocal.reglasAprendidas,
          cicloRepositorio: widget.almacenLocal.ciclos,
        ),
      ),
    );
  }

  Future<void> _irAMetaAhorro() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaMetaAhorro(
          perfil: _perfil,
          categoriaRepositorio: widget.almacenLocal.categorias,
          perfilRepositorio: widget.almacenLocal.perfil,
          onIrACategorias: _irACategorias,
        ),
      ),
    );
    final perfilActualizado = await widget.almacenLocal.perfil.obtener();
    if (!mounted || perfilActualizado == null) return;
    setState(() => _perfil = perfilActualizado);
  }

  ServicioNube? get _nube {
    final auth = widget.servicioAuth;
    if (auth.usuarioActual == null) return null;
    return ServicioNube(
      almacen: widget.almacenLocal,
      remoto: RespaldoDrive(token: auth.tokenDrive, invalidar: auth.invalidarTokenDrive),
    );
  }

  Future<void> _irANube() async {
    final nube = _nube;
    if (nube == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaNube(
          nube: nube,
          correo: widget.servicioAuth.usuarioActual?.email ?? '',
          // Inicio recarga al volver de Ajustes; aquí no hace falta más.
          alCambiarDatos: () {},
        ),
      ),
    );
    final perfilActualizado = await widget.almacenLocal.perfil.obtener();
    if (!mounted || perfilActualizado == null) return;
    setState(() => _perfil = perfilActualizado);
  }

  Future<void> _irACambiarCorte() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCambiarCorte(
          perfil: _perfil,
          perfilRepositorio: widget.almacenLocal.perfil,
        ),
      ),
    );
    final perfilActualizado = await widget.almacenLocal.perfil.obtener();
    if (!mounted || perfilActualizado == null) return;
    setState(() => _perfil = perfilActualizado);
  }

  String get _subtituloCorte {
    final hoy = DateTime.now();
    final pendiente = cambioPendiente(_perfil, hoy);
    if (pendiente != null) {
      return 'Día ${pendiente.diaCorteNuevo} desde el ${fechaCorta(pendiente.vigenteDesde)} '
          '· hoy en ciclo de transición';
    }
    final ciclo = _perfil.calculadoraCiclo.calcularPara(hoy);
    return 'Día ${_perfil.diaCorte} · ciclo del ${fechaCorta(ciclo.fechaInicio)} '
        'al ${fechaCorta(ciclo.fechaFin)}';
  }

  Future<void> _irAImportar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaImportar(
          perfil: _perfil,
          categoriaRepositorio: widget.almacenLocal.categorias,
          movimientoRepositorio: widget.almacenLocal.movimientos,
          reglasAprendidasRepositorio: widget.almacenLocal.reglasAprendidas,
          cuentaRepositorio: widget.almacenLocal.cuentas,
          nube: _nube,
        ),
      ),
    );
  }

  /// En la web no hay hoja de compartir con archivos: se descarga.
  Future<void> _descargarEnWeb(String nombre, String contenido) => FilePicker.saveFile(
        fileName: nombre,
        bytes: Uint8List.fromList(utf8.encode(contenido)),
      );

  Future<void> _descargarPlantilla() async {
    setState(() => _procesando = true);
    try {
      if (kIsWeb) {
        await _descargarEnWeb('plantilla_importacion.csv', generarPlantillaCsvDeEjemplo());
        return;
      }
      final temporal = await getTemporaryDirectory();
      final archivo = File('${temporal.path}/plantilla_importacion.csv');
      await archivo.writeAsString(generarPlantillaCsvDeEjemplo());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path)],
          subject: 'Plantilla de importación — MAVfin',
          sharePositionOrigin: _origenCompartir(),
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// En iPad la hoja de compartir es un popover y necesita un ancla en
  /// pantalla; sin ella `SharePlus` lanza y no se abre nada. En iPhone y
  /// Android se ignora.
  Rect? _origenCompartir() {
    final caja = context.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return null;
    return caja.localToGlobal(Offset.zero) & caja.size;
  }

  void _irAComoFunciona() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaGuia(servicioIA: servicioIADe(widget.almacenLocal))),
    );
  }

  Future<void> _exportarCsv() async {
    final movimientos = await widget.almacenLocal.movimientos.listarTodos();
    final categorias = await widget.almacenLocal.categorias.listarTodas();
    final cuentas = await widget.almacenLocal.cuentas.listarTodas();
    await _compartirCsv(
      'gastos',
      'Mis gastos',
      exportarMovimientosCsv(movimientos: movimientos, categorias: categorias, cuentas: cuentas),
    );
  }

  /// Ingresos, ajustes y transferencias (spec §7.4): su propio archivo,
  /// porque sus columnas no son las de un gasto.
  Future<void> _exportarMovimientosCuenta() async {
    final movimientos = await widget.almacenLocal.movimientosCuenta.listarTodos();
    final cuentas = await widget.almacenLocal.cuentas.listarTodas();
    final categorias = await widget.almacenLocal.categoriasIngreso.listarTodas();
    await _compartirCsv(
      'ingresos_y_cuentas',
      'Mis ingresos y movimientos de cuentas',
      exportarMovimientosCuentaCsv(movimientos: movimientos, cuentas: cuentas, categoriasIngreso: categorias),
    );
  }

  Future<void> _compartirCsv(String base, String asunto, String csv) async {
    setState(() => _procesando = true);
    try {
      // No dejar exportaciones de veces anteriores acumulándose en el
      // directorio temporal — cada exportación deja atrás el historial
      // financiero completo hasta que el SO decida limpiar esa carpeta.
      await _borrarExportacionesTemporales();
      final fecha = DateTime.now();
      final nombre = '${base}_${fecha.year}${fecha.month.toString().padLeft(2, '0')}'
          '${fecha.day.toString().padLeft(2, '0')}.csv';
      if (kIsWeb) {
        await _descargarEnWeb(nombre, csv);
        return;
      }

      final temporal = await getTemporaryDirectory();
      final archivo = File('${temporal.path}/$nombre');
      await archivo.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path)],
          subject: '$asunto — MAVfin',
          sharePositionOrigin: _origenCompartir(),
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _abrirDocumentoLegal(String titulo, String rutaAsset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDocumentoLegal(titulo: titulo, rutaAsset: rutaAsset),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tus datos siguen en este dispositivo. Puedes volver a entrar con la misma cuenta de Google.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar != true) return;
    // El widget no debe seguir mostrando cifras de esta cuenta.
    await AccesosRapidos.limpiarWidget();
    await SesionSiri.olvidar();
    await widget.servicioAuth.cerrarSesion();
    // La compuerta de sesión (main.dart) reacciona sola y cambia la ruta
    // raíz a PantallaLogin, pero esta pantalla llegó apilada encima con
    // Navigator.push — sin este pop se queda tapando el login por debajo,
    // como si "Cerrar sesión" no hubiera hecho nada.
    if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  Future<void> _eliminarCuenta() async {
    final primerPaso = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Se borran de este dispositivo y de tu respaldo en Google Drive: tus '
          'movimientos, categorías, ciclos cerrados, ingresos extra y las '
          'fotos de tus tickets. También se borra tu cuenta de Google '
          'Sign-In. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              _exportarCsv();
            },
            child: const Text('Exportar antes de borrar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresApp.coralTexto),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (primerPaso != true) return;
    if (!mounted) return;

    // El error se guarda en vez de dejarlo volar: se reporta abajo, ya con
    // el diálogo cerrado.
    Future<Object?>? reautenticacion;
    final segundoPaso = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Seguro que quieres eliminar tu cuenta?'),
        content: const Text('Es la última confirmación. No hay forma de recuperar tus datos después de esto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresApp.coralTexto),
            onPressed: () {
              // Directo desde el toque, antes de cualquier espera (Safari).
              reautenticacion = widget.servicioAuth
                  .reautenticarParaEliminar()
                  .then<Object?>((_) => null, onError: (Object e) => e);
              Navigator.pop(context, true);
            },
            child: const Text('Sí, eliminar todo'),
          ),
        ],
      ),
    );
    if (segundoPaso != true) return;

    setState(() => _procesando = true);
    try {
      final errorDeReautenticacion = await reautenticacion;
      if (errorDeReautenticacion != null) throw errorDeReautenticacion;
      // Orden no negociable (Fase 6, Bloque 2.4): si delete() de Firebase
      // falla, los datos locales deben seguir intactos para reintentar. Al
      // revés, el usuario se queda sin datos y con cuenta.
      // La copia en Drive se borra primero: después de eliminar la
      // cuenta ya no habría sesión para borrarla (spec §4.2.1).
      final nube = _nube;
      if (nube != null && (await nube.estaActiva() || await nube.hayRespaldoEnNube())) {
        await nube.borrarCopiaEnNube();
      }
      await widget.servicioAuth.eliminarCuenta();
      await widget.almacenLocal.borrarTodo();
      await _borrarExportacionesTemporales();
      await AccesosRapidos.limpiarWidget();
      await SesionSiri.olvidar();
      await widget.servicioAuth.cerrarSesion();
      // Mismo motivo que en _cerrarSesion: sin este pop, la pantalla se
      // queda tapando el login aunque la cuenta ya no exista.
      if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar la cuenta. ${describirErrorRespaldo(e)}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// `borrarTodo()` limpia el directorio de documentos, pero "Exportar mis
  /// gastos" escribe el CSV en el directorio temporal (`getTemporaryDirectory`,
  /// fuera del alcance de `AlmacenLocal`) para pasárselo a `SharePlus`. Sin
  /// esto, un CSV con el historial financiero completo podía sobrevivir a
  /// "Eliminar cuenta" — el reseteo total que promete el diálogo de
  /// confirmación no era cierto del todo.
  Future<void> _borrarExportacionesTemporales() async {
    if (kIsWeb) return;
    final temporal = await getTemporaryDirectory();
    final dir = Directory(temporal.path);
    if (!await dir.exists()) return;
    await for (final entidad in dir.list()) {
      final nombre = entidad.path.replaceAll('\\', '/').split('/').last;
      if (entidad is File && (nombre.startsWith('gastos_') || nombre.startsWith('ingresos_y_cuentas_')) && nombre.endsWith('.csv')) {
        await entidad.delete();
      }
    }
  }

  Future<void> _elegirApariencia() async {
    final elegida = await mostrarHoja<Apariencia>(
      context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in Apariencia.values)
              ListTile(
                title: Text(a.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(a.detalle),
                trailing: a == AparienciaApp.actual.value ? Icon(Icons.check, color: ColoresApp.azul) : null,
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    );
    if (elegida != null) await AparienciaApp.elegir(elegida);
  }

  String get _textoMeta => switch (_perfil.metaApartado) {
        null => 'Lo que sobre',
        MetaPorMonto(:final monto) => enPesos(monto),
        MetaPorPorcentaje(:final porcentaje) => '$porcentaje % de lo que entra',
      };

  Widget _seccion(String titulo, List<Widget> renglones) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [EncabezadoSeccion(titulo: titulo), TarjetaApp.lista(renglones: renglones)],
      );

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final usuario = widget.servicioAuth.usuarioActual;
    final correo = usuario?.email ?? 'Sin sesión';
    final nombre = usuario?.displayName;
    final inicial = (nombre ?? correo).trim().characters.firstOrNull?.toUpperCase() ?? '·';
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AbsorbPointer(
        absorbing: _procesando,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TarjetaApp(
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: p.accion,
                      foregroundColor: p.sobreAccion,
                      child: Text(inicial, style: textos.seccion.copyWith(color: p.sobreAccion)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre ?? correo, style: textos.cuerpoFuerte, overflow: TextOverflow.ellipsis),
                        if (nombre != null) Text(correo, style: textos.etiqueta, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _seccion('Tu plan', [
              RenglonApp(
                icono: Icons.savings_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.verde,
                colorIcono: Colors.white,
                titulo: 'Meta del ciclo',
                derecha: Text(_textoMeta, style: textos.etiqueta),
                onTap: _irAMetaAhorro,
              ),
              RenglonApp(
                icono: Icons.grid_view_rounded,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.azul,
                colorIcono: Colors.white,
                titulo: 'Categorías y presupuestos',
                onTap: _irACategorias,
              ),
              RenglonApp(
                icono: Icons.event_repeat,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.naranja,
                colorIcono: Colors.white,
                titulo: 'Día de corte',
                subtitulo: _subtituloCorte,
                onTap: _irACambiarCorte,
              ),
            ]),
            _seccion('App', [
              RenglonApp(
                icono: Icons.auto_awesome,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.morado,
                colorIcono: Colors.white,
                titulo: 'Complementos de IA',
                subtitulo: 'Conecta Apple Intelligence o Gemini',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PantallaComplementosIA(servicio: servicioIADe(widget.almacenLocal))),
                ),
              ),
              ValueListenableBuilder<Apariencia>(
                valueListenable: AparienciaApp.actual,
                builder: (context, apariencia, _) => RenglonApp(
                  icono: Icons.dark_mode_outlined,
                  iconoCuadrado: true,
                  fondoIcono: _TinteAjustes.indigo,
                  colorIcono: Colors.white,
                  titulo: 'Apariencia',
                  derecha: Text(apariencia.etiqueta, style: textos.etiqueta),
                  onTap: _elegirApariencia,
                ),
              ),
              RenglonApp(
                icono: Icons.lock_outline,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.gris,
                colorIcono: Colors.white,
                titulo: 'Seguridad',
                subtitulo: 'Bloqueo con PIN, Face ID o huella',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantallaSeguridad(candado: Candado(widget.almacenLocal.candado, derivar: derivarClave)),
                  ),
                ),
              ),
            ]),
            _seccion('Tus datos', [
              RenglonApp(
                icono: Icons.cloud_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.azul,
                colorIcono: Colors.white,
                titulo: 'Respaldo en tu Google Drive',
                subtitulo: 'Una copia privada en tu propia cuenta',
                onTap: _irANube,
              ),
              RenglonApp(
                icono: Icons.ios_share_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.verde,
                colorIcono: Colors.white,
                titulo: 'Exportar mis gastos',
                subtitulo: 'Un archivo CSV con todo tu historial',
                onTap: _exportarCsv,
              ),
              RenglonApp(
                icono: Icons.ios_share_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.verde,
                colorIcono: Colors.white,
                titulo: 'Exportar ingresos y cuentas',
                subtitulo: 'Lo que te entró, ajustes y transferencias, en CSV',
                onTap: _exportarMovimientosCuenta,
              ),
              RenglonApp(
                icono: Icons.file_upload_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.naranja,
                colorIcono: Colors.white,
                titulo: 'Importar gastos',
                subtitulo: 'Desde un CSV, en cualquier momento',
                onTap: _irAImportar,
              ),
              RenglonApp(
                icono: Icons.description_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.turquesa,
                colorIcono: Colors.white,
                titulo: 'Descargar plantilla de ejemplo',
                subtitulo: 'El formato que espera la importación',
                onTap: _descargarPlantilla,
              ),
            ]),
            _seccion('Ayuda', [
              RenglonApp(
                icono: Icons.help_outline,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.azul,
                colorIcono: Colors.white,
                titulo: 'Cómo funciona la app',
                subtitulo: 'Guía por temas',
                onTap: _irAComoFunciona,
              ),
              RenglonApp(
                icono: Icons.forum_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.turquesa,
                colorIcono: Colors.white,
                titulo: 'Pregúntale a tu IA',
                subtitulo: 'Cómo se hace algo o dónde está un botón',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PantallaAsistente(servicio: servicioIADe(widget.almacenLocal))),
                ),
              ),
              RenglonApp(
                icono: Icons.replay,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.morado,
                colorIcono: Colors.white,
                titulo: 'Ver de nuevo las guías rápidas',
                onTap: () async {
                  await reiniciarGuiasRapidas();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Listo: verás la guía de cada apartado al volver a entrar.')),
                  );
                },
              ),
              RenglonApp(
                icono: Icons.privacy_tip_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.gris,
                colorIcono: Colors.white,
                titulo: 'Política de privacidad',
                onTap: () => _abrirDocumentoLegal('Política de privacidad', 'docs/legal/privacidad.md'),
              ),
              RenglonApp(
                icono: Icons.gavel_outlined,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.gris,
                colorIcono: Colors.white,
                titulo: 'Términos y condiciones',
                onTap: () => _abrirDocumentoLegal('Términos y condiciones', 'docs/legal/terminos.md'),
              ),
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text('Esta app no da asesoría financiera', style: textos.cuerpoFuerte),
                children: [
                  Text(
                    'MAVfin es una herramienta de registro y '
                    'pronóstico de tus propios gastos. No es asesoría '
                    'financiera, no invierte tu dinero, no se conecta a '
                    'bancos ni tarjetas, y no maneja dinero real en '
                    'ningún momento. Las cifras que muestra son '
                    'estimaciones basadas en lo que tú capturas.',
                    style: textos.etiqueta,
                  ),
                ],
              ),
            ]),
            _seccion('Cuenta', [
              RenglonApp(
                icono: Icons.logout,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.gris,
                colorIcono: Colors.white,
                titulo: 'Cerrar sesión',
                onTap: _cerrarSesion,
              ),
              RenglonApp(
                icono: Icons.delete_outline,
                iconoCuadrado: true,
                fondoIcono: _TinteAjustes.rojo,
                colorIcono: Colors.white,
                titulo: 'Eliminar cuenta',
                onTap: _eliminarCuenta,
              ),
            ]),
            const SizedBox(height: 24),
            Center(child: Text('MAVfin · versión 1.0.0 (1)', style: textos.etiqueta)),
          ],
        ),
      ),
    );
  }
}

/// Colores de los íconos en cuadro de Ajustes (estilo de las listas de
/// configuración de iOS). Fijos en los dos modos: el ícono va en blanco y
/// cada fondo pasa 3:1 contra él (umbral de gráficos, WCAG 1.4.11).
abstract final class _TinteAjustes {
  static const azul = Color(0xFF1F6FE0);
  static const verde = Color(0xFF248A3D);
  static const naranja = Color(0xFFC9590B);
  static const indigo = Color(0xFF4B4ACF);
  static const morado = Color(0xFF8344C7);
  static const turquesa = Color(0xFF0E7C86);
  static const gris = Color(0xFF6B6F7A);
  static const rojo = Color(0xFFD12E2E);
}
