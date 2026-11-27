import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/cuentas/compra_a_meses.dart';
import '../../domain/cuentas/resumen_a_meses.dart';
import '../../domain/modelos/cuenta.dart';
import '../comun/chip_estado.dart';
import '../comun/esqueleto.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'graficas_analisis.dart';
import 'vista_periodo.dart';

/// Análisis › A meses (spec-app-finanzas-v2.md §7.3.1, 2026-11-27): cuánto
/// se debe a meses sin intereses, cuánto se paga al mes solo de eso y cómo
/// va cada compra, para tenerlo presente antes de endeudarse más. Solo
/// consulta; se filtra por tarjeta.
class VistaAMeses extends StatefulWidget {
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;

  /// El ingreso del ciclo, para decir qué parte se va a meses.
  final Dinero ingreso;

  /// Para probar con una fecha fija.
  final DateTime? hoy;

  const VistaAMeses({
    super.key,
    required this.cuentaRepositorio,
    required this.movimientoRepositorio,
    required this.ingreso,
    this.hoy,
  });

  @override
  State<VistaAMeses> createState() => _VistaAMesesState();
}

const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Arriba de esta parte del ingreso se avisa en ámbar; arriba de la
/// segunda, en rojo. Guía general, no asesoría (Ajustes → aviso).
const _porcentajeAtencion = 10;
const _porcentajePeligro = 20;

class _VistaAMesesState extends State<VistaAMeses> {
  ResumenAMeses? _resumen;
  ResumenAMeses? _todas;
  Map<String, Cuenta> _cuentas = const {};
  List<Cuenta> _filtrables = const [];

  /// Vacío = todas las tarjetas.
  Set<String> _filtro = {};

  DateTime get _hoy => widget.hoy ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cuentas = await widget.cuentaRepositorio.listarTodas();
    final gastos = await widget.movimientoRepositorio.listarTodos();
    final todas = resumirComprasAMeses(gastos: gastos, hoy: _hoy);
    final resumen = _filtro.isEmpty ? todas : resumirComprasAMeses(gastos: gastos, hoy: _hoy, soloCuentas: _filtro);
    if (!mounted) return;
    setState(() {
      _todas = todas;
      _resumen = resumen;
      _cuentas = {for (final c in cuentas) c.id: c};
      _filtrables = cuentasConMeses(cuentas, todas);
    });
  }

  Future<void> _alternarCuenta(String? id) async {
    setState(() {
      if (id == null) {
        _filtro = {};
      } else {
        _filtro = {..._filtro};
        if (!_filtro.remove(id)) _filtro.add(id);
      }
    });
    await _cargar();
  }

  String _nombreCuenta(String id) {
    final c = _cuentas[id];
    return c == null ? 'Cuenta eliminada' : '${c.emoji} ${c.nombre}';
  }

  String _mes(DateTime f) => mesEnPalabras(f, hoy: _hoy);

  @override
  Widget build(BuildContext context) {
    final r = _resumen;
    final todas = _todas;
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    if (r == null || todas == null) {
      return const CargandoPantalla(formas: [Esqueleto.tarjeta(alto: 160), Esqueleto.tarjeta(alto: 120)]);
    }
    if (todas.vacio) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TarjetaApp(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No debes nada a meses', style: textos.cuerpoFuerte),
                const SizedBox(height: 6),
                Text(
                  'Cuando registres una compra con tu tarjeta de crédito a meses sin intereses '
                  '(Registrar → Meses), aquí verás cuánto debes, cuánto pagas al mes y cómo va cada compra.',
                  style: textos.cuerpo,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final porcentaje = r.porcentajeDe(widget.ingreso);
    final tono = porcentaje == null || porcentaje < _porcentajeAtencion
        ? TonoEstado.exito
        : porcentaje < _porcentajePeligro
            ? TonoEstado.atencion
            : TonoEstado.peligro;
    final alivio = r.primerAlivio;
    final aumento = r.primerAumento;
    final ultimo = r.ultimoPago;
    final maximo = r.proximosMeses.reduce((a, b) => b.monto > a.monto ? b : a);

    final filtro = _filtrables.length < 2
        ? null
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas las tarjetas'),
                  selected: _filtro.isEmpty,
                  onSelected: (_) => _alternarCuenta(null),
                ),
                for (final c in _filtrables) ...[
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('${c.emoji} ${c.nombre}'),
                    selected: _filtro.contains(c.id),
                    onSelected: (_) => _alternarCuenta(c.id),
                  ),
                ],
              ],
            ),
          );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ?filtro,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TarjetaApp(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Debes a meses sin intereses', style: textos.etiqueta),
                Text(
                  enPesos(r.debes),
                  style: textos.cifraHeroe,
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                ),
                Text(
                  '${r.compras.length} ${r.compras.length == 1 ? 'compra' : 'compras'}'
                  '${ultimo == null ? '' : ' · terminas de pagar en ${_mes(ultimo)}'}',
                  style: textos.cuerpo,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: DatoAnalisis(etiqueta: 'Este mes pagas', valor: enPesos(r.esteMes))),
                    Expanded(child: DatoAnalisis(etiqueta: 'Llevas pagado', valor: enPesos(r.pagado))),
                  ],
                ),
                const SizedBox(height: 12),
                BarraProporcion(
                  valor: r.total.esPositivo ? (r.pagado.centavos / r.total.centavos).clamp(0.0, 1.0) : 0,
                  color: p.graf1,
                  alto: 10,
                ),
                const SizedBox(height: 6),
                Text('${enPesos(r.pagado)} de ${enPesos(r.total)} de estas compras', style: textos.etiqueta),
                if (porcentaje != null && r.esteMes.esPositivo) ...[
                  const SizedBox(height: 14),
                  ChipEstado(
                    tono: tono,
                    texto: switch (tono) {
                      TonoEstado.exito => 'Bajo control',
                      TonoEstado.atencion => 'Pesa en tu ingreso',
                      _ => 'Ya es mucho',
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'De cada \$100 que ganas, \$$porcentaje se van a meses este mes.'
                    '${tono == TonoEstado.exito ? '' : ' Antes de otra compra a meses, piensa si cabe con lo que ya pagas.'}',
                    style: textos.cuerpo,
                  ),
                ],
              ],
            ),
          ),
        ),
        TituloAnalisis(
          etiqueta: 'Lo que pagas cada mes',
          // Que suba (una compra diferida que empieza) importa más que
          // cuándo baja.
          titulo: aumento != null
              ? 'En ${_mes(aumento.mes)} sube a ${enPesos(aumento.monto)}'
              : alivio != null
                  ? 'En ${_mes(alivio.mes)} baja a ${enPesos(alivio.monto)}'
                  : 'Sigue en ${enPesos(r.esteMes)} al mes',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TarjetaApp(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: GraficaBarras(
              valores: [for (final m in r.proximosMeses) m.monto],
              etiquetas: [for (final m in r.proximosMeses) _mesesCortos[m.mes.month - 1]],
              destacada: 0,
              descripcion: 'Lo que pagas a meses en los próximos 12 meses: este mes ${enPesos(r.esteMes)}, '
                  'el más alto ${enPesos(maximo.monto)} en ${_mes(maximo.mes)}.',
            ),
          ),
        ),
        if (r.porEmpezar.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              '${r.porEmpezar.length == 1 ? 'Una compra aún no te cobra' : '${r.porEmpezar.length} compras aún no te cobran'}'
              ' (compraste hoy, pagas después): ya cuentan en lo que debes y aparecen en la gráfica desde su primer pago.',
              style: textos.etiqueta,
            ),
          ),
        if (_filtro.isEmpty && r.porCuenta.length > 1) ...[
          TituloAnalisis(
            etiqueta: 'Por tarjeta',
            titulo: 'Debes más en ${_nombreCuenta(r.porCuenta.first.cuentaId)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TarjetaApp.lista(renglones: [
              for (final c in r.porCuenta)
                RenglonApp(
                  titulo: _nombreCuenta(c.cuentaId),
                  subtitulo: '${c.compras} ${c.compras == 1 ? 'compra' : 'compras'} · este mes ${enPesos(c.esteMes)}',
                  monto: c.debes.formateado(),
                  onTap: () => _alternarCuenta(c.cuentaId),
                ),
            ]),
          ),
        ],
        TituloAnalisis(
          etiqueta: 'Cada compra',
          titulo: r.compras.length == 1 ? 'Te falta ${enPesos(r.debes)}' : 'Lo que te falta de cada una',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TarjetaApp.lista(renglones: [for (final c in r.compras) _renglon(c, p)]),
        ),
      ],
    );
  }

  Widget _renglon(CompraAMeses c, Paleta p) {
    final cuenta = _filtrables.length > 1 && _filtro.length != 1 ? ' · ${_nombreCuenta(c.cuentaId)}' : '';
    final String detalle;
    if (c.porEmpezar) {
      detalle = c.unSoloPago
          ? 'Un solo pago en ${_mes(c.primerPago)}'
          : 'Empiezas en ${_mes(c.primerPago)} · ${c.meses} de ${enPesos(c.mensualidad)}';
    } else {
      detalle = '${enPesos(c.mensualidad)} al mes · van ${c.pagadas} de ${c.meses}';
    }
    return RenglonApp(
      icono: c.porEmpezar ? Icons.schedule_rounded : Icons.calendar_view_month_outlined,
      titulo: c.descripcion.isEmpty ? 'Compra a meses' : c.descripcion,
      subtitulo: '$detalle$cuenta',
      monto: c.falta.formateado(),
      etiquetaSemantica: '${c.descripcion}: te faltan ${enPesos(c.falta)} de ${enPesos(c.total)}. $detalle',
      abajo: BarraProporcion(
        valor: c.meses == 0 ? 0 : (c.pagadas / c.meses).clamp(0.0, 1.0),
        color: p.graf1,
      ),
    );
  }
}
