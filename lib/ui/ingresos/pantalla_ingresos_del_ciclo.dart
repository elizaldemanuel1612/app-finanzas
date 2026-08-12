import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/perfil_repositorio.dart';
import '../../domain/modelos/ingreso_extra.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/tema.dart';
import 'pantalla_registrar_ingreso_extra.dart';

/// Ingresos del ciclo (app-finanzas-ingresos-ajustes-v11.html §1): el
/// ingreso base editable con un toque y la lista de extras registrados,
/// vivos en `IngresoExtraRepositorio` — no confundir con el snapshot
/// congelado de un ciclo ya cerrado.
class PantallaIngresosDelCiclo extends StatefulWidget {
  final Ciclo ciclo;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;
  final PerfilRepositorio perfilRepositorio;

  const PantallaIngresosDelCiclo({
    super.key,
    required this.ciclo,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.ingresoExtraRepositorio,
    required this.perfilRepositorio,
  });

  @override
  State<PantallaIngresosDelCiclo> createState() => _PantallaIngresosDelCicloState();
}

class _PantallaIngresosDelCicloState extends State<PantallaIngresosDelCiclo> {
  late Perfil _perfil = widget.perfil;
  List<IngresoExtra>? _extras;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todos = await widget.ingresoExtraRepositorio.listarPorCiclo(widget.ciclo.id);
    if (!mounted) return;
    setState(() {
      _extras = todos.where((i) => i.estado == EstadoIngreso.activo).toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
    });
  }

  Dinero get _total =>
      _perfil.ingresoBaseMensual + Dinero.suma((_extras ?? const []).map((e) => e.monto));

  Future<void> _editarIngresoBase() async {
    final controlador = TextEditingController(
      text: textoEditableDeDinero(_perfil.ingresoBaseMensual),
    );
    final nuevo = await showDialog<Dinero>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingreso base'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Cuánto entra cada ciclo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final monto = Dinero.intentarDesdeTexto(controlador.text);
              Navigator.of(context).pop(monto);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null || !nuevo.esPositivo || !mounted) return;

    final actualizado = _perfil.copyWith(ingresoBaseMensual: nuevo);
    await widget.perfilRepositorio.guardar(actualizado);
    if (!mounted) return;
    setState(() => _perfil = actualizado);
  }

  Future<void> _registrarOtro() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaRegistrarIngresoExtra(
          ciclo: widget.ciclo,
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        ),
      ),
    );
    if (resultado == true) await _cargar();
  }

  Future<void> _editar(IngresoExtra ingreso) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaRegistrarIngresoExtra(
          ciclo: widget.ciclo,
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
          ingresoExistente: ingreso,
        ),
      ),
    );
    if (resultado == true) await _cargar();
  }

  Future<void> _anular(IngresoExtra ingreso) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Anular "${ingreso.etiqueta}"?'),
        content: Text(
          'El total de este ciclo baja de ${_total.formateado()} a '
          '${(_total - ingreso.monto).formateado()}. No se borra: queda anulado '
          'en tu historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    await widget.ingresoExtraRepositorio.anular(ingreso.id);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final extras = _extras;
    return Scaffold(
      appBar: AppBar(title: Text('Ingresos del ciclo ${widget.ciclo.etiqueta}')),
      body: SafeArea(
        child: extras == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FilaIngreso(
                            icono: '💼',
                            etiqueta: 'Ingreso base',
                            monto: _perfil.ingresoBaseMensual,
                            onTap: _editarIngresoBase,
                          ),
                          for (final extra in extras)
                            _FilaIngreso(
                              icono: '🎁',
                              etiqueta: '${extra.etiqueta} · ${fechaCorta(extra.fecha)}',
                              monto: extra.monto,
                              onTap: () => _editar(extra),
                              onAnular: () => _anular(extra),
                            ),
                          const Divider(height: 24),
                          _FilaIngreso(icono: null, etiqueta: 'Total', monto: _total, negrita: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _registrarOtro,
                    child: const Text('＋ Registrar otro ingreso'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FilaIngreso extends StatelessWidget {
  final String? icono;
  final String etiqueta;
  final Dinero monto;
  final bool negrita;
  final VoidCallback? onTap;
  final VoidCallback? onAnular;

  const _FilaIngreso({
    required this.icono,
    required this.etiqueta,
    required this.monto,
    this.negrita = false,
    this.onTap,
    this.onAnular,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Text(
      '${icono != null ? '$icono ' : ''}$etiqueta',
      style: TextStyle(
        fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
        color: negrita ? ColoresApp.tinta : ColoresApp.medio,
      ),
    );
    final valor = Text(
      monto.formateado(),
      style: TextStyle(fontWeight: negrita ? FontWeight.w800 : FontWeight.w700),
    );

    final fila = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: texto),
          valor,
          if (onAnular != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: ColoresApp.medio),
              tooltip: 'Anular',
              onPressed: onAnular,
            ),
        ],
      ),
    );

    if (onTap == null) return fila;
    return InkWell(onTap: onTap, child: fila);
  }
}
