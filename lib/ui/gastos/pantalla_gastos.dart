import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../captura/pantalla_captura.dart';
import '../comun/tema.dart';

const _uuid = Uuid();

/// app-finanzas-gastos-v3.html §1–3: agrupado por día, con el total de
/// cada día; la búsqueda contesta "¿cuánto llevo?", no solo filtra.
///
/// Cada movimiento responde a tres gestos (app-finanzas-eliminar-
/// reembolsos-v10.html §1): tocar para editar, deslizar a la izquierda
/// para eliminar (anular — regla no negociable #3, nunca se borra
/// físicamente), deslizar a la derecha para duplicar con la fecha de hoy
/// — "el atajo más usado" para gastos que se repiten casi idénticos.
class PantallaGastos extends StatefulWidget {
  final String cicloId;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;

  const PantallaGastos({
    super.key,
    required this.cicloId,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
  });

  @override
  State<PantallaGastos> createState() => _PantallaGastosState();
}

class _PantallaGastosState extends State<PantallaGastos> {
  late Future<_DatosGastos> _datos;
  final _busquedaControlador = TextEditingController();
  String _busqueda = '';
  String? _filtroCategoriaId;
  MedioPago? _filtroMedio;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
    _busquedaControlador.addListener(() {
      setState(() => _busqueda = _busquedaControlador.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _busquedaControlador.dispose();
    super.dispose();
  }

  void _refrescar() => setState(() => _datos = _cargar());

  Future<_DatosGastos> _cargar() async {
    final movimientos = await widget.movimientoRepositorio.listarPorCiclo(widget.cicloId);
    final categorias = await widget.categoriaRepositorio.listarTodas();
    return _DatosGastos(
      movimientos: movimientos.where((m) => m.estado == EstadoMovimiento.activo).toList(),
      categoriasPorId: {for (final c in categorias) c.id: c},
    );
  }

  Future<void> _abrirFiltros(List<Categoria> categorias) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtros', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              const Text('Categoría', style: TextStyle(color: ColoresApp.medio)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filtroCategoriaId == null,
                    onSelected: (_) {
                      setModalState(() => _filtroCategoriaId = null);
                      setState(() => _filtroCategoriaId = null);
                    },
                  ),
                  ...categorias.map((c) => ChoiceChip(
                        label: Text('${c.emoji} ${c.nombre}'),
                        selected: _filtroCategoriaId == c.id,
                        onSelected: (_) {
                          setModalState(() => _filtroCategoriaId = c.id);
                          setState(() => _filtroCategoriaId = c.id);
                        },
                      )),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Medio de pago', style: TextStyle(color: ColoresApp.medio)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filtroMedio == null,
                    onSelected: (_) {
                      setModalState(() => _filtroMedio = null);
                      setState(() => _filtroMedio = null);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Tarjeta'),
                    selected: _filtroMedio == MedioPago.tarjeta,
                    onSelected: (_) {
                      setModalState(() => _filtroMedio = MedioPago.tarjeta);
                      setState(() => _filtroMedio = MedioPago.tarjeta);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Efectivo'),
                    selected: _filtroMedio == MedioPago.efectivo,
                    onSelected: (_) {
                      setModalState(() => _filtroMedio = MedioPago.efectivo);
                      setState(() => _filtroMedio = MedioPago.efectivo);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<Movimiento> _filtrar(List<Movimiento> movimientos, Map<String, Categoria> categoriasPorId) {
    return movimientos.where((m) {
      if (_filtroCategoriaId != null && m.categoriaId != _filtroCategoriaId) return false;
      if (_filtroMedio != null && m.medio != _filtroMedio) return false;
      if (_busqueda.isNotEmpty) {
        final categoria = categoriasPorId[m.categoriaId];
        final texto = '${m.descripcion} ${categoria?.nombre ?? ''}'.toLowerCase();
        if (!texto.contains(_busqueda)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      body: FutureBuilder<_DatosGastos>(
        future: _datos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final datos = snapshot.data!;
          final categorias = datos.categoriasPorId.values.toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre));
          final filtrados = _filtrar(datos.movimientos, datos.categoriasPorId);
          final hayFiltrosActivos =
              _busqueda.isNotEmpty || _filtroCategoriaId != null || _filtroMedio != null;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _busquedaControlador,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar gasto o comercio',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      tooltip: 'Filtros',
                      onPressed: () => _abrirFiltros(categorias),
                    ),
                  ],
                ),
              ),
              if (hayFiltrosActivos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filtrados.length} movimiento(s) · '
                      '${Dinero.suma(filtrados.map((m) => m.monto)).formateado()}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.violeta),
                    ),
                  ),
                ),
              Expanded(
                child: filtrados.isEmpty
                    ? const Center(
                        child: Text('Nada por aquí.', style: TextStyle(color: ColoresApp.medio)))
                    : _ListaAgrupadaPorDia(
                        movimientos: filtrados,
                        categoriasPorId: datos.categoriasPorId,
                        perfil: widget.perfil,
                        categoriaRepositorio: widget.categoriaRepositorio,
                        movimientoRepositorio: widget.movimientoRepositorio,
                        reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
                        onCambio: _refrescar,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListaAgrupadaPorDia extends StatelessWidget {
  final List<Movimiento> movimientos;
  final Map<String, Categoria> categoriasPorId;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final VoidCallback onCambio;

  const _ListaAgrupadaPorDia({
    required this.movimientos,
    required this.categoriasPorId,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.onCambio,
  });

  Future<void> _editar(BuildContext context, Movimiento m) async {
    final editado = await Navigator.of(context).push<Movimiento>(
      MaterialPageRoute(
        builder: (_) => PantallaCaptura(
          perfil: perfil,
          categoriaRepositorio: categoriaRepositorio,
          movimientoRepositorio: movimientoRepositorio,
          reglasAprendidasRepositorio: reglasAprendidasRepositorio,
          paraEditar: m,
        ),
      ),
    );
    if (editado != null) onCambio();
  }

  Future<bool> _confirmarEliminar(BuildContext context, Movimiento m) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este gasto?'),
        content: Text('${m.descripcion} · ${m.monto.formateado()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return false;
    await movimientoRepositorio.anular(m.id!);
    onCambio();
    return true;
  }

  Future<void> _duplicar(BuildContext context, Movimiento m) async {
    final resultado = crearMovimiento(
      clientId: _uuid.v4(),
      fecha: DateTime.now(),
      calculadoraCiclo: CalculadoraCiclo(perfil.diaCorte),
      monto: m.monto,
      categoriaId: m.categoriaId,
      medio: m.medio,
      descripcion: m.descripcion,
      origenCaptura: OrigenCaptura.manual,
    );
    switch (resultado) {
      case Falla():
        return;
      case Exito(:final valor):
        await movimientoRepositorio.guardar(valor);
        onCambio();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gasto duplicado: ${valor.descripcion} hoy')),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = <DateTime, List<Movimiento>>{};
    for (final m in movimientos) {
      final dia = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      grupos.putIfAbsent(dia, () => []).add(m);
    }
    final dias = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: dias.length,
      itemBuilder: (context, i) {
        final dia = dias[i];
        final movsDelDia = grupos[dia]!;
        final total = Dinero.suma(movsDelDia.map((m) => m.monto));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fechaLarga(dia),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.medio)),
                  Text(total.formateado(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.medio)),
                ],
              ),
            ),
            ...movsDelDia.map((m) {
              final categoria = categoriasPorId[m.categoriaId];
              return Dismissible(
                key: ValueKey(m.id),
                direction: DismissDirection.horizontal,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: ColoresApp.verde,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.white),
                ),
                secondaryBackground: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: ColoresApp.coral,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) => direction == DismissDirection.startToEnd
                    ? _duplicar(context, m).then((_) => false)
                    : _confirmarEliminar(context, m),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _editar(context, m),
                    child: ListTile(
                      leading: Text(categoria?.emoji ?? '❔', style: const TextStyle(fontSize: 18)),
                      title: Text(m.descripcion),
                      subtitle: Text('${categoria?.nombre ?? m.categoriaId} · ${m.medio.name}'),
                      trailing: Text(m.monto.formateado(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

String _fechaLarga(DateTime f) {
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final nombreDia = dias[f.weekday - 1];
  final nombreDia0 = nombreDia[0].toUpperCase() + nombreDia.substring(1);
  return '$nombreDia0 ${f.day} ${meses[f.month - 1]}';
}

class _DatosGastos {
  final List<Movimiento> movimientos;
  final Map<String, Categoria> categoriasPorId;

  const _DatosGastos({required this.movimientos, required this.categoriasPorId});
}
