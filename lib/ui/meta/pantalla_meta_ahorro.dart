import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/perfil_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/meta_apartado.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/popscope_descartar.dart';
import 'selector_meta.dart';

/// Pantalla de edición de la meta de apartado (Bloque A): envuelve
/// [SelectorMeta], guarda en [PerfilRepositorio] al confirmar. Enganchada
/// desde Ajustes ("Tu plan"), la tarjeta de Inicio y la fila "Meta de este
/// ciclo" de Ingresos del ciclo.
///
/// [onIrACategorias] es opcional y lo arma quien empuja esta pantalla: no
/// todos los que la abren tienen a la mano los cuatro repositorios que pide
/// `PantallaCategorias` (`PantallaIngresosDelCiclo`, por ejemplo, no trae
/// `MovimientoRepositorio`). Sin callback, el aviso de "no cabe" simplemente
/// no ofrece ese botón — mismo criterio que usa `SelectorMeta` internamente.
class PantallaMetaAhorro extends StatefulWidget {
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final PerfilRepositorio perfilRepositorio;
  final VoidCallback? onIrACategorias;

  const PantallaMetaAhorro({
    super.key,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.perfilRepositorio,
    this.onIrACategorias,
  });

  @override
  State<PantallaMetaAhorro> createState() => _PantallaMetaAhorroState();
}

class _PantallaMetaAhorroState extends State<PantallaMetaAhorro> {
  List<Categoria>? _categorias;
  MetaApartado? _metaSeleccionada;
  bool _cambio = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _metaSeleccionada = widget.perfil.metaApartado;
    _cargar();
  }

  Future<void> _cargar() async {
    final categorias = await widget.categoriaRepositorio.listarTodas();
    if (!mounted) return;
    setState(() => _categorias = categorias);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final actualizado = widget.perfil.copyWith(
      metaApartado: _metaSeleccionada,
      quitarMeta: _metaSeleccionada == null,
    );
    await widget.perfilRepositorio.guardar(actualizado);
    if (!mounted) return;
    Navigator.of(context).pop(actualizado);
  }

  @override
  Widget build(BuildContext context) {
    final categorias = _categorias;
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _cambio,
      child: Scaffold(
        appBar: AppBar(title: const Text('Meta de apartado')),
        body: SafeArea(
          child: categorias == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('De lo que entra al mes, ¿cuánto no quieres tocar?'),
                    const SizedBox(height: 16),
                    SelectorMeta(
                      ingresoBase: widget.perfil.ingresoBaseMensual,
                      fijas: categorias.whereType<CategoriaFija>().toList(),
                      variables: categorias.whereType<CategoriaVariable>().toList(),
                      metaInicial: _metaSeleccionada,
                      onCambio: (meta) => setState(() {
                        _metaSeleccionada = meta;
                        _cambio = true;
                      }),
                      onIrACategorias: widget.onIrACategorias,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      child: Text(_guardando ? 'Guardando…' : 'Guardar meta'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
