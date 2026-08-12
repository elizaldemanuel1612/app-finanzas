import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/presupuesto/categorias.dart';
import '../comun/popscope_descartar.dart';
import '../comun/tema.dart';
import 'eliminar_categoria.dart';

/// Alta y edición de categoría siguiendo app-finanzas-fijos-cierre-v6.html
/// §1–2: una sola pregunta ("¿el monto es siempre el mismo?") decide todo
/// lo demás. No se infiere del nombre — el usuario declara el tipo (regla
/// no negociable #8).
///
/// Si [categoriaExistente] viene dado, edita en vez de crear: el `id` se
/// conserva fijo aunque el usuario cambie el nombre — si no, renombrar
/// crearía una categoría nueva en vez de actualizar la que ya existe.
class PantallaNuevaCategoria extends StatefulWidget {
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;
  final Categoria? categoriaExistente;

  const PantallaNuevaCategoria({
    super.key,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
    this.categoriaExistente,
  });

  @override
  State<PantallaNuevaCategoria> createState() => _PantallaNuevaCategoriaState();
}

class _PantallaNuevaCategoriaState extends State<PantallaNuevaCategoria> {
  late final _nombreControlador = TextEditingController(
    text: _existente?.nombre,
  );
  late final _emojiControlador = TextEditingController(
    text: _existente?.emoji ?? '🏷️',
  );
  late final _montoControlador = TextEditingController(text: _montoInicial());
  late final _diaControlador = TextEditingController(text: _diaInicial());
  late bool _esFija = _existente is CategoriaFija;
  String? _error;
  bool _guardando = false;
  bool _eliminando = false;

  Categoria? get _existente => widget.categoriaExistente;
  bool get _editando => _existente != null;

  String? _montoInicial() {
    final e = _existente;
    return switch (e) {
      CategoriaFija f => (f.montoFijoCentavos.centavos / 100).toStringAsFixed(
        2,
      ),
      CategoriaVariable v =>
        (v.presupuestoMensualCentavos.centavos / 100).toStringAsFixed(2),
      null => null,
    };
  }

  String _diaInicial() {
    final e = _existente;
    return e is CategoriaFija ? '${e.diaDelCiclo}' : '1';
  }

  bool get _hayCambiosSinGuardar =>
      _nombreControlador.text != (_existente?.nombre ?? '') ||
      _emojiControlador.text != (_existente?.emoji ?? '🏷️') ||
      _montoControlador.text != (_montoInicial() ?? '') ||
      _diaControlador.text != _diaInicial() ||
      _esFija != (_existente is CategoriaFija);

  @override
  void dispose() {
    _nombreControlador.dispose();
    _emojiControlador.dispose();
    _montoControlador.dispose();
    _diaControlador.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final id =
        _existente?.id ??
        _nombreControlador.text.trim().toLowerCase().replaceAll(' ', '_');
    final monto = Dinero.intentarDesdeTexto(_montoControlador.text);

    if (monto == null) {
      setState(() => _error = 'Escribe un monto válido, ej. 500 o 500.00.');
      return;
    }

    final activa = _existente?.activa ?? true;
    final esNecesaria = _existente?.esNecesaria ?? false;

    final Resultado<Categoria> resultado;
    if (_esFija) {
      final dia = int.tryParse(_diaControlador.text.trim()) ?? 0;
      resultado = crearCategoriaFija(
        id: id,
        nombre: _nombreControlador.text.trim(),
        emoji: _emojiControlador.text.trim(),
        montoFijoCentavos: monto,
        diaDelCiclo: dia,
        activa: activa,
        esNecesaria: esNecesaria,
      );
    } else {
      resultado = crearCategoriaVariable(
        id: id,
        nombre: _nombreControlador.text.trim(),
        emoji: _emojiControlador.text.trim(),
        presupuestoMensualCentavos: monto,
        activa: activa,
        esNecesaria: esNecesaria,
      );
    }

    switch (resultado) {
      case Falla(:final mensaje):
        setState(() => _error = mensaje);
      case Exito(:final valor):
        setState(() {
          _error = null;
          _guardando = true;
        });
        await widget.categoriaRepositorio.guardar(valor);
        if (!mounted) return;
        Navigator.of(context).pop(true);
    }
  }

  /// Borrar de verdad solo tiene sentido cuando ningún movimiento
  /// referencia esta categoría — si ya se usó, borrarla dejaría esos
  /// movimientos apuntando a una categoría inexistente (rompe rollups y
  /// pronósticos en silencio). En ese caso se ofrece desactivar en su
  /// lugar, que ya es seguro (`conActiva`, usado desde la lista de
  /// categorías). El flujo completo —incluidos los diálogos con las
  /// cifras— vive en `eliminar_categoria.dart` para no duplicarlo con el
  /// swipe de la lista.
  Future<void> _eliminar() async {
    final existente = _existente!;
    setState(() {
      _eliminando = true;
      _error = null;
    });
    try {
      final huboCambio = await confirmarYEliminarCategoria(
        context,
        categoria: existente,
        categoriaRepositorio: widget.categoriaRepositorio,
        movimientoRepositorio: widget.movimientoRepositorio,
        reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
        cicloRepositorio: widget.cicloRepositorio,
      );
      if (!mounted) return;
      if (huboCambio) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _eliminando = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eliminando = false;
        _error = 'No se pudo eliminar la categoría. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar categoría' : 'Nueva categoría'),
          actions: [
            if (_editando)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar categoría',
                onPressed: _eliminando ? null : _eliminar,
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _nombreControlador,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emojiControlador,
                decoration: const InputDecoration(labelText: 'Emoji'),
              ),
              const SizedBox(height: 20),
              const Text(
                '¿El monto es siempre el mismo?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Sí, es fijo')),
                  ButtonSegment(value: false, label: Text('No, varía')),
                ],
                selected: {_esFija},
                onSelectionChanged: (s) => setState(() => _esFija = s.first),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _montoControlador,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _esFija ? 'Cuánto' : 'Presupuesto al mes',
                ),
              ),
              if (_esFija) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _diaControlador,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Día del ciclo'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: ColoresApp.coralTexto),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(
                  _guardando
                      ? 'Guardando…'
                      : (_editando ? 'Guardar cambios' : 'Crear categoría'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
