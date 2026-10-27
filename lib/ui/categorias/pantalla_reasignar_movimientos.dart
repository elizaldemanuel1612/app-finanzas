import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/presupuesto/reasignacion_categoria.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/popscope_descartar.dart';
import '../comun/tema.dart';

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _fechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]}';

/// Reasigna, movimiento por movimiento (de todos los ciclos, activos y
/// anulados), el historial de [categoria] a otra categoría activa — paso
/// previo para poder eliminarla de verdad cuando tiene historial (ver
/// `eliminar_categoria.dart`, caso `SoloPuedeDesactivarse`). También deja
/// eliminar (anular) un movimiento que no debería estar ahí, con el mismo
/// gesto de swipe que el resto de la app.
///
/// Regresa `true` si se guardó al menos un cambio, para que quien navegó
/// aquí vuelva a evaluar el efecto de eliminación desde cero.
class PantallaReasignarMovimientos extends StatefulWidget {
  final Categoria categoria;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final CicloRepositorio cicloRepositorio;

  const PantallaReasignarMovimientos({
    super.key,
    required this.categoria,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.cicloRepositorio,
  });

  @override
  State<PantallaReasignarMovimientos> createState() =>
      _PantallaReasignarMovimientosState();
}

class _PantallaReasignarMovimientosState extends State<PantallaReasignarMovimientos> {
  List<Movimiento>? _movimientos;
  List<Categoria> _destinos = const [];
  Categoria? _destinoGlobal;
  final Map<String, Categoria> _seleccionManual = {};
  bool _guardando = false;
  bool _huboAnulacion = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final movimientos =
        await widget.movimientoRepositorio.listarPorCategoria(widget.categoria.id);
    final activas = await widget.categoriaRepositorio.listarActivas();
    if (!mounted) return;
    setState(() {
      _movimientos = movimientos;
      _destinos = activas.where((c) => c.id != widget.categoria.id).toList();
    });
  }

  bool get _hayCambiosSinGuardar =>
      _destinoGlobal != null || _seleccionManual.isNotEmpty;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    var huboCambio = false;
    for (final m in _movimientos!) {
      final destino = _seleccionManual[m.id] ?? _destinoGlobal;
      if (destino == null) continue;
      final resultado = reasignarMovimiento(movimiento: m, destino: destino);
      switch (resultado) {
        case Exito(:final valor):
          await widget.movimientoRepositorio.actualizar(valor);
          huboCambio = true;
        case Falla():
          break;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(huboCambio || _huboAnulacion);
  }

  /// Anula el movimiento (regla no negociable #3: nunca se borra de
  /// verdad). Si su ciclo ya cerró, `asegurarCicloAbierto` avisa y exige
  /// reabrirlo antes de tocarlo — es la misma guardia que ya usa
  /// `pantalla_gastos.dart` para el mismo gesto.
  Future<bool> _eliminarMovimiento(Movimiento m) async {
    final puedeModificar = await asegurarCicloAbierto(
      context,
      cicloId: m.cicloId,
      cicloRepositorio: widget.cicloRepositorio,
    );
    if (!puedeModificar || !mounted) return false;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este movimiento?'),
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

    await widget.movimientoRepositorio.anular(m.id!);
    if (!mounted) return false;
    setState(() {
      _movimientos!.removeWhere((mv) => mv.id == m.id);
      _seleccionManual.remove(m.id);
      _huboAnulacion = true;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(title: Text('Reasignar ${widget.categoria.nombre}')),
        body: _movimientos == null
            ? const Center(child: CircularProgressIndicator())
            : _buildContenido(),
      ),
    );
  }

  Widget _buildContenido() {
    final movimientos = _movimientos!;

    if (_destinos.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay otra categoría activa a la que reasignar. Crea o '
            'reactiva una categoría primero.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresApp.medio),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mover todos a:', style: TextStyle(color: ColoresApp.medio)),
                const SizedBox(height: 8),
                _SelectorCategoria(
                  opciones: _destinos,
                  seleccionada: _destinoGlobal,
                  etiquetaVacia: 'Sin cambio',
                  onCambio: (c) => setState(() => _destinoGlobal = c),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: movimientos.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ya no quedan movimientos en esta categoría.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.medio),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: movimientos.length,
                    itemBuilder: (context, i) => _filaMovimiento(movimientos[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(_huboAnulacion),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaMovimiento(Movimiento m) {
    final esActivo = m.estado == EstadoMovimiento.activo;
    final destinoEfectivo = _seleccionManual[m.id] ?? _destinoGlobal;

    final tarjeta = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    m.descripcion,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: esActivo ? null : ColoresApp.medio,
                    ),
                  ),
                ),
                Text(
                  m.monto.formateado(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: esActivo ? null : ColoresApp.medio,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_fechaCorta(m.fecha)} · ciclo ${m.cicloId}'
              '${esActivo ? '' : ' · anulado'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            _SelectorCategoria(
              opciones: _destinos,
              seleccionada: destinoEfectivo,
              etiquetaVacia: 'Sin cambio',
              onCambio: (c) => setState(() => _seleccionManual[m.id!] = c),
            ),
          ],
        ),
      ),
    );

    // Un movimiento ya anulado no tiene nada más que "eliminar" — el
    // swipe queda solo para los activos.
    if (!esActivo) return tarjeta;

    return Dismissible(
      key: ValueKey(m.id),
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
      confirmDismiss: (_) => _eliminarMovimiento(m),
      child: tarjeta,
    );
  }
}

class _SelectorCategoria extends StatelessWidget {
  final List<Categoria> opciones;
  final Categoria? seleccionada;
  final String etiquetaVacia;
  final ValueChanged<Categoria> onCambio;

  const _SelectorCategoria({
    required this.opciones,
    required this.seleccionada,
    required this.etiquetaVacia,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ColoresApp.fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Categoria>(
          value: seleccionada,
          hint: Text(etiquetaVacia, style: TextStyle(color: ColoresApp.medio)),
          isExpanded: true,
          items: opciones
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c.emoji} ${c.nombre}'),
                  ))
              .toList(),
          onChanged: (c) {
            if (c != null) onCambio(c);
          },
        ),
      ),
    );
  }
}
