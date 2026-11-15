import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_ingreso_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/categoria_ingreso.dart';
import '../../domain/presupuesto/categorias.dart' as reglas_categoria;
import '../comun/aviso_gesto.dart';
import '../comun/guia_rapida.dart';
import '../comun/tema.dart';
import 'editor_categoria_ingreso.dart';
import 'eliminar_categoria.dart';
import 'pantalla_nueva_categoria.dart';

class PantallaCategorias extends StatefulWidget {
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;

  /// Con él aparece el selector Gastos | Ingresos (spec §7.3.4).
  final CategoriaIngresoRepositorio? categoriaIngresoRepositorio;

  /// Abre directo en Ingresos (desde un abono, por ejemplo).
  final bool abrirEnIngresos;

  const PantallaCategorias({
    super.key,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
    this.categoriaIngresoRepositorio,
    this.abrirEnIngresos = false,
  });

  @override
  State<PantallaCategorias> createState() => _PantallaCategoriasState();
}

class _PantallaCategoriasState extends State<PantallaCategorias> {
  List<Categoria>? _categorias;
  List<CategoriaIngreso>? _deIngreso;
  late bool _viendoIngresos = widget.abrirEnIngresos && widget.categoriaIngresoRepositorio != null;

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarGuiaRapidaPrimeraVez(context, GuiaRapida.categorias));
  }

  Future<void> _cargar() async {
    final categorias = await widget.categoriaRepositorio.listarTodas();
    final deIngreso = await widget.categoriaIngresoRepositorio?.listarTodas();
    if (!mounted) return;
    setState(() {
      _categorias = categorias;
      _deIngreso = deIngreso;
    });
  }

  Future<void> _editarDeIngreso([CategoriaIngreso? existente]) async {
    final guardada = await mostrarEditorCategoriaIngreso(
      context,
      repositorio: widget.categoriaIngresoRepositorio!,
      existente: existente,
    );
    if (guardada != null) await _cargar();
  }

  Future<void> _alternarDeIngreso(CategoriaIngreso c) async {
    await widget.categoriaIngresoRepositorio!.guardar(c.copyWith(activa: !c.activa));
    await _cargar();
  }

  Future<void> _alternarActiva(Categoria categoria) async {
    final actualizada = reglas_categoria.conActiva(categoria, !categoria.activa);
    await widget.categoriaRepositorio.guardar(actualizada);
    await _cargar();
  }

  /// El valor que regresa es lo que el `Dismissible` de la fila usa para
  /// decidir si completa su animación de colapso (regla del widget: una
  /// vez que colapsa a cero, esa fila no vuelve a aparecer con la misma
  /// key). Eso solo es correcto cuando la categoría de verdad desapareció
  /// de la lista (`PuedeEliminarse`); archivarla o reasignarle
  /// movimientos la deja existiendo — ahí el swipe debe regresar a su
  /// lugar aunque sí haya habido un cambio que recargar.
  Future<bool> _eliminar(Categoria categoria) async {
    final huboCambio = await confirmarYEliminarCategoria(
      context,
      categoria: categoria,
      categoriaRepositorio: widget.categoriaRepositorio,
      movimientoRepositorio: widget.movimientoRepositorio,
      reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
      cicloRepositorio: widget.cicloRepositorio,
    );
    if (mounted) await avisarGestoPrimeraVez(context, GestoApp.eliminarCategoria);
    if (!huboCambio) return false;
    await _cargar();
    if (!mounted) return false;
    return !_categorias!.any((c) => c.id == categoria.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_viendoIngresos) return _editarDeIngreso();
          final creada = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PantallaNuevaCategoria(
                categoriaRepositorio: widget.categoriaRepositorio,
                movimientoRepositorio: widget.movimientoRepositorio,
                reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
                cicloRepositorio: widget.cicloRepositorio,
              ),
            ),
          );
          if (creada == true) await _cargar();
        },
        tooltip: 'Nueva categoría',
        child: const Icon(Icons.add),
      ),
      body: _categorias == null
          ? const Center(child: CircularProgressIndicator())
          : widget.categoriaIngresoRepositorio == null
              ? _buildContenido()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: false, label: Text('Gastos')),
                            ButtonSegment(value: true, label: Text('Ingresos')),
                          ],
                          selected: {_viendoIngresos},
                          onSelectionChanged: (s) => setState(() => _viendoIngresos = s.first),
                        ),
                      ),
                    ),
                    Expanded(child: _viendoIngresos ? _buildIngresos() : _buildContenido()),
                  ],
                ),
    );
  }

  /// Categorías de ingreso: de dónde entra el dinero. Sin presupuesto; se
  /// archivan con el interruptor.
  Widget _buildIngresos() {
    final todas = _deIngreso ?? const <CategoriaIngreso>[];
    final textos = Theme.of(context).textTheme;
    final activas = todas.where((c) => c.activa).toList();
    final archivadas = todas.where((c) => !c.activa).toList();
    Widget tarjeta(CategoriaIngreso c) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () => _editarDeIngreso(c),
            leading: ExcludeSemantics(child: Text(c.emoji, style: textos.titulo)),
            title: Text(c.nombre),
            subtitle: Text(c.activa ? 'Aparece al registrar un abono' : 'Archivada'),
            trailing: Switch(value: c.activa, onChanged: (_) => _alternarDeIngreso(c)),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'De dónde te entra dinero. Las eliges al registrar un abono en tus cuentas y se analizan en Análisis → Ingresos.',
            style: textos.etiqueta,
          ),
        ),
        if (activas.isNotEmpty) ...[
          _encabezadoSeccion('Activas', activas.length),
          const SizedBox(height: 8),
          ...activas.map(tarjeta),
        ],
        if (archivadas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _encabezadoSeccion('Archivadas', archivadas.length),
          const SizedBox(height: 8),
          ...archivadas.map(tarjeta),
        ],
        if (todas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Crea tu primera categoría de ingreso con el botón +.', textAlign: TextAlign.center, style: textos.cuerpo),
          ),
      ],
    );
  }

  Widget _buildContenido() {
    final categorias = _categorias!;
    if (categorias.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavía no tienes categorías. Crea la primera con el botón +.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresApp.medio),
          ),
        ),
      );
    }
    final activas = categorias.where((c) => c.activa).toList();
    final archivadas = categorias.where((c) => !c.activa).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activas.isNotEmpty) ...[
          _encabezadoSeccion('Activas', activas.length),
          const SizedBox(height: 8),
          ...activas.map((c) => _tarjetaCategoria(context, c)),
        ],
        if (archivadas.isNotEmpty) ...[
          if (activas.isNotEmpty) const SizedBox(height: 8),
          _encabezadoSeccion('Archivadas', archivadas.length),
          const SizedBox(height: 8),
          ...archivadas.map((c) => _tarjetaCategoria(context, c)),
        ],
      ],
    );
  }

  Widget _encabezadoSeccion(String titulo, int conteo) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '$titulo ($conteo)',
        style: TextStyle(
          color: ColoresApp.medio,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _tarjetaCategoria(BuildContext context, Categoria c) {
    final montoTexto = switch (c) {
      CategoriaFija f => '${f.montoFijoCentavos.formateado()} · fija',
      CategoriaVariable v => '${v.presupuestoMensualCentavos.formateado()} al mes · variable',
    };
    // Solo endToStart (coral + basurero): a diferencia de la lista
    // de gastos, aquí no hay un "duplicar" que justifique el
    // gesto contrario.
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: ColoresApp.coral,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _eliminar(c),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: () async {
            final editada = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PantallaNuevaCategoria(
                  categoriaRepositorio: widget.categoriaRepositorio,
                  movimientoRepositorio: widget.movimientoRepositorio,
                  reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
                  cicloRepositorio: widget.cicloRepositorio,
                  categoriaExistente: c,
                ),
              ),
            );
            if (editada == true) await _cargar();
          },
          leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
          title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(montoTexto),
          trailing: Switch(
            value: c.activa,
            onChanged: (_) => _alternarActiva(c),
          ),
        ),
      ),
    );
  }
}
