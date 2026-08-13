import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ciclo.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/importacion/importar_movimientos.dart';
import '../../domain/importacion/plantilla_csv.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/popscope_descartar.dart';
import '../comun/tema.dart';

/// Importar gastos desde CSV, siempre disponible (Bloque B) — a diferencia
/// de la migración inicial (`domain/migracion/`, que exige que todo cuadre
/// al centavo contra un Excel), esto es para cualquier momento: explica el
/// formato, ofrece una plantilla de ejemplo, deja elegir un archivo y
/// muestra una vista previa antes de guardar nada.
class PantallaImportar extends StatefulWidget {
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;

  const PantallaImportar({
    super.key,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
  });

  @override
  State<PantallaImportar> createState() => _PantallaImportarState();
}

class _PantallaImportarState extends State<PantallaImportar> {
  String? _nombreArchivo;
  ResultadoImportacion? _vistaPrevia;
  String? _error;
  bool _cargando = false;
  bool _importando = false;
  bool _importado = false;

  Future<void> _descargarPlantilla() async {
    final temporal = await getTemporaryDirectory();
    final archivo = File('${temporal.path}/plantilla_importacion.csv');
    await archivo.writeAsString(generarPlantillaCsvDeEjemplo());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(archivo.path)], subject: 'Plantilla de importación — App Finanzas'),
    );
  }

  Future<void> _elegirArchivo() async {
    final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv']);
    if (archivo == null) return;

    setState(() {
      _cargando = true;
      _error = null;
      _vistaPrevia = null;
      _importado = false;
      _nombreArchivo = archivo.name;
    });

    final String contenido;
    try {
      contenido = utf8.decode(await archivo.readAsBytes());
    } catch (_) {
      setState(() {
        _cargando = false;
        _error = 'No pude leer ese archivo.';
      });
      return;
    }

    final procesado = previsualizarImportacion(
      contenidoCsv: contenido,
      calculadoraCiclo: CalculadoraCiclo(widget.perfil.diaCorte),
      categoriasExistentes: await widget.categoriaRepositorio.listarTodas(),
    );

    if (!mounted) return;
    switch (procesado) {
      case Falla(:final mensaje):
        setState(() {
          _cargando = false;
          _error = mensaje;
        });
      case Exito(:final valor):
        setState(() {
          _cargando = false;
          _vistaPrevia = valor;
        });
    }
  }

  Future<void> _confirmarImportacion() async {
    final vistaPrevia = _vistaPrevia;
    if (vistaPrevia == null) return;

    setState(() => _importando = true);
    for (final categoria in vistaPrevia.categoriasPorCrear) {
      await widget.categoriaRepositorio.guardar(categoria);
    }
    for (final movimiento in vistaPrevia.movimientos) {
      await widget.movimientoRepositorio.guardar(movimiento);
    }
    if (!mounted) return;
    setState(() {
      _importando = false;
      _importado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vistaPrevia = _vistaPrevia;
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => vistaPrevia != null && !_importado,
      child: Scaffold(
        appBar: AppBar(title: const Text('Importar gastos')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Importa tu historial desde un CSV: fecha y monto son obligatorios; '
                'categoría, descripción y medio de pago son opcionales. Si no sabes '
                'el formato, descarga la plantilla de ejemplo primero.',
                style: TextStyle(color: ColoresApp.medio),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _descargarPlantilla,
                child: const Text('Descargar plantilla de ejemplo'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _cargando ? null : _elegirArchivo,
                child: Text(_cargando ? 'Leyendo…' : 'Elegir archivo'),
              ),
              if (_nombreArchivo != null) ...[
                const SizedBox(height: 8),
                Text(_nombreArchivo!, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: ColoresApp.coralTexto)),
              ],
              if (vistaPrevia != null) ...[
                const SizedBox(height: 24),
                _TarjetaVistaPrevia(vistaPrevia: vistaPrevia, importado: _importado),
                const SizedBox(height: 20),
                if (_importado)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ColoresApp.verdeSuave,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Listo. Los movimientos y categorías nuevas ya están guardados.',
                      style: TextStyle(color: ColoresApp.verdeTexto, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: vistaPrevia.movimientos.isEmpty || _importando
                        ? null
                        : _confirmarImportacion,
                    child: Text(_importando ? 'Importando…' : 'Importar'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaVistaPrevia extends StatelessWidget {
  final ResultadoImportacion vistaPrevia;
  final bool importado;

  const _TarjetaVistaPrevia({required this.vistaPrevia, required this.importado});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vistaPrevia.movimientos.length} '
              '${vistaPrevia.movimientos.length == 1 ? 'movimiento listo' : 'movimientos listos'} '
              'para importar',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (vistaPrevia.categoriasPorCrear.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Categorías nuevas (con presupuesto \$0, edítalas después):',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: vistaPrevia.categoriasPorCrear
                    .map((c) => Chip(label: Text('${c.emoji} ${c.nombre}')))
                    .toList(),
              ),
            ],
            if (vistaPrevia.renglonesConProblema.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${vistaPrevia.renglonesConProblema.length} '
                '${vistaPrevia.renglonesConProblema.length == 1 ? 'renglón' : 'renglones'} con problema '
                '(no se van a importar):',
                style: const TextStyle(color: ColoresApp.coralTexto, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...vistaPrevia.renglonesConProblema.take(10).map(
                    (p) => Text('• $p', style: Theme.of(context).textTheme.labelSmall),
                  ),
              if (vistaPrevia.renglonesConProblema.length > 10)
                Text(
                  'y ${vistaPrevia.renglonesConProblema.length - 10} más…',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
