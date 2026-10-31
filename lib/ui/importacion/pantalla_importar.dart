import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../data/nube/errores_respaldo.dart';
import '../../data/nube/servicio_nube.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/clasificacion/historial_comercios.dart';
import '../../domain/importacion/importar_movimientos.dart';
import '../../domain/importacion/plantilla_csv.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../plataforma/elegir_archivo.dart';
import '../ayuda/modelo_guia.dart';
import '../comun/nota_destacada.dart';
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

  /// Para adivinar la categoría de los renglones que no la traen (Nivel 1
  /// de la cascada). Sin él se usa solo el historial de comercios.
  final ReglasAprendidasRepositorio? reglasAprendidasRepositorio;

  /// Con el respaldo activo, importar sobrescribe la copia de Drive: la
  /// fusión normal reviviría lo que se acaba de eliminar (spec §7.4).
  final ServicioNube? nube;

  const PantallaImportar({
    super.key,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    this.reglasAprendidasRepositorio,
    this.nube,
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
  bool _nubeActiva = false;

  Future<void> _descargarPlantilla() async {
    await FilePicker.saveFile(
      fileName: 'plantilla_importacion.csv',
      bytes: Uint8List.fromList(utf8.encode(generarPlantillaCsvDeEjemplo())),
    );
  }

  Future<void> _elegirArchivo() async {
    final archivo = await elegirArchivo(extensiones: ['csv']);
    if (archivo == null) return;

    setState(() {
      _cargando = true;
      _error = null;
      _vistaPrevia = null;
      _importado = false;
      _nombreArchivo = archivo.nombre;
    });

    final String contenido;
    try {
      contenido = utf8.decode(archivo.bytes);
    } catch (_) {
      setState(() {
        _cargando = false;
        _error = 'No pude leer ese archivo.';
      });
      return;
    }

    final movimientos = await widget.movimientoRepositorio.listarTodos();
    _nubeActiva = await widget.nube?.estaActiva() ?? false;
    final procesado = previsualizarImportacion(
      contenidoCsv: contenido,
      calculadoraCiclo: widget.perfil.calculadoraCiclo,
      categoriasExistentes: await widget.categoriaRepositorio.listarTodas(),
      reglasUsuario: await widget.reglasAprendidasRepositorio?.listarTodas() ?? const [],
      historialComercios: construirHistorialComercios([
        for (final m in movimientos)
          if (m.estado == EstadoMovimiento.activo) ObservacionComercio(m.descripcion, m.categoriaId),
      ]),
      movimientosExistentes: movimientos,
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

    // Sin permiso de Drive no se toca nada: la siguiente sincronización
    // reviviría lo eliminado. Se pide directo desde el toque (Safari), así
    // que el diálogo de confirmación lo arranca.
    Future<Object?> acceso = Future.value();
    final nube = _nubeActiva ? widget.nube : null;
    void pedirAcceso() {
      if (nube != null) {
        acceso = nube.pedirAcceso().then<Object?>(
              (concedido) => concedido ? null : StateError('Sin permiso para el respaldo.'),
              onError: (Object e) => e,
            );
      }
    }

    if (vistaPrevia.eliminaDatos) {
      if (!await _confirmarReemplazo(vistaPrevia, pedirAcceso)) return;
    } else {
      pedirAcceso();
    }

    setState(() => _importando = true);
    try {
      final error = await acceso;
      if (error != null) throw error;
      await nube?.marcarReemplazo();
      await widget.categoriaRepositorio.reemplazarTodas(vistaPrevia.categoriasFinales);
      await widget.movimientoRepositorio.reemplazarTodos(vistaPrevia.movimientos);
    } catch (e) {
      if (mounted) {
        setState(() => _importando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se importó nada. ${describirErrorRespaldo(e)}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      return;
    }
    // Sin red queda pendiente: la marca sobrevive hasta poder subir.
    await nube?.sincronizarSiActiva();
    if (!mounted) return;
    setState(() {
      _importando = false;
      _importado = true;
    });
  }

  Future<bool> _confirmarReemplazo(ResultadoImportacion vistaPrevia, VoidCallback alAceptar) async {
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reemplazar tus datos?'),
        content: Text(
          'Se eliminarán ${vistaPrevia.movimientosPorEliminar} gastos y '
          '${vistaPrevia.categoriasPorEliminar.length} categorías que no vienen en el archivo. '
          '${vistaPrevia.renglonesConProblema.isEmpty ? '' : 'Los renglones con problema tampoco se guardan. '}'
          'Esto no se puede deshacer. Si quieres conservarlos, cancela y usa primero '
          '"Exportar mis gastos" en Ajustes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ColoresApp.coralTexto),
            onPressed: () {
              alAceptar();
              Navigator.pop(context, true);
            },
            child: const Text('Sí, reemplazar'),
          ),
        ],
      ),
    );
    return respuesta == true;
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
              Text(
                'Importa tus gastos y categorías desde un CSV: solo fecha y monto son '
                'obligatorios. Al importar, tus datos quedan iguales al archivo: lo que no '
                'venga en él se elimina. Antes de guardar te dirá cuánto.',
                style: TextStyle(color: ColoresApp.medio),
              ),
              const SizedBox(height: 8),
              const _AyudaColumnas(),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _descargarPlantilla,
                child: const Text('Descargar plantilla de ejemplo'),
              ),
              const SizedBox(height: 12),
              const NotaDestacada(
                etiqueta: 'TIP',
                texto: 'Si tienes alguna IA, como ChatGPT, Copilot, Gemini, etc., '
                    'descarga la plantilla y pásasela junto con tus gastos: ya trae '
                    'las instrucciones para que te regrese el archivo listo para cargar.',
                tono: TonoNota.tip,
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
                Text(_error!, style: TextStyle(color: ColoresApp.coralTexto)),
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
                    child: Text(
                      'Listo. Tus gastos y categorías ya son los del archivo.',
                      style: TextStyle(color: ColoresApp.verdeTexto, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: (vistaPrevia.movimientos.isEmpty && vistaPrevia.categoriasFinales.isEmpty) ||
                            _importando
                        ? null
                        : _confirmarImportacion,
                    child: Text(_importando
                        ? 'Importando…'
                        : vistaPrevia.eliminaDatos
                            ? 'Reemplazar mis datos'
                            : 'Importar'),
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
            if (vistaPrevia.categoriasAdivinadas > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${vistaPrevia.categoriasAdivinadas} sin categoría '
                '${vistaPrevia.categoriasAdivinadas == 1 ? 'se clasificó' : 'se clasificaron'} '
                'por su descripción, como cuando registras un gasto.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (vistaPrevia.sinCategoria > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${vistaPrevia.sinCategoria} ${vistaPrevia.sinCategoria == 1 ? 'gasto no tiene' : 'gastos no tienen'} '
                'categoría y no pude adivinarla: ${vistaPrevia.sinCategoria == 1 ? 'irá' : 'irán'} a '
                '"$categoriaSinCategoria". Después muévelos a la suya desde Gastos.',
                style: TextStyle(color: ColoresApp.ambarTexto, fontWeight: FontWeight.w700),
              ),
            ],
            if (vistaPrevia.anulados > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${vistaPrevia.anulados} ${vistaPrevia.anulados == 1 ? 'viene anulado' : 'vienen anulados'}: '
                'se guardan, pero no cuentan en tus totales.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (vistaPrevia.categoriasPorCrear.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Categorías nuevas (sin presupuesto en el archivo quedan en \$0):',
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
            if (vistaPrevia.categoriasPorActualizar.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Estas categorías que ya tenías cambian con el archivo:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: vistaPrevia.categoriasPorActualizar
                    .map((c) => Chip(label: Text('${c.emoji} ${c.nombre}')))
                    .toList(),
              ),
            ],
            if (vistaPrevia.eliminaDatos && !importado) ...[
              const SizedBox(height: 12),
              Text(
                'Se eliminarán ${vistaPrevia.movimientosPorEliminar} gastos y '
                '${vistaPrevia.categoriasPorEliminar.length} categorías que no vienen en el archivo'
                '${vistaPrevia.categoriasPorEliminar.isEmpty ? '' : ': ${vistaPrevia.categoriasPorEliminar.map((c) => c.nombre).join(', ')}'}.',
                style: TextStyle(color: ColoresApp.coralTexto, fontWeight: FontWeight.w700),
              ),
            ],
            _ListaRenglones(
              renglones: vistaPrevia.avisos,
              titulo: '${vistaPrevia.avisos.length} '
                  '${vistaPrevia.avisos.length == 1 ? 'aviso' : 'avisos'} '
                  '(sí se importan, con el valor de omisión):',
              color: ColoresApp.ambarTexto,
            ),
            _ListaRenglones(
              renglones: vistaPrevia.renglonesConProblema,
              titulo: '${vistaPrevia.renglonesConProblema.length} '
                  '${vistaPrevia.renglonesConProblema.length == 1 ? 'renglón' : 'renglones'} con problema '
                  '(no se van a importar):',
              color: ColoresApp.coralTexto,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renglones con problema o con aviso: los primeros 10 y cuántos faltan.
class _ListaRenglones extends StatelessWidget {
  final List<RenglonConProblema> renglones;
  final String titulo;
  final Color color;

  const _ListaRenglones({required this.renglones, required this.titulo, required this.color});

  @override
  Widget build(BuildContext context) {
    if (renglones.isEmpty) return const SizedBox.shrink();
    final pequeno = Theme.of(context).textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...renglones.take(10).map((p) => Text('• $p', style: pequeno)),
        if (renglones.length > 10) Text('y ${renglones.length - 10} más…', style: pequeno),
      ],
    );
  }
}

/// Qué va en cada columna, plegado para no saturar la pantalla.
class _AyudaColumnas extends StatelessWidget {
  const _AyudaColumnas();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text('Qué va en cada columna', style: textos.titleMedium),
        children: [
          for (final (columna, ayuda) in ayudaColumnasCsv)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$columna: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ayuda),
                ]),
                style: textos.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
