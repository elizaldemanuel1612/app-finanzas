import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/firebase/servicio_auth.dart';
import '../../data/repositorios/local/almacen_local.dart';
import '../../domain/exportacion/exportar_csv.dart';
import '../comun/documento_legal.dart';
import '../comun/tema.dart';

/// §8 del paquete: "Ajustes" es donde viven la exportación de datos, los
/// avisos legales y la eliminación de cuenta que ambas tiendas exigen para
/// una app que maneja datos personales (Fase 6, Bloque 2).
class PantallaAjustes extends StatefulWidget {
  final ServicioAuth servicioAuth;
  final AlmacenLocal almacenLocal;

  const PantallaAjustes({
    super.key,
    required this.servicioAuth,
    required this.almacenLocal,
  });

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  bool _procesando = false;

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

      final temporal = await getTemporaryDirectory();
      final fecha = DateTime.now();
      final archivo = File(
        '${temporal.path}/gastos_${fecha.year}${fecha.month.toString().padLeft(2, '0')}'
        '${fecha.day.toString().padLeft(2, '0')}.csv',
      );
      await archivo.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(archivo.path)], subject: 'Mis gastos — App Finanzas'),
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
          'Se borran de este dispositivo: tus movimientos, categorías, '
          'ciclos cerrados, ingresos extra y las fotos de tus tickets. '
          'También se borra tu cuenta de Google Sign-In. Esto no se puede '
          'deshacer.',
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
      await widget.servicioAuth.eliminarCuenta();
      await widget.almacenLocal.borrarTodo();
      await _borrarExportacionesTemporales();
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
            _Seccion(
              titulo: 'Cuenta',
              children: [_Renglon(icono: Icons.person_outline, titulo: correo)],
            ),
            const SizedBox(height: 20),
            _Seccion(
              titulo: 'Tus datos',
              children: [
                _Renglon(
                  icono: Icons.ios_share_outlined,
                  titulo: 'Exportar mis gastos',
                  subtitulo: 'Un archivo CSV con todo tu historial',
                  onTap: _exportarCsv,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Seccion(
              titulo: 'Legal',
              children: [
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
                          'App Finanzas es una herramienta de registro y '
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
            _Seccion(
              titulo: 'Cuenta',
              children: [
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
            const Center(
              child: Text(
                'App Finanzas · versión 1.0.0 (1)',
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

class _Seccion extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const _Seccion({required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            titulo,
            style: const TextStyle(
              color: ColoresApp.medio,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        Card(child: Padding(padding: const EdgeInsets.all(4), child: Column(children: children))),
      ],
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
      trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: ColoresApp.medio),
    );
  }
}
