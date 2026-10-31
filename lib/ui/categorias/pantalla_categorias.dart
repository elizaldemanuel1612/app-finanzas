import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/presupuesto/categorias.dart' as reglas_categoria;
import '../comun/aviso_gesto.dart';
import '../comun/tema.dart';
import 'eliminar_categoria.dart';
import 'pantalla_nueva_categoria.dart';

class PantallaCategorias extends StatefulWidget {
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;

  const PantallaCategorias({
    super.key,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
  });

  @override
  State<PantallaCategorias> createState() => _PantallaCategoriasState();
}

class _PantallaCategoriasState extends State<PantallaCategorias> {
  List<Categoria>? _categorias;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final categorias = await widget.categoriaRepositorio.listarTodas();
    if (!mounted) return;
    setState(() => _categorias = categorias);
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
      body: _categorias == null ? const Center(child: CircularProgressIndicator()) : _buildContenido(),
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
