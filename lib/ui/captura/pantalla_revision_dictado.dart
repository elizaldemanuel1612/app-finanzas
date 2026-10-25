import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../../domain/voz/parser_dictado.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/formato_dinero.dart';
import '../comun/popscope_descartar.dart';
import '../comun/selector_fecha.dart';
import '../comun/tema.dart';

const _uuid = Uuid();

/// "Lo que entendió" (app-finanzas-voz-v4.html §2): cuando un dictado trae
/// más de un gasto, o alguno quedó ambiguo (dos montos candidatos, sin
/// categoría), esta pantalla los muestra editables antes de registrar
/// nada — nunca se guarda a ciegas lo que el parser adivinó.
class PantallaRevisionDictado extends StatefulWidget {
  final List<GastoDictado> gastos;
  final DateTime fechaInicial;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final CicloRepositorio cicloRepositorio;

  const PantallaRevisionDictado({
    super.key,
    required this.gastos,
    required this.fechaInicial,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.cicloRepositorio,
  });

  @override
  State<PantallaRevisionDictado> createState() =>
      _PantallaRevisionDictadoState();
}

class _ItemRevision {
  final TextEditingController monto;
  final TextEditingController descripcion;
  String? categoriaId;
  MedioPago medio;
  final List<Dinero> montosAmbiguos;

  _ItemRevision({
    required String? montoTexto,
    required String descripcionTexto,
    required this.categoriaId,
    required this.medio,
    required this.montosAmbiguos,
  }) : monto = TextEditingController(text: montoTexto),
       descripcion = TextEditingController(text: descripcionTexto);

  void dispose() {
    monto.dispose();
    descripcion.dispose();
  }
}

class _PantallaRevisionDictadoState extends State<PantallaRevisionDictado> {
  late Future<List<Categoria>> _categorias;
  late List<_ItemRevision> _items;
  late DateTime _fecha;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _categorias = widget.categoriaRepositorio.listarActivas();
    _fecha = widget.fechaInicial;
    _items = widget.gastos
        .map(
          (g) => _ItemRevision(
            montoTexto: g.monto == null
                ? null
                : textoEditableDeDinero(g.monto!),
            descripcionTexto: g.descripcion,
            categoriaId: g.categoriaId,
            medio: g.medio,
            montosAmbiguos: g.montosAmbiguos,
          ),
        )
        .toList();
  }

  // Llegar aquí ya significa que el dictado se parseó en gastos
  // pendientes — salir sin registrar los descarta todos.
  bool get _hayCambiosSinGuardar => _items.isNotEmpty;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _quitar(int i) {
    setState(() {
      _items[i].dispose();
      _items.removeAt(i);
    });
  }

  Future<void> _registrarTodos() async {
    if (_items.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    final calculadoraCiclo = widget.perfil.calculadoraCiclo;
    final puedeCapturar = await asegurarCicloAbierto(
      context,
      cicloId: calculadoraCiclo.calcularPara(_fecha).id,
      cicloRepositorio: widget.cicloRepositorio,
      esCaptura: true,
    );
    if (!puedeCapturar || !mounted) return;

    final aGuardar = <Movimiento>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final monto = Dinero.intentarDesdeTexto(item.monto.text);
      if (monto == null) {
        setState(() => _error = 'Gasto ${i + 1}: escribe un monto válido.');
        return;
      }
      if (item.categoriaId == null) {
        setState(() => _error = 'Gasto ${i + 1}: elige una categoría.');
        return;
      }
      final resultado = crearMovimiento(
        clientId: _uuid.v4(),
        fecha: _fecha,
        calculadoraCiclo: calculadoraCiclo,
        monto: monto,
        categoriaId: item.categoriaId!,
        medio: item.medio,
        descripcion: item.descripcion.text.trim().isEmpty
            ? 'Gasto'
            : item.descripcion.text.trim(),
        origenCaptura: OrigenCaptura.voz,
      );
      switch (resultado) {
        case Falla(:final mensaje):
          setState(() => _error = 'Gasto ${i + 1}: $mensaje');
          return;
        case Exito(:final valor):
          aGuardar.add(valor);
      }
    }

    setState(() {
      _error = null;
      _guardando = true;
    });
    for (final movimiento in aGuardar) {
      await widget.movimientoRepositorio.guardar(movimiento);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(title: const Text('Lo que entendí')),
        body: FutureBuilder<List<Categoria>>(
          future: _categorias,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final categorias = snapshot.data!;
            if (_items.isEmpty) {
              return const Center(
                child: Text(
                  'No queda ningún gasto por registrar.',
                  style: TextStyle(color: ColoresApp.medio),
                ),
              );
            }
            final hoy = DateTime.now();
            final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SelectorFecha(
                  seleccionada: _fecha,
                  onCambio: (f) => setState(() => _fecha = f),
                  primeraFecha: hoySoloFecha.subtract(
                    const Duration(days: 365),
                  ),
                  ultimaFecha: hoySoloFecha,
                  etiqueta: '¿Cuándo fueron estos gastos?',
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _items.length; i++) ...[
                  _TarjetaItem(
                    item: _items[i],
                    categorias: categorias,
                    onCambio: () => setState(() {}),
                    onQuitar: () => _quitar(i),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: ColoresApp.coralTexto),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _guardando ? null : _registrarTodos,
                  child: Text(
                    _guardando
                        ? 'Registrando…'
                        : 'Registrar los ${_items.length}',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaItem extends StatelessWidget {
  final _ItemRevision item;
  final List<Categoria> categorias;
  final VoidCallback onCambio;
  final VoidCallback onQuitar;

  const _TarjetaItem({
    required this.item,
    required this.categorias,
    required this.onCambio,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.monto,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: formateadoresDeMonto,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      prefixText: r'$ ',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: ColoresApp.medio,
                  ),
                  onPressed: onQuitar,
                  tooltip: 'Quitar este gasto',
                ),
              ],
            ),
            if (item.montosAmbiguos.length > 1) ...[
              const Text(
                'No quedó claro cuál es el monto:',
                style: TextStyle(
                  color: ColoresApp.coralTexto,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: item.montosAmbiguos.map((d) {
                  return ActionChip(
                    label: Text(d.formateado()),
                    onPressed: () {
                      item.monto.text = textoEditableDeDinero(d);
                      onCambio();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: item.descripcion,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categorias.map((c) {
                final elegida = c.id == item.categoriaId;
                return ChoiceChip(
                  label: Text('${c.emoji} ${c.nombre}'),
                  selected: elegida,
                  selectedColor: ColoresApp.violetaSuave,
                  onSelected: (_) {
                    item.categoriaId = c.id;
                    onCambio();
                  },
                );
              }).toList(),
            ),
            if (item.categoriaId == null) ...[
              const SizedBox(height: 6),
              const Text(
                'Elige una categoría para este gasto.',
                style: TextStyle(color: ColoresApp.coralTexto, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            SegmentedButton<MedioPago>(
              segments: const [
                ButtonSegment(value: MedioPago.tarjeta, label: Text('Tarjeta')),
                ButtonSegment(
                  value: MedioPago.efectivo,
                  label: Text('Efectivo'),
                ),
              ],
              selected: {item.medio},
              onSelectionChanged: (s) {
                item.medio = s.first;
                onCambio();
              },
            ),
          ],
        ),
      ),
    );
  }
}
