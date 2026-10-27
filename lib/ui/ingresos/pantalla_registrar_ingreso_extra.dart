import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/modelos/ingreso_extra.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../../domain/reglas/creacion_ingreso_extra.dart';
import '../../domain/reglas/monto.dart';
import '../comun/formato_dinero.dart';
import '../comun/popscope_descartar.dart';
import '../comun/selector_fecha.dart';
import '../comun/tema.dart';

const _uuid = Uuid();

/// Registrar un ingreso extra (app-finanzas-ingresos-ajustes-v11.html §1–2):
/// monto, etiqueta, fecha y a dónde va — con vista previa calculada del
/// efecto exacto en meta o presupuesto **antes** de guardar (regla no
/// negociable #20). `repartido` queda fuera del alcance de esta fase; solo
/// se ofrece `apartado` (preseleccionado) y `gasto`.
///
/// Si [ingresoExistente] viene dado, edita en vez de crear: conserva su
/// `id` y `cicloId` — igual que `Movimiento.copyWith`, cambiar de ciclo no
/// es una edición (regla no negociable #5).
class PantallaRegistrarIngresoExtra extends StatefulWidget {
  final Ciclo ciclo;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;
  final IngresoExtra? ingresoExistente;

  const PantallaRegistrarIngresoExtra({
    super.key,
    required this.ciclo,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.ingresoExtraRepositorio,
    this.ingresoExistente,
  });

  @override
  State<PantallaRegistrarIngresoExtra> createState() =>
      _PantallaRegistrarIngresoExtraState();
}

class _PantallaRegistrarIngresoExtraState
    extends State<PantallaRegistrarIngresoExtra> {
  late final _montoControlador = TextEditingController(
    text: _existente == null ? null : textoEditableDeDinero(_existente!.monto),
  );
  late final _etiquetaControlador = TextEditingController(
    text: _existente?.etiqueta,
  );
  late DestinoExtra _destino = _existente?.destino ?? DestinoExtra.apartado;
  late DateTime _fecha = _existente?.fecha ?? _hoyDentroDelCiclo();
  Dinero? _metaBase;
  IngresosDelCiclo? _ingresosBase;
  String? _error;
  bool _guardando = false;

  IngresoExtra? get _existente => widget.ingresoExistente;
  bool get _editando => _existente != null;

  DateTime _hoyDentroDelCiclo() {
    final hoy = DateTime.now();
    if (hoy.isBefore(widget.ciclo.fechaInicio)) return widget.ciclo.fechaInicio;
    if (hoy.isAfter(widget.ciclo.fechaFin)) return widget.ciclo.fechaFin;
    return hoy;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosPrevia();
  }

  /// Carga la meta base (misma fuente única que Inicio y Cierre de ciclo,
  /// [calcularMetaBase]) y los ingresos extra ya activos del ciclo,
  /// **sin** el que se está editando — así la vista previa no cuenta dos
  /// veces su propia contribución al recalcular antes/después.
  Future<void> _cargarDatosPrevia() async {
    final categorias = await widget.categoriaRepositorio.listarActivas();
    final metaBase = calcularMetaBase(perfil: widget.perfil, categorias: categorias);
    final extras = await widget.ingresoExtraRepositorio.listarPorCiclo(widget.ciclo.id);
    final idExistente = _existente?.id;
    final ingresosBase = calcularIngresosDelCiclo(
      ingresoBase: widget.perfil.ingresoBaseMensual,
      cicloId: widget.ciclo.id,
      extras: idExistente == null ? extras : extras.where((e) => e.id != idExistente),
    );
    if (!mounted) return;
    setState(() {
      _metaBase = metaBase;
      _ingresosBase = ingresosBase;
    });
  }

  bool get _hayCambiosSinGuardar =>
      _montoControlador.text !=
          (_existente == null
              ? ''
              : textoEditableDeDinero(_existente!.monto)) ||
      _etiquetaControlador.text != (_existente?.etiqueta ?? '') ||
      _destino != (_existente?.destino ?? DestinoExtra.apartado);

  @override
  void dispose() {
    _montoControlador.dispose();
    _etiquetaControlador.dispose();
    super.dispose();
  }

  /// Antes/después de meta y presupuesto para gastar, ambos recalculados
  /// con [_metaBase] y [_ingresosBase] (que ya excluyen este mismo ingreso
  /// si se está editando) más el monto que se está por guardar — nunca
  /// solo `ingresoBaseMensual + monto`, que ignoraba una meta explícita
  /// (`Perfil.metaApartado`) y cualquier otro extra ya activo del ciclo.
  String? get _vistaPrevia {
    final monto = Dinero.intentarDesdeTexto(_montoControlador.text);
    final metaBase = _metaBase;
    final ingresosBase = _ingresosBase;
    if (monto == null || !monto.esPositivo || metaBase == null || ingresosBase == null) {
      return null;
    }

    final metaActual = calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresosBase);
    final presupuestoActual = ingresosBase.total - metaActual;

    final ingresosConEste = IngresosDelCiclo(
      base: ingresosBase.base,
      extraAApartado: ingresosBase.extraAApartado +
          (_destino == DestinoExtra.apartado ? monto : const Dinero.cero()),
      extraAGasto: ingresosBase.extraAGasto +
          (_destino == DestinoExtra.gasto ? monto : const Dinero.cero()),
    );
    final metaNueva = calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresosConEste);
    final presupuestoNuevo = ingresosConEste.total - metaNueva;

    return switch (_destino) {
      DestinoExtra.apartado =>
        'Tu meta pasa de ${metaActual.formateado()} a ${metaNueva.formateado()}. '
            'Tu presupuesto para gastar no cambia (${presupuestoActual.formateado()}).',
      DestinoExtra.gasto =>
        'Tu presupuesto para gastar pasa de ${presupuestoActual.formateado()} a '
            '${presupuestoNuevo.formateado()}. Tu meta no cambia (${metaActual.formateado()}).',
    };
  }

  Future<void> _guardar() async {
    final monto = Dinero.intentarDesdeTexto(_montoControlador.text);
    if (monto == null) {
      setState(() => _error = 'Escribe un monto válido, ej. 500 o 500.00.');
      return;
    }
    final etiqueta = _etiquetaControlador.text.trim();

    final Resultado<IngresoExtra> resultado;
    final existente = _existente;
    if (existente != null) {
      final montoValido = validarMontoPositivo(
        monto,
        etiqueta: 'monto del ingreso',
      );
      if (montoValido case Falla(:final mensaje)) {
        setState(() => _error = mensaje);
        return;
      }
      if (etiqueta.isEmpty) {
        setState(
          () => _error = 'La etiqueta del ingreso no puede estar vacía.',
        );
        return;
      }
      resultado = Exito(
        existente.copyWith(
          etiqueta: etiqueta,
          monto: monto,
          fecha: _fecha,
          destino: _destino,
        ),
      );
    } else {
      resultado = crearIngresoExtra(
        id: _uuid.v4(),
        fecha: _fecha,
        calculadoraCiclo: widget.perfil.calculadoraCiclo,
        monto: monto,
        etiqueta: etiqueta,
        destino: _destino,
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
        await widget.ingresoExtraRepositorio.guardar(valor);
        if (!mounted) return;
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final ultima = widget.ciclo.fechaFin.isAfter(hoy)
        ? hoy
        : widget.ciclo.fechaFin;

    return PopScopeDescartar(
      hayCambiosSinGuardar: () => _hayCambiosSinGuardar,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar ingreso' : 'Registrar ingreso'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _etiquetaControlador,
                decoration: const InputDecoration(
                  labelText: '¿De dónde vino? (ej. Bono trimestral)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _montoControlador,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formateadoresDeMonto,
                decoration: const InputDecoration(labelText: 'Monto'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              SelectorFecha(
                seleccionada: _fecha,
                onCambio: (f) => setState(() => _fecha = f),
                primeraFecha: widget.ciclo.fechaInicio,
                ultimaFecha: ultima,
              ),
              const SizedBox(height: 20),
              const Text(
                '¿Qué haces con esto?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DestinoExtra>(
                segments: const [
                  ButtonSegment(
                    value: DestinoExtra.apartado,
                    label: Text('Todo al apartado'),
                  ),
                  ButtonSegment(
                    value: DestinoExtra.gasto,
                    label: Text('Todo a gasto'),
                  ),
                ],
                selected: {_destino},
                onSelectionChanged: (s) => setState(() => _destino = s.first),
              ),
              if (_vistaPrevia != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ColoresApp.azulSuave,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    _vistaPrevia!,
                    style: TextStyle(color: ColoresApp.tinta),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: ColoresApp.coralTexto),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(
                  _guardando
                      ? 'Guardando…'
                      : (_editando ? 'Guardar cambios' : 'Registrar ingreso'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
