import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/presupuesto/categorias.dart' as reglas_categoria;
import '../comun/tema.dart';
import 'pantalla_nueva_categoria.dart';

class PantallaCategorias extends StatefulWidget {
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;

  const PantallaCategorias({
    super.key,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
  });

  @override
  State<PantallaCategorias> createState() => _PantallaCategoriasState();
}

class _PantallaCategoriasState extends State<PantallaCategorias> {
  late Future<List<Categoria>> _categorias;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _categorias = widget.categoriaRepositorio.listarTodas();
  }

  Future<void> _alternarActiva(Categoria categoria) async {
    final actualizada = reglas_categoria.conActiva(categoria, !categoria.activa);
    await widget.categoriaRepositorio.guardar(actualizada);
    setState(_cargar);
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
              ),
            ),
          );
          if (creada == true) setState(_cargar);
        },
        backgroundColor: ColoresApp.violeta,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<Categoria>>(
        future: _categorias,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categorias = snapshot.data!;
          if (categorias.isEmpty) {
            return const Center(
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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categorias.length,
            itemBuilder: (context, i) {
              final c = categorias[i];
              final montoTexto = switch (c) {
                CategoriaFija f => '${f.montoFijoCentavos.formateado()} · fija',
                CategoriaVariable v =>
                  '${v.presupuestoMensualCentavos.formateado()} al mes · variable',
              };
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () async {
                    final editada = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => PantallaNuevaCategoria(
                          categoriaRepositorio: widget.categoriaRepositorio,
                          movimientoRepositorio: widget.movimientoRepositorio,
                          categoriaExistente: c,
                        ),
                      ),
                    );
                    if (editada == true) setState(_cargar);
                  },
                  leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(montoTexto),
                  trailing: Switch(
                    value: c.activa,
                    activeThumbColor: ColoresApp.violeta,
                    onChanged: (_) => _alternarActiva(c),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
