import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/firebase/servicio_auth.dart';
import '../../data/repositorios/local/almacen_local.dart';
import '../../domain/ciclo_de_vida/cambio_de_corte.dart';
import '../../domain/exportacion/exportar_csv.dart';
import '../../domain/importacion/plantilla_csv.dart';
import '../../domain/modelos/perfil.dart';
import '../../data/nube/respaldo_drive.dart';
import '../../data/nube/servicio_nube.dart';
import '../../plataforma/accesos_rapidos.dart';
import '../ayuda/pantalla_guia.dart';
import '../categorias/pantalla_categorias.dart';
import '../comun/apariencia.dart';
import '../comun/documento_legal.dart';
import '../comun/formato_fecha.dart';
import '../comun/seccion_lista.dart';
import '../comun/tema.dart';
import '../importacion/pantalla_importar.dart';
import '../meta/pantalla_meta_ahorro.dart';
import 'pantalla_cambiar_corte.dart';
import 'pantalla_nube.dart';

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
      MaterialPageRoute(builder: (_) => const PantallaGuia()),
    );
  }

  Future<void> _exportarCsv() async {
    setState(() => _procesando = true);
    try {
      // No dejar exportaciones de veces anteriores acumulándose en el
      // directorio temporal — cada exportación deja atrás el historial
      // financiero completo hasta que el SO decida limpiar esa carpeta.
      await _borrarExportacionesTemporales();
      final movimientos = await widget.almacenLocal.movimientos.listarTodos();
      final categorias = await widget.almacenLocal.categorias.listarTodas();
      final csv = exportarMovimientosCsv(movimientos: movimientos, categorias: categorias);
      final fecha = DateTime.now();
      final nombre = 'gastos_${fecha.year}${fecha.month.toString().padLeft(2, '0')}'
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
          subject: 'Mis gastos — MAVfin',
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

    final segundoPaso = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Seguro que quieres eliminar tu cuenta?'),
        content: const Text('Es la última confirmación. No hay forma de recuperar tus datos después de esto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresApp.coralTexto),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar todo'),
          ),
        ],
      ),
    );
    if (segundoPaso != true) return;

    setState(() => _procesando = true);
    try {
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
      await widget.servicioAuth.cerrarSesion();
      // Mismo motivo que en _cerrarSesion: sin este pop, la pantalla se
      // queda tapando el login aunque la cuenta ya no exista.
      if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar la cuenta: $e')),
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
      if (entidad is File && nombre.startsWith('gastos_') && nombre.endsWith('.csv')) {
        await entidad.delete();
      }
    }
  }

  Future<void> _elegirApariencia() async {
    final elegida = await showModalBottomSheet<Apariencia>(
      context: context,
      showDragHandle: true,
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

  @override
  Widget build(BuildContext context) {
    final correo = widget.servicioAuth.usuarioActual?.email ?? 'Sin sesión';
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AbsorbPointer(
        absorbing: _procesando,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SeccionLista(
              titulo: 'Cuenta',
              hijos: [_Renglon(icono: Icons.person_outline, titulo: correo)],
            ),
            const SizedBox(height: 20),
            SeccionLista(
              titulo: 'Apariencia',
              hijos: [
                ValueListenableBuilder<Apariencia>(
                  valueListenable: AparienciaApp.actual,
                  builder: (context, apariencia, _) => _Renglon(
                    icono: Icons.dark_mode_outlined,
                    titulo: 'Modo claro u oscuro',
                    subtitulo: apariencia.etiqueta,
                    onTap: _elegirApariencia,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SeccionLista(
              titulo: 'Ayuda',
              hijos: [
                _Renglon(
                  icono: Icons.help_outline,
                  titulo: 'Cómo funciona la app',
                  subtitulo: 'Guía por temas: categorías, movimientos, registrar un gasto…',
                  onTap: _irAComoFunciona,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SeccionLista(
              titulo: 'Tu plan',
              hijos: [
                _Renglon(
                  icono: Icons.savings_outlined,
                  titulo: 'Meta de apartado',
                  subtitulo: _perfil.metaApartado == null
                      ? 'Hoy: lo que sobre de tus presupuestos'
                      : 'Editar cuánto quieres apartar cada ciclo',
                  onTap: _irAMetaAhorro,
                ),
                _Renglon(
                  icono: Icons.grid_view_rounded,
                  titulo: 'Categorías',
                  subtitulo: 'Crear, editar o archivar tus categorías',
                  onTap: _irACategorias,
                ),
                _Renglon(
                  icono: Icons.event_repeat,
                  titulo: 'Día de corte',
                  subtitulo: _subtituloCorte,
                  onTap: _irACambiarCorte,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SeccionLista(
              titulo: 'Tus datos',
              hijos: [
                _Renglon(
                  icono: Icons.cloud_outlined,
                  titulo: 'Respaldo en tu Google Drive',
                  subtitulo: 'Una copia privada en tu propia cuenta',
                  onTap: _irANube,
                ),
                _Renglon(
                  icono: Icons.ios_share_outlined,
                  titulo: 'Exportar mis gastos',
                  subtitulo: 'Un archivo CSV con todo tu historial',
                  onTap: _exportarCsv,
                ),
                _Renglon(
                  icono: Icons.file_upload_outlined,
                  titulo: 'Importar gastos',
                  subtitulo: 'Desde un CSV, en cualquier momento',
                  onTap: _irAImportar,
                ),
                _Renglon(
                  icono: Icons.description_outlined,
                  titulo: 'Descargar plantilla de ejemplo',
                  subtitulo: 'El formato que espera la importación',
                  onTap: _descargarPlantilla,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SeccionLista(
              titulo: 'Legal',
              hijos: [
                _Renglon(
                  icono: Icons.privacy_tip_outlined,
                  titulo: 'Política de privacidad',
                  onTap: () => _abrirDocumentoLegal(
                    'Política de privacidad',
                    'docs/legal/privacidad.md',
                  ),
                ),
                _Renglon(
                  icono: Icons.description_outlined,
                  titulo: 'Términos y condiciones',
                  onTap: () => _abrirDocumentoLegal(
                    'Términos y condiciones',
                    'docs/legal/terminos.md',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Esta app no da asesoría financiera'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'MAVfin es una herramienta de registro y '
                          'pronóstico de tus propios gastos. No es asesoría '
                          'financiera, no invierte tu dinero, no se conecta a '
                          'bancos ni tarjetas, y no maneja dinero real en '
                          'ningún momento. Las cifras que muestra son '
                          'estimaciones basadas en lo que tú capturas.',
                          style: TextStyle(color: ColoresApp.medio),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SeccionLista(
              titulo: 'Cuenta',
              hijos: [
                _Renglon(
                  icono: Icons.logout,
                  titulo: 'Cerrar sesión',
                  onTap: _cerrarSesion,
                ),
                _Renglon(
                  icono: Icons.delete_outline,
                  titulo: 'Eliminar cuenta',
                  colorTexto: ColoresApp.coralTexto,
                  onTap: _eliminarCuenta,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'MAVfin · versión 1.0.0 (1)',
                style: TextStyle(color: ColoresApp.medio, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Color? colorTexto;
  final VoidCallback? onTap;

  const _Renglon({
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.colorTexto,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono, color: colorTexto ?? ColoresApp.tinta),
      title: Text(titulo, style: TextStyle(color: colorTexto ?? ColoresApp.tinta)),
      subtitle: subtitulo == null ? null : Text(subtitulo!),
      onTap: onTap,
      trailing: onTap == null ? null : Icon(Icons.chevron_right, color: ColoresApp.medio),
    );
  }
}
