import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_ingreso_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/cuentas/apartados.dart';
import '../../domain/cuentas/compra_a_meses.dart';
import '../../domain/cuentas/eliminar_cuenta.dart';
import '../../domain/cuentas/fechas_tarjeta.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/categoria_ingreso.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/ingreso_extra.dart';
import '../../domain/modelos/movimiento_cuenta.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/reglas/creacion_ingreso_extra.dart';
import '../categorias/editor_categoria_ingreso.dart';
import '../comun/aviso.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'color_saldo.dart';
import 'frase_pago.dart';
import 'hoja_apartado.dart';
import 'hoja_transferencia.dart';
import 'pantalla_editar_cuenta.dart';
import '../comun/hoja.dart';

const _uuid = Uuid();

/// Una cuenta: su saldo (o lo gastado en el ciclo, si es de crédito), sus
/// movimientos, y registrar abonos o ajustar el saldo (spec §7.3.1).
class PantallaDetalleCuenta extends StatefulWidget {
  final Cuenta cuenta;
  final Perfil perfil;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;

  /// Categorías de ingreso para los abonos (spec §7.3.4); sin él, el abono
  /// no pide categoría.
  final CategoriaIngresoRepositorio? categoriaIngresoRepositorio;

  const PantallaDetalleCuenta({
    super.key,
    required this.cuenta,
    required this.perfil,
    required this.cuentaRepositorio,
    required this.movimientoRepositorio,
    required this.movimientoCuentaRepositorio,
    required this.ingresoExtraRepositorio,
    this.categoriaIngresoRepositorio,
  });

  @override
  State<PantallaDetalleCuenta> createState() => _PantallaDetalleCuentaState();
}

/// Un renglón de la lista: un gasto o un abono/ajuste.
typedef _Renglon = ({DateTime fecha, String texto, Dinero efecto, MovimientoCuenta? deCuenta});

class _PantallaDetalleCuentaState extends State<PantallaDetalleCuenta> {
  late Cuenta _cuenta = widget.cuenta;
  List<Cuenta> _cuentas = const [];
  Dinero? _saldo;
  PagoTarjeta? _pago;

  /// Compras a meses con mensualidades por venir (spec §7.3.1).
  List<CompraAMeses> _compras = const [];
  Dinero _gastadoCiclo = const Dinero.cero();
  List<_Renglon>? _renglones;

  /// Apartados (spec §7.3.5): los de esta cuenta con su saldo, lo que hay
  /// contando todos, y la cuenta donde vive si esta es un apartado.
  List<(Cuenta, Dinero?)> _apartados = const [];
  Dinero? _total;
  Cuenta? _padre;

  /// Qué haría "Eliminar cuenta" (spec §7.3.1).
  QuitarCuenta? _quitar;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cuentas = await widget.cuentaRepositorio.listarTodas();
    final cuenta = cuentas.firstWhere((c) => c.id == _cuenta.id, orElse: () => _cuenta);
    final gastos = await widget.movimientoRepositorio.listarTodos();
    final abonos = await widget.movimientoCuentaRepositorio.listarTodos();
    final ciclo = widget.perfil.calculadoraCiclo.calcularPara(DateTime.now());
    final suyos = [
      for (final g in gastos)
        if (cuentaDe(g) == cuenta.id && g.estado == EstadoMovimiento.activo) g,
    ];
    final nombres = {for (final c in cuentas) c.id: c.nombre};
    final deIngreso = {
      for (final c in await widget.categoriaIngresoRepositorio?.listarTodas() ?? const <CategoriaIngreso>[]) c.id: c,
    };
    String textoDe(MovimientoCuenta a) {
      final nota = a.nota.isEmpty ? '' : ' · ${a.nota}';
      final categoria = deIngreso[a.categoriaIngresoId];
      return switch (a.tipo) {
        // Con categoría de ingreso, ella es el título: "💼 Nómina · Quincena".
        TipoMovimientoCuenta.abono when categoria != null => '${categoria.emoji} ${categoria.nombre}$nota',
        TipoMovimientoCuenta.abono => 'Abono$nota',
        // En ahorro e inversión un ajuste es lo que ganó o perdió de valor.
        TipoMovimientoCuenta.ajuste when cuenta.tipo == TipoCuenta.ahorro =>
          a.efectoEn(cuenta.id).esNegativo ? 'Baja de valor' : 'Rendimiento',
        TipoMovimientoCuenta.ajuste => 'Ajuste de saldo',
        TipoMovimientoCuenta.transferencia when a.cuentaId == cuenta.id =>
          'A ${nombres[a.cuentaDestinoId] ?? 'otra cuenta'}$nota',
        TipoMovimientoCuenta.transferencia => cuenta.tipo == TipoCuenta.credito
            ? 'Pago desde ${nombres[a.cuentaId] ?? 'otra cuenta'}$nota'
            : 'De ${nombres[a.cuentaId] ?? 'otra cuenta'}$nota',
      };
    }

    _cuentas = cuentas;
    final ahora = DateTime.now();
    final finDeHoy = DateTime(ahora.year, ahora.month, ahora.day + 1);
    final renglones = <_Renglon>[
      // Las mensualidades por venir van en "A meses", no en lo que pasó.
      for (final g in suyos)
        if (g.fecha.isBefore(finDeHoy))
          (
            fecha: g.fecha,
            texto: g.esAMeses ? '${g.descripcion} · ${g.mensualidad} de ${g.meses} meses' : g.descripcion,
            efecto: Dinero(-g.monto.centavos),
            deCuenta: null,
          ),
      for (final a in abonos)
        if (a.toca(cuenta.id) && a.estado == EstadoMovimientoCuenta.activo)
          (fecha: a.fecha, texto: textoDe(a), efecto: a.efectoEn(cuenta.id), deCuenta: a),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    if (!mounted) return;
    setState(() {
      _cuenta = cuenta;
      _saldo = saldoDe(cuenta, gastos, abonos);
      _pago = pagoDeTarjeta(cuenta, gastos, abonos, hoy: ahora);
      _compras = comprasAMesesDe(cuenta, gastos, hoy: ahora);
      _gastadoCiclo = Dinero(suyos.where((g) => g.cicloId == ciclo.id).fold(0, (s, g) => s + g.monto.centavos));
      _renglones = renglones.take(60).toList();
      _apartados = [for (final a in apartadosDe(cuenta, cuentas)) (a, saldoDe(a, gastos, abonos))];
      _total = totalConApartados(cuenta, cuentas, gastos, abonos);
      _padre = cuentas.where((c) => c.id == cuenta.cuentaPadreId).firstOrNull;
      _quitar = comoQuitarCuenta(cuenta, cuentas, gastos, abonos);
    });
  }

  Future<void> _editar() async {
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaEditarCuenta(cuentaRepositorio: widget.cuentaRepositorio, existente: _cuenta),
      ),
    );
    if (guardada == true) await _cargar();
  }

  Future<void> _archivar() async {
    await widget.cuentaRepositorio.guardar(_cuenta.copyWith(activa: !_cuenta.activa));
    await _cargar();
  }

  /// "Eliminar cuenta" (spec §7.3.1): se borra si nunca se usó; si tiene
  /// movimientos, se archiva y su historial se conserva.
  Future<void> _eliminarCuenta() async {
    final quitar = _quitar;
    if (quitar == null || quitar == QuitarCuenta.noSePuede) return;
    final nombre = _cuenta.nombre;
    if (quitar == QuitarCuenta.tieneApartados) {
      await showDialog<void>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Primero elimina sus apartados'),
          content: Text(
            '$nombre tiene ${_apartados.length == 1 ? 'un apartado' : '${_apartados.length} apartados'}. '
            'Elimínalos (su dinero regresa a $nombre) y después podrás quitar la cuenta.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Entendido'))],
        ),
      );
      return;
    }
    final borrar = quitar == QuitarCuenta.eliminar;
    final saldo = _saldo;
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Eliminar $nombre?'),
        content: Text(
          borrar
              ? 'No tiene movimientos, así que se borra por completo. '
                  'Si un objetivo se juntaba aquí, después elígele otra cuenta.'
              : 'Tiene movimientos registrados, así que no se borra: se archiva. Deja de verse y de contar '
                  'en tu patrimonio${saldo != null && !saldo.esCero ? ' (hoy marca ${saldo.formateado()})' : ''}, '
                  'y su historial se conserva; puedes reactivarla desde "Ver archivadas". '
                  'Si un objetivo se juntaba aquí, después elígele otra cuenta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.actual.peligroTexto),
            child: Text(borrar ? 'Eliminar' : 'Archivar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    if (borrar) {
      await widget.cuentaRepositorio.eliminar(_cuenta.id);
    } else {
      await widget.cuentaRepositorio.guardar(_cuenta.copyWith(activa: false));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _abonar() async {
    final guardado = await mostrarHoja<bool>(
      context,
      builder: (_) => _HojaAbono(
        cuenta: _cuenta,
        perfil: widget.perfil,
        movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
        ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        categoriaIngresoRepositorio: widget.categoriaIngresoRepositorio,
      ),
    );
    if (guardado == true) await _cargar();
  }

  /// En una de crédito, pagarla; en una de ahorro, aportarle; en las demás,
  /// sacar de ella.
  Future<void> _transferir() async {
    final esCredito = _cuenta.tipo == TipoCuenta.credito || _cuenta.tipo == TipoCuenta.ahorro;
    final hecha = await mostrarHojaTransferencia(
      context,
      cuentas: _cuentas,
      repositorio: widget.movimientoCuentaRepositorio,
      origenId: esCredito ? null : _cuenta.id,
      destinoId: esCredito ? _cuenta.id : null,
    );
    if (hecha == true) await _cargar();
  }

  Future<void> _nuevoApartado() async {
    final creado = await mostrarHojaNuevoApartado(
      context,
      padre: _cuenta,
      disponible: _saldo,
      cuentaRepositorio: widget.cuentaRepositorio,
      movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
    );
    if (creado == true) await _cargar();
  }

  Future<void> _abrirApartado(Cuenta apartado) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PantallaDetalleCuenta(
        cuenta: apartado,
        perfil: widget.perfil,
        cuentaRepositorio: widget.cuentaRepositorio,
        movimientoRepositorio: widget.movimientoRepositorio,
        movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
        ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        categoriaIngresoRepositorio: widget.categoriaIngresoRepositorio,
      ),
    ));
    await _cargar();
  }

  /// Eliminar este apartado (spec §7.3.5): lo que tenga regresa a su
  /// cuenta y el apartado se archiva; el historial se conserva.
  Future<void> _eliminarApartado() async {
    final padre = _padre;
    final saldo = _saldo ?? const Dinero.cero();
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Eliminar ${_cuenta.nombre}?'),
        content: Text(
          '${saldo.esPositivo ? 'Los ${saldo.formateado()} que tiene regresan a ${padre?.nombre ?? 'su cuenta'}. ' : ''}'
          'Si un objetivo se juntaba aquí, después elígele otra cuenta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: TextButton.styleFrom(foregroundColor: ColoresApp.actual.peligroTexto),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    final r = eliminarApartado(apartado: _cuenta, saldo: saldo, clientId: _uuid.v4(), ahora: DateTime.now());
    if (r == null) return;
    final liberacion = r.liberacion;
    if (liberacion != null) await widget.movimientoCuentaRepositorio.guardar(liberacion);
    await widget.cuentaRepositorio.guardar(r.archivado);
    if (mounted) Navigator.of(context).pop();
  }

  /// Guardar en este apartado (desde su cuenta) o sacar de él (a su cuenta).
  Future<void> _moverConPadre({required bool guardar}) async {
    final padre = _padre;
    if (padre == null) return;
    final hecha = await mostrarHojaTransferencia(
      context,
      cuentas: _cuentas,
      repositorio: widget.movimientoCuentaRepositorio,
      origenId: guardar ? padre.id : _cuenta.id,
      destinoId: guardar ? _cuenta.id : padre.id,
    );
    if (hecha == true) await _cargar();
  }

  Future<void> _ajustar() async {
    final esCredito = _cuenta.tipo == TipoCuenta.credito;
    final actual = _saldo ?? const Dinero.cero();
    final limite = esCredito ? _cuenta.limite : null;
    final respuesta = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => _DialogoAjuste(
        saldo: esCredito ? Dinero(-actual.centavos) : actual,
        esCredito: esCredito,
        esAhorro: _cuenta.tipo == TipoCuenta.ahorro,
        limite: limite,
      ),
    );
    if (respuesta == null) return;
    final (texto, porDisponible) = respuesta;
    final limpio = texto.replaceAll(RegExp(r'[\$\s]'), '');
    final negativo = limpio.startsWith('-');
    final deseado = Dinero.intentarDesdeTexto(negativo ? limpio.substring(1) : limpio);
    if (deseado == null) return;
    var escrito = negativo ? Dinero(-deseado.centavos) : deseado;
    // Si escribió su crédito disponible, lo que debe es límite − disponible.
    if (porDisponible && limite != null) escrito = deudaDesdeDisponible(limite: limite, disponible: escrito);
    final ajuste = ajusteParaSaldo(
      actual: actual,
      // En crédito se escribe lo que se debe: el saldo es lo contrario.
      deseado: esCredito ? Dinero(-escrito.centavos) : escrito,
    );
    if (ajuste == null) return;
    await widget.movimientoCuentaRepositorio.guardar(MovimientoCuenta(
      clientId: _uuid.v4(),
      cuentaId: _cuenta.id,
      fecha: DateTime.now(),
      monto: ajuste.monto,
      tipo: TipoMovimientoCuenta.ajuste,
      entra: ajuste.entra,
    ));
    await _cargar();
  }

  /// Anula el abono o ajuste; si el abono creó un ingreso del ciclo, también.
  Future<void> _anular(MovimientoCuenta m) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(switch (m.tipo) {
          TipoMovimientoCuenta.abono => '¿Eliminar este abono?',
          TipoMovimientoCuenta.ajuste => '¿Eliminar este ajuste?',
          TipoMovimientoCuenta.transferencia => '¿Eliminar esta transferencia?',
        }),
        content: Text(
          m.ingresoExtraId == null ? m.monto.formateado() : '${m.monto.formateado()}. También se quita de tus ingresos del ciclo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (si != true) return;
    await widget.movimientoCuentaRepositorio.anular(m.clientId);
    final ingreso = m.ingresoExtraId;
    if (ingreso != null) await widget.ingresoExtraRepositorio.anular(ingreso);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final renglones = _renglones;
    final saldo = _saldo;
    final esEfectivoBase = _cuenta.id == idCuentaEfectivo;
    final esCredito = _cuenta.tipo == TipoCuenta.credito;
    final esAhorro = _cuenta.tipo == TipoCuenta.ahorro;
    final apartado = _cuenta.esApartado;
    final conApartados = _cuenta.puedeTenerApartados && _cuenta.activa && saldo != null;
    final lectura = saldo == null ? null : lecturaDeSaldo(_cuenta, saldo);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_cuenta.emoji} ${_cuenta.nombre}'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: _editar),
          if (!esEfectivoBase && !_cuenta.esApartado)
            IconButton(
              icon: Icon(_cuenta.activa ? Icons.archive_outlined : Icons.unarchive_outlined),
              tooltip: _cuenta.activa ? 'Archivar' : 'Reactivar',
              onPressed: _archivar,
            ),
        ],
      ),
      body: renglones == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lectura?.etiqueta ?? 'Gastado este ciclo', style: textos.bodySmall),
                        Text(
                          (lectura?.monto ?? _gastadoCiclo).formateado(),
                          style: textos.displaySmall?.copyWith(
                            color: lectura == null ? null : colorDeLectura(lectura),
                          ),
                        ),
                        if (lectura?.disponible case final disponible?)
                          Text(
                            disponible.esNegativo
                                ? 'Te pasaste ${Dinero(-disponible.centavos).formateado()} de tu límite de ${_cuenta.limite!.formateado()}.'
                                : 'Disponible: ${disponible.formateado()} de ${_cuenta.limite!.formateado()}',
                            style: textos.bodySmall?.copyWith(color: disponible.esNegativo ? ColoresApp.coralTexto : null),
                          ),
                        if (_apartados.isNotEmpty && _total != null)
                          Text('Con tus apartados: ${_total!.formateado()}', style: textos.bodySmall),
                        if (saldo != null && saldo.esNegativo && !esCredito)
                          Text('Gastaste más de lo que tenías.', style: textos.bodySmall?.copyWith(color: ColoresApp.coralTexto)),
                        if (saldo != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            apartado
                                ? 'Apartado en ${_padre?.nombre ?? 'otra cuenta'}. Guarda desde ella o saca para usarlo.'
                                : esAhorro
                                    ? 'Cuenta para tu patrimonio. Transfiérele lo que apartas y actualiza su valor cuando cambie.'
                                    : 'Gastado este ciclo: ${_gastadoCiclo.formateado()}',
                            style: textos.bodySmall,
                          ),
                          if (apartado && _padre != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _moverConPadre(guardar: true),
                                    child: const Text('Guardar'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _moverConPadre(guardar: false),
                                    child: const Text('Sacar'),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton(onPressed: _ajustar, child: const Text('Actualizar valor')),
                                const Spacer(),
                                TextButton(
                                  onPressed: _eliminarApartado,
                                  style: TextButton.styleFrom(foregroundColor: ColoresApp.actual.peligroTexto),
                                  child: const Text('Eliminar apartado'),
                                ),
                              ],
                            ),
                          ] else ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _abonar,
                                  child: Text(esCredito || esAhorro ? 'Abonar' : 'Registrar abono'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _ajustar,
                                  child: Text(esCredito
                                      ? 'Ajustar deuda'
                                      : esAhorro
                                          ? 'Actualizar valor'
                                          : 'Ajustar saldo'),
                                ),
                              ),
                            ],
                          ),
                          ],
                        ] else ...[
                          const SizedBox(height: 8),
                          TextButton(onPressed: _editar, child: Text(esCredito ? 'Llevar lo que debes' : 'Llevar su saldo')),
                        ],
                        if (!apartado && _cuentas.where((c) => c.activa).length > 1) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _transferir,
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: Text(esCredito
                                ? 'Pagar esta tarjeta'
                                : esAhorro
                                    ? 'Aportar desde otra cuenta'
                                    : 'Transferir a otra cuenta'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Corte y fecha de pago (spec §7.3.1): cuánto y antes de
                // cuándo; si falta pagar, la salida es pagarla.
                if (_pago case final pago?) ...[
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final frases = frasesDePago(pago);
                    final pagar = pago.estado != EstadoPagoTarjeta.sinPendiente &&
                        _cuentas.where((c) => c.activa).length > 1;
                    return Aviso(
                      tono: frases.tono,
                      titulo: frases.titulo,
                      apoyo: frases.apoyo,
                      accion: pagar ? 'Pagar esta tarjeta' : null,
                      onAccion: pagar ? _transferir : null,
                    );
                  }),
                ] else if (esCredito && _cuenta.activa) ...[
                  const SizedBox(height: 12),
                  Aviso.info(
                    titulo: '¿Cuándo corta y cuándo se paga?',
                    apoyo: 'Agrega los días y te avisamos cuánto pagar.',
                    accion: 'Agregar',
                    onAccion: _editar,
                  ),
                ],
                if (_compras.isNotEmpty) ...[
                  EncabezadoSeccion(
                    titulo: 'A meses sin intereses',
                    dato: 'Faltan ${enPesos(Dinero.suma(_compras.map((c) => c.falta)))}',
                  ),
                  TarjetaApp.lista(renglones: [
                    for (final c in _compras)
                      RenglonApp(
                        icono: Icons.calendar_view_month_outlined,
                        titulo: c.descripcion,
                        subtitulo: !c.porEmpezar
                            ? '${enPesos(c.mensualidad)} al mes · van ${c.pagadas} de ${c.meses}'
                            : c.unSoloPago
                                ? 'Un solo pago en ${mesEnPalabras(c.primerPago, hoy: DateTime.now())}'
                                : 'Empiezas en ${mesEnPalabras(c.primerPago, hoy: DateTime.now())} · '
                                    '${c.meses} de ${enPesos(c.mensualidad)}',
                        monto: c.falta.formateado(),
                      ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Ya cuentan en lo que debes, pero cada corte solo te pide su mensualidad. '
                      'El resumen de todas está en Análisis → A meses.',
                      style: textos.etiqueta,
                    ),
                  ),
                ],
                if (conApartados) ...[
                  EncabezadoSeccion(
                    titulo: 'Apartados',
                    dato: _apartados.isEmpty
                        ? null
                        : enPesos(Dinero(_apartados.fold<int>(0, (t, a) => t + (a.$2?.centavos ?? 0)))),
                  ),
                  if (_apartados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Separa tu dinero para algo —un viaje, tu fondo de emergencia— sin sacarlo de '
                        '${_cuenta.nombre}, como en tu banco.',
                        style: textos.etiqueta,
                      ),
                    )
                  else
                    TarjetaApp.lista(renglones: [
                      for (final (a, s) in _apartados)
                        RenglonApp(
                          emoji: a.emoji,
                          titulo: a.nombre,
                          monto: s?.formateado(),
                          onTap: () => _abrirApartado(a),
                        ),
                    ]),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _nuevoApartado,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuevo apartado'),
                  ),
                ],
                const SizedBox(height: 12),
                if (renglones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aún no hay movimientos con esta cuenta.', textAlign: TextAlign.center, style: textos.bodySmall),
                  ),
                for (final r in renglones)
                  ListTile(
                    onTap: r.deCuenta == null ? null : () => _anular(r.deCuenta!),
                    title: Text(r.texto),
                    subtitle: Text('${r.fecha.day}/${r.fecha.month}/${r.fecha.year}'),
                    trailing: Text(
                      '${r.efecto.esNegativo ? '−' : '+'}${Dinero(r.efecto.centavos.abs()).formateado()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.efecto.esNegativo ? ColoresApp.tinta : ColoresApp.verdeTexto,
                      ),
                    ),
                  ),
                // Una archivada con historial ya no tiene nada más que quitar.
                if (!apartado &&
                    _quitar != null &&
                    _quitar != QuitarCuenta.noSePuede &&
                    (_cuenta.activa || _quitar == QuitarCuenta.eliminar)) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _eliminarCuenta,
                    style: TextButton.styleFrom(foregroundColor: ColoresApp.actual.peligroTexto),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar cuenta'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _HojaAbono extends StatefulWidget {
  final Cuenta cuenta;
  final Perfil perfil;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;
  final CategoriaIngresoRepositorio? categoriaIngresoRepositorio;

  const _HojaAbono({
    required this.cuenta,
    required this.perfil,
    required this.movimientoCuentaRepositorio,
    required this.ingresoExtraRepositorio,
    this.categoriaIngresoRepositorio,
  });

  @override
  State<_HojaAbono> createState() => _HojaAbonoState();
}

class _HojaAbonoState extends State<_HojaAbono> {
  bool get _esCredito => widget.cuenta.tipo == TipoCuenta.credito;

  final _monto = TextEditingController();
  final _nota = TextEditingController();
  bool _esIngreso = false;
  String? _error;
  bool _guardando = false;

  /// Solo categorías de ingreso, y solo las activas (spec §7.3.4). En una
  /// tarjeta de crédito no se piden: un abono ahí baja la deuda.
  List<CategoriaIngreso> _categorias = const [];
  String? _categoriaId;

  bool get _pideCategoria => !_esCredito && widget.categoriaIngresoRepositorio != null;

  @override
  void initState() {
    super.initState();
    if (_pideCategoria) _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final todas = await widget.categoriaIngresoRepositorio!.listarTodas();
    if (mounted) setState(() => _categorias = [for (final c in todas) if (c.activa) c]);
  }

  Future<void> _nuevaCategoria() async {
    final creada = await mostrarEditorCategoriaIngreso(context, repositorio: widget.categoriaIngresoRepositorio!);
    if (creada == null) return;
    await _cargarCategorias();
    if (mounted) setState(() => _categoriaId = creada.id);
  }

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = Dinero.intentarDesdeTexto(_monto.text);
    if (monto == null || !monto.esPositivo) {
      setState(() => _error = 'Escribe cuánto entró, mayor a 0.');
      return;
    }
    setState(() => _guardando = true);
    final ahora = DateTime.now();
    final nota = _nota.text.trim();
    final categoria = _categorias.where((c) => c.id == _categoriaId).firstOrNull;
    String? ingresoId;
    if (_esIngreso) {
      final ingreso = crearIngresoExtra(
        id: _uuid.v4(),
        fecha: ahora,
        calculadoraCiclo: widget.perfil.calculadoraCiclo,
        monto: monto,
        etiqueta: nota.isNotEmpty ? nota : (categoria?.nombre ?? 'Abono a ${widget.cuenta.nombre}'),
        destino: DestinoExtra.apartado,
      );
      if (ingreso case Exito(:final valor)) {
        await widget.ingresoExtraRepositorio.guardar(valor);
        ingresoId = valor.id;
      }
    }
    await widget.movimientoCuentaRepositorio.guardar(MovimientoCuenta(
      clientId: _uuid.v4(),
      cuentaId: widget.cuenta.id,
      fecha: ahora,
      monto: monto,
      tipo: TipoMovimientoCuenta.abono,
      entra: true,
      nota: nota,
      ingresoExtraId: ingresoId,
      categoriaIngresoId: categoria?.id,
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_esCredito ? 'Abono o devolución a' : 'Abono a'} ${widget.cuenta.nombre}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _monto,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: formateadoresDeMonto,
            decoration: InputDecoration(labelText: _esCredito ? '¿Cuánto bajó tu deuda?' : '¿Cuánto entró?', prefixText: '\$ ', errorText: _error),
          ),
          if (_pideCategoria) ...[
            const SizedBox(height: 14),
            Text('¿De dónde viene?', style: textos.etiqueta),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categorias)
                  ChoiceChip(
                    label: Text('${c.emoji} ${c.nombre}'),
                    selected: _categoriaId == c.id,
                    // Tocar la elegida la quita: la categoría es opcional.
                    onSelected: (sel) => setState(() => _categoriaId = sel ? c.id : null),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nueva'),
                  onPressed: _nuevaCategoria,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _nota,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nota (opcional)', hintText: _esCredito ? 'Devolución de Liverpool' : 'Quincena'),
          ),
          // Un abono a la tarjeta de crédito baja la deuda, no es dinero
          // que te entra.
          if (!_esCredito)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _esIngreso,
              onChanged: (v) => setState(() => _esIngreso = v ?? false),
              title: const Text('También es ingreso de este ciclo'),
              subtitle: const Text('Se suma a lo que te entra, como un ingreso extra.'),
            ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar abono')),
        ],
        ),
      ),
    );
  }
}

/// Dueño de su propio controlador: si lo desecha quien abre el diálogo, el
/// campo todavía se dibuja durante la animación de cierre y truena.
class _DialogoAjuste extends StatefulWidget {
  final Dinero saldo;

  final bool esCredito;

  /// Ahorro o inversión: se pregunta cuánto vale hoy.
  final bool esAhorro;

  /// Con límite, en crédito se puede ajustar escribiendo lo que se debe o
  /// el crédito disponible (2026-11-07).
  final Dinero? limite;

  const _DialogoAjuste({required this.saldo, this.esCredito = false, this.esAhorro = false, this.limite});

  @override
  State<_DialogoAjuste> createState() => _DialogoAjusteState();
}

class _DialogoAjusteState extends State<_DialogoAjuste> {
  late final _controlador = TextEditingController(text: textoEditableDeDinero(widget.saldo));

  /// `true`: lo escrito es el crédito disponible, no lo que se debe.
  bool _porDisponible = false;

  /// Al cambiar de modo, el número del campo se convierte (deuda ↔
  /// disponible) para que siga diciendo lo mismo.
  void _cambiarModo(bool porDisponible) {
    final limite = widget.limite;
    if (limite == null || porDisponible == _porDisponible) return;
    final actual = Dinero.intentarDesdeTexto(_controlador.text.replaceAll(RegExp(r'[\$\s]'), ''));
    setState(() {
      _porDisponible = porDisponible;
      if (actual != null) {
        // límite − x convierte en los dos sentidos.
        _controlador.text = textoEditableDeDinero(deudaDesdeDisponible(limite: limite, disponible: actual));
      }
    });
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.esCredito
          ? 'Ajustar lo que debes'
          : widget.esAhorro
              ? 'Actualizar valor'
              : 'Ajustar saldo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.esCredito && widget.limite != null) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Lo que debo')),
                ButtonSegment(value: true, label: Text('Disponible')),
              ],
              selected: {_porDisponible},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _cambiarModo(s.first),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controlador,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: widget.esAhorro
                  ? '¿Cuánto vale hoy?'
                  : !widget.esCredito
                      ? '¿Cuánto dice tu banco?'
                  : _porDisponible
                      ? 'Crédito disponible'
                      : 'Lo que debes según tu banco',
              prefixText: '\$ ',
              helperText: _porDisponible ? 'Con tu límite de ${widget.limite!.formateado()} calculamos lo que debes.' : null,
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(context, (_controlador.text, _porDisponible)),
          child: const Text('Ajustar'),
        ),
      ],
    );
  }
}
