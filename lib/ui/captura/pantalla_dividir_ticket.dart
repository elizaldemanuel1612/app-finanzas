import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../../domain/reglas/ticket_dividido.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/formato_dinero.dart';
import '../comun/popscope_descartar.dart';
import '../comun/selector_fecha.dart';
import '../comun/tema.dart';

const _uuid = Uuid();

/// Divide un mismo ticket en varios movimientos que comparten `ticketId` y
/// `fotoUrl` (spec-app-finanzas-v2.md §5.5). Regla no negociable #19: las
/// partes deben sumar el total al centavo o no se deja registrar
/// (domain/reglas/ticket_dividido.dart) — se valida en vivo con cada
/// cambio, como en app-finanzas-ticket-v7.html §3.
class PantallaDividirTicket extends StatefulWidget {
  final String fotoUrl;
  final Dinero? totalInicial;
  final DateTime fechaInicial;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final CicloRepositorio cicloRepositorio;

  const PantallaDividirTicket({
    super.key,
    required this.fotoUrl,
    required this.totalInicial,
    required this.fechaInicial,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.cicloRepositorio,
  });

  @override
  State<PantallaDividirTicket> createState() => _PantallaDividirTicketState();
}

class _Renglon {
  final TextEditingController monto = TextEditingController();
  final TextEditingController descripcion = TextEditingController();
  String? categoriaId;

  void dispose() {
    monto.dispose();
    descripcion.dispose();
  }
}

class _PantallaDividirTicketState extends State<PantallaDividirTicket> {
  final _ticketId = _uuid.v4();
  late final TextEditingController _totalControlador;
  late Future<List<Categoria>> _categorias;
  final _renglones = <_Renglon>[_Renglon(), _Renglon()];
  late DateTime _fecha;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _totalControlador = TextEditingController(
      text: widget.totalInicial == null
          ? ''
          : textoEditableDeDinero(widget.totalInicial!),
    );
    _categorias = widget.categoriaRepositorio.listarActivas();
    _fecha = widget.fechaInicial;
  }

  bool get _hayCambiosSinGuardar => _renglones.any(
    (r) =>
        r.monto.text.isNotEmpty ||
        r.descripcion.text.isNotEmpty ||
        r.categoriaId != null,
  );

  @override
  void dispose() {
    _totalControlador.dispose();
    for (final r in _renglones) {
      r.dispose();
    }
    super.dispose();
  }

  void _agregarRenglon() => setState(() => _renglones.add(_Renglon()));

  void _quitarRenglon(int i) {
    setState(() {
      _renglones[i].dispose();
      _renglones.removeAt(i);
    });
  }

  Dinero get _suma => Dinero.suma(
    _renglones.map(
      (r) => Dinero.intentarDesdeTexto(r.monto.text) ?? const Dinero.cero(),
    ),
  );

  Future<void> _registrar() async {
    final total = Dinero.intentarDesdeTexto(_totalControlador.text);
    if (total == null) {
      setState(() => _error = 'Escribe el total del ticket.');
      return;
    }

    final partes = <Dinero>[];
    for (var i = 0; i < _renglones.length; i++) {
      final monto = Dinero.intentarDesdeTexto(_renglones[i].monto.text);
      if (monto == null) {
        setState(() => _error = 'Renglón ${i + 1}: escribe un monto válido.');
        return;
      }
      partes.add(monto);
    }

    final validacion = validarPartesTicket(total: total, partes: partes);
    if (validacion case Falla(:final mensaje)) {
      setState(() => _error = mensaje);
      return;
    }

    for (var i = 0; i < _renglones.length; i++) {
      if (_renglones[i].categoriaId == null) {
        setState(() => _error = 'Renglón ${i + 1}: elige una categoría.');
        return;
      }
    }

    final calculadoraCiclo = CalculadoraCiclo(widget.perfil.diaCorte);
    final puedeCapturar = await asegurarCicloAbierto(
      context,
      cicloId: calculadoraCiclo.calcularPara(_fecha).id,
      cicloRepositorio: widget.cicloRepositorio,
      esCaptura: true,
    );
    if (!puedeCapturar || !mounted) return;

    final aGuardar = <Movimiento>[];
    for (final renglon in _renglones) {
      final resultado = crearMovimiento(
        clientId: _uuid.v4(),
        fecha: _fecha,
        calculadoraCiclo: calculadoraCiclo,
        monto: Dinero.intentarDesdeTexto(renglon.monto.text)!,
        categoriaId: renglon.categoriaId!,
        medio: MedioPago.tarjeta,
        descripcion: renglon.descripcion.text.trim().isEmpty
            ? 'Ticket'
            : renglon.descripcion.text.trim(),
        origenCaptura: OrigenCaptura.ticket,
      );
      switch (resultado) {
        case Falla(:final mensaje):
          setState(() => _error = mensaje);
          return;
        case Exito(:final valor):
          aGuardar.add(
            valor.copyWith(ticketId: _ticketId, fotoUrl: widget.fotoUrl),
          );
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
    final suma = _suma;
    final total = Dinero.intentarDesdeTexto(_totalControlador.text);
    final cuadra = total != null && suma == total;
    final hoy = DateTime.now();
    final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);

    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(title: const Text('Dividir ticket')),
        body: FutureBuilder<List<Categoria>>(
          future: _categorias,
          builder: (context, snapshot) {
            final categorias = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Total del ticket',
                  style: TextStyle(color: ColoresApp.medio),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _totalControlador,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(prefixText: r'$ '),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SelectorFecha(
                  seleccionada: _fecha,
                  onCambio: (f) => setState(() => _fecha = f),
                  primeraFecha: hoySoloFecha.subtract(
                    const Duration(days: 365),
                  ),
                  ultimaFecha: hoySoloFecha,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Renglones',
                  style: TextStyle(color: ColoresApp.medio),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _renglones.length; i++) ...[
                  _TarjetaRenglon(
                    renglon: _renglones[i],
                    categorias: categorias,
                    onCambio: () => setState(() {}),
                    onQuitar: _renglones.length > 1
                        ? () => _quitarRenglon(i)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _agregarRenglon,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar renglón'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cuadra ? ColoresApp.verdeSuave : ColoresApp.fondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Suma de las partes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cuadra
                              ? ColoresApp.verdeTexto
                              : ColoresApp.medio,
                        ),
                      ),
                      Text(
                        suma.formateado(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cuadra
                              ? ColoresApp.verdeTexto
                              : ColoresApp.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: ColoresApp.coralTexto),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _guardando ? null : _registrar,
                  child: Text(
                    _guardando
                        ? 'Registrando…'
                        : 'Registrar los ${_renglones.length}',
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

class _TarjetaRenglon extends StatelessWidget {
  final _Renglon renglon;
  final List<Categoria> categorias;
  final VoidCallback onCambio;
  final VoidCallback? onQuitar;

  const _TarjetaRenglon({
    required this.renglon,
    required this.categorias,
    required this.onCambio,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: renglon.monto,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      prefixText: r'$ ',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => onCambio(),
                  ),
                ),
                if (onQuitar != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: ColoresApp.medio,
                    ),
                    onPressed: onQuitar,
                    tooltip: 'Quitar renglón',
                  ),
              ],
            ),
            TextField(
              controller: renglon.descripcion,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categorias.map((c) {
                final elegida = c.id == renglon.categoriaId;
                return ChoiceChip(
                  label: Text('${c.emoji} ${c.nombre}'),
                  selected: elegida,
                  selectedColor: ColoresApp.violetaSuave,
                  onSelected: (_) {
                    renglon.categoriaId = c.id;
                    onCambio();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
