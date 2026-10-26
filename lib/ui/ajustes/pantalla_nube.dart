import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/nube/servicio_nube.dart';
import '../../domain/sincronizacion/fusion.dart';
import '../comun/formato_fecha.dart';
import '../comun/tema.dart';

/// Respaldo en la nube (spec-app-finanzas-v2.md §4.2.1): activar, elegir
/// cómo combinar si ya había algo en la nube, sincronizar, desactivar o
/// borrar la copia.
class PantallaNube extends StatefulWidget {
  final ServicioNube nube;
  final String correo;

  /// Se avisa cuando los datos del dispositivo cambiaron (para recargar).
  final VoidCallback alCambiarDatos;

  const PantallaNube({
    super.key,
    required this.nube,
    required this.correo,
    required this.alCambiarDatos,
  });

  @override
  State<PantallaNube> createState() => _PantallaNubeState();
}

class _PantallaNubeState extends State<PantallaNube> {
  bool? _activa;
  DateTime? _ultima;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final activa = await widget.nube.estaActiva();
    final ultima = await widget.nube.ultimaSincronizacion();
    if (!mounted) return;
    setState(() {
      _activa = activa;
      _ultima = ultima;
    });
  }

  Future<void> _conProgreso(Future<void> Function() tarea, String exito) async {
    setState(() => _trabajando = true);
    try {
      await tarea();
      widget.alCambiarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar con la nube. Revisa tu internet e intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _trabajando = false);
      await _cargar();
    }
  }

  Future<void> _activar() async {
    setState(() => _trabajando = true);
    EstadoInicialNube estado;
    try {
      estado = await widget.nube.estadoInicial();
    } catch (_) {
      if (!mounted) return;
      setState(() => _trabajando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar con la nube. Revisa tu internet e intenta de nuevo.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _trabajando = false);

    var modo = ModoFusion.combinar;
    if (estado.hayQueElegir) {
      final elegido = await _preguntarModo();
      if (elegido == null) return;
      modo = elegido;
    } else if (estado.hayDatosEnNube) {
      modo = ModoFusion.usarNube;
    } else {
      modo = ModoFusion.usarDispositivo;
    }
    await _conProgreso(() => widget.nube.activar(modo), 'Listo: tus datos ya tienen respaldo en la nube.');
  }

  Future<ModoFusion?> _preguntarModo() => showModalBottomSheet<ModoFusion>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          final textos = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Ya tienes datos en la nube', style: textos.titleMedium),
                  const SizedBox(height: 4),
                  Text('Y también en este dispositivo. ¿Cómo los juntamos?', style: textos.bodySmall),
                  const SizedBox(height: 16),
                  _OpcionModo(
                    titulo: 'Combinar (recomendado)',
                    detalle: 'Junta todo. Si un mismo dato es distinto, se queda el de este dispositivo.',
                    icono: Icons.merge_rounded,
                    alTocar: () => Navigator.pop(context, ModoFusion.combinar),
                  ),
                  _OpcionModo(
                    titulo: 'Usar lo de la nube',
                    detalle: 'Este dispositivo queda igual que tu respaldo.',
                    icono: Icons.cloud_download_outlined,
                    alTocar: () => Navigator.pop(context, ModoFusion.usarNube),
                  ),
                  _OpcionModo(
                    titulo: 'Usar lo de este dispositivo',
                    detalle: 'Tu respaldo queda igual que este dispositivo. Los gastos que sobren en la nube '
                        'se anulan, no se borran.',
                    icono: Icons.cloud_upload_outlined,
                    alTocar: () => Navigator.pop(context, ModoFusion.usarDispositivo),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _borrarCopia() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar la copia en la nube?'),
        content: const Text(
          'Se borra tu respaldo y dejas de sincronizar. Los datos de este dispositivo no se tocan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresApp.coralTexto),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar copia'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _conProgreso(widget.nube.borrarCopiaEnNube, 'Listo: se borró tu copia en la nube.');
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final activa = _activa;
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo en la nube')),
      body: activa == null
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _trabajando,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: activa ? ColoresApp.verdeSuave : ColoresApp.azulSuave,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        activa ? Icons.cloud_done_rounded : Icons.cloud_outlined,
                        size: 40,
                        color: activa ? ColoresApp.verdeTexto : ColoresApp.azul,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    activa ? 'Tu respaldo está activo' : 'Guarda una copia en la nube',
                    textAlign: TextAlign.center,
                    style: textos.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activa
                        ? (_ultima == null
                            ? 'Ligado a ${widget.correo}.'
                            : 'Ligado a ${widget.correo}. Última sincronización: '
                                '${fechaCorta(_ultima!)}, ${_hora(_ultima!)}.')
                        : 'Tus datos se guardan ligados a tu cuenta de Google (${widget.correo}). '
                            'Si cambias de teléfono o entras desde la web, los recuperas.',
                    textAlign: TextAlign.center,
                    style: textos.bodySmall,
                  ),
                  if (kIsWeb && !activa) ...[
                    const SizedBox(height: 16),
                    const _Aviso(
                      texto: 'En la web, el navegador puede borrar los datos si no usas el sitio por un '
                          'tiempo. Te recomendamos activar el respaldo.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_trabajando) const Center(child: CircularProgressIndicator()),
                  if (!_trabajando && !activa)
                    ElevatedButton(onPressed: _activar, child: const Text('Activar respaldo')),
                  if (!_trabajando && activa) ...[
                    ElevatedButton(
                      onPressed: () => _conProgreso(widget.nube.sincronizarAhora, 'Listo: todo sincronizado.'),
                      child: const Text('Sincronizar ahora'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _conProgreso(widget.nube.desactivar, 'Respaldo pausado. Tu copia sigue en la nube.'),
                      child: const Text('Pausar respaldo'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _Aviso(
                    texto: 'Se sincroniza solo al abrir y al salir de la app. Solo tú puedes ver tu copia. '
                        'Las fotos de tickets no se suben.',
                  ),
                  if (!_trabajando) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: ColoresApp.coralTexto),
                        onPressed: _borrarCopia,
                        child: const Text('Borrar mi copia en la nube'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  static String _hora(DateTime f) => '${f.hour}:${f.minute.toString().padLeft(2, '0')}';
}

class _OpcionModo extends StatelessWidget {
  final String titulo;
  final String detalle;
  final IconData icono;
  final VoidCallback alTocar;

  const _OpcionModo({
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono, color: ColoresApp.azul),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detalle),
        onTap: alTocar,
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.azulSuave, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: ColoresApp.azul),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
