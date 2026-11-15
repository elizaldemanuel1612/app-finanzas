import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../data/repositorios/categoria_ingreso_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/analisis/reporte_ingresos.dart';
import '../../domain/analisis/resumen_periodo.dart';
import '../../domain/modelos/cuenta.dart';
import '../comun/esqueleto.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'graficas_analisis.dart';
import 'vista_periodo.dart';

/// Análisis › Ingresos (spec-app-finanzas-v2.md §7.3.4): lo que entró a las
/// cuentas, por categoría de ingreso. Solo consulta.
class VistaIngresos extends StatefulWidget {
  final Ciclo ciclo;
  final CategoriaIngresoRepositorio categoriaIngresoRepositorio;
  final CuentaRepositorio cuentaRepositorio;
  final MovimientoCuentaRepositorio movimientoCuentaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;

  const VistaIngresos({
    super.key,
    required this.ciclo,
    required this.categoriaIngresoRepositorio,
    required this.cuentaRepositorio,
    required this.movimientoCuentaRepositorio,
    required this.movimientoRepositorio,
  });

  @override
  State<VistaIngresos> createState() => _VistaIngresosState();
}

enum _Atajo { esteCiclo, esteAnio, ultimos12, elegido }

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _iniciales = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class _VistaIngresosState extends State<VistaIngresos> {
  _Atajo _atajo = _Atajo.esteCiclo;
  late RangoFechas _rango = RangoFechas(widget.ciclo.fechaInicio, widget.ciclo.fechaFin);
  ReporteIngresos? _reporte;

  /// Filtro por cuenta (spec §7.3.4): vacío = todas. Se ofrecen las que no
  /// son de crédito y están activas.
  Set<String> _filtro = {};
  List<Cuenta> _cuentas = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cuentas = await widget.cuentaRepositorio.listarTodas();
    final reporte = calcularReporteIngresos(
      movimientosCuenta: await widget.movimientoCuentaRepositorio.listarTodos(),
      categorias: await widget.categoriaIngresoRepositorio.listarTodas(),
      cuentas: cuentas,
      gastos: await widget.movimientoRepositorio.listarTodos(),
      rango: _rango,
      soloCuentas: _filtro,
    );
    if (!mounted) return;
    setState(() {
      _reporte = reporte;
      _cuentas = [for (final c in cuentas) if (c.activa && c.tipo != TipoCuenta.credito) c];
    });
  }

  /// Una cuenta entra o sale del filtro; sin ninguna, son todas.
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

  Future<void> _elegir(_Atajo atajo) async {
    final hoy = DateTime.now();
    final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
    RangoFechas? rango = switch (atajo) {
      _Atajo.esteCiclo => RangoFechas(widget.ciclo.fechaInicio, widget.ciclo.fechaFin),
      _Atajo.esteAnio => rangoEsteAnio(hoy),
      _Atajo.ultimos12 => rangoUltimos12Meses(hoy),
      _Atajo.elegido => null,
    };
    if (rango == null) {
      final elegido = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: hoyDia,
        // El ciclo en curso termina después de hoy: el calendario llega a hoy.
        initialDateRange: DateTimeRange(
          start: _rango.desde.isAfter(hoyDia) ? hoyDia : _rango.desde,
          end: _rango.hasta.isAfter(hoyDia) ? hoyDia : _rango.hasta,
        ),
        helpText: 'Elige el periodo',
        saveText: 'Ver',
      );
      if (elegido == null) return;
      rango = RangoFechas(elegido.start, elegido.end);
    }
    setState(() {
      _atajo = atajo;
      _rango = rango!;
    });
    await _cargar();
  }

  String _textoRango(RangoFechas r) {
    final mismoAnio = r.desde.year == r.hasta.year;
    final desde = mismoAnio ? fechaCorta(r.desde) : '${fechaCorta(r.desde)} ${r.desde.year}';
    return 'Del $desde al ${fechaCorta(r.hasta)} ${r.hasta.year}';
  }

  @override
  Widget build(BuildContext context) {
    final r = _reporte;
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    if (r == null) {
      return const CargandoPantalla(formas: [Esqueleto(alto: 36, radio: Radios.pill), Esqueleto.tarjeta(alto: 160)]);
    }
    final atajos = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (atajo, texto) in [
            (_Atajo.esteCiclo, 'Este ciclo'),
            (_Atajo.esteAnio, 'Este año'),
            (_Atajo.ultimos12, 'Últimos 12 meses'),
            (_Atajo.elegido, 'Elegir fechas'),
          ])
            ChoiceChip(label: Text(texto), selected: _atajo == atajo, onSelected: (_) => _elegir(atajo)),
        ],
      ),
    );
    // Solo con más de una cuenta hay algo que filtrar.
    final porCuenta = _cuentas.length < 2
        ? null
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas las cuentas'),
                  selected: _filtro.isEmpty,
                  onSelected: (_) => _alternarCuenta(null),
                ),
                for (final c in _cuentas) ...[
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
    final quedo = r.quedo;
    final gastadoPorciento = r.porcentajeGastado;
    final dominante = r.fuenteDominante;
    final principal = r.porCategoria.firstOrNull;
    final indiceAlto = r.mesMasAlto == null ? null : r.meses.indexOf(r.mesMasAlto!);
    final sinCategoria = r.porCategoria.where((c) => c.categoria == null).firstOrNull;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        atajos,
        ?porCuenta,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TarjetaApp(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_textoRango(r.rango), style: textos.etiqueta),
                const SizedBox(height: 6),
                Text('Te entraron', style: textos.etiqueta),
                Text(
                  enPesos(r.total),
                  style: textos.cifraHeroe.copyWith(color: r.vacio ? null : p.exitoTexto),
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                ),
                Text(
                  r.vacio
                      ? 'No hay abonos en estas fechas. Regístralos en Patrimonio → tu cuenta → Registrar abono.'
                      : '${r.conteo} ${r.conteo == 1 ? 'abono' : 'abonos'} · ${enPesos(r.promedioMensual)} al mes en promedio',
                  style: textos.cuerpo,
                ),
              ],
            ),
          ),
        ),
        if (!r.vacio) ...[
          TituloAnalisis(
            etiqueta: 'Contra lo que gastaste',
            titulo: quedo.esNegativo
                ? 'Gastaste ${enPesos(quedo.absoluto)} más de lo que entró'
                : 'Te quedaron ${enPesos(quedo)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TarjetaApp(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BarraProporcion(
                    valor: (r.gastado.centavos / r.total.centavos).clamp(0.0, 1.0),
                    color: quedo.esNegativo ? p.peligro : p.graf1,
                    alto: 10,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: DatoAnalisis(etiqueta: 'Entró', valor: enPesos(r.total))),
                      Expanded(child: DatoAnalisis(etiqueta: 'Gastaste', valor: enPesos(r.gastado))),
                    ],
                  ),
                  if (gastadoPorciento != null) ...[
                    const SizedBox(height: 10),
                    Text('De cada \$100 que entraron, gastaste \$$gastadoPorciento.', style: textos.etiqueta),
                  ],
                  if (_filtro.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Solo cuenta lo que gastaste con las cuentas elegidas.', style: textos.etiqueta),
                  ],
                ],
              ),
            ),
          ),
          TituloAnalisis(
            etiqueta: 'Por categoría',
            titulo: principal?.categoria == null
                ? 'De dónde viene tu dinero'
                : '${principal!.categoria!.nombre} es el ${principal.porcentaje}% de lo que entra',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TarjetaApp.lista(renglones: [
              for (final c in r.porCategoria)
                RenglonApp(
                  emoji: c.categoria?.emoji ?? '❔',
                  titulo: c.categoria?.nombre ?? 'Sin categoría',
                  subtitulo: c.conteo == 1 ? '1 abono' : '${c.conteo} abonos',
                  monto: enPesos(c.total),
                  abajo: Row(
                    children: [
                      Expanded(child: BarraProporcion(valor: c.total.centavos / r.total.centavos, color: p.exito)),
                      const SizedBox(width: 8),
                      Text('${c.porcentaje}%', style: textos.etiqueta),
                    ],
                  ),
                ),
            ]),
          ),
          if (dominante != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                'Casi todo viene de ${dominante.categoria!.nombre}: si esa entrada falla, se nota de inmediato.',
                style: textos.etiqueta,
              ),
            )
          else if (sinCategoria != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                'Elige la categoría al registrar cada abono para que este desglose sea más claro.',
                style: textos.etiqueta,
              ),
            ),
          if (r.meses.length > 1) ...[
            TituloAnalisis(
              etiqueta: 'Mes por mes',
              titulo: r.mesMasAlto == null
                  ? 'Tus meses'
                  : 'Tu mejor mes fue ${_mesesLargos[r.mesMasAlto!.mes - 1]}: ${enPesos(r.mesMasAlto!.total)}',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TarjetaApp(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: GraficaBarras(
                  valores: [for (final m in r.meses) m.total],
                  etiquetas: [for (final m in r.meses) r.meses.length > 6 ? _iniciales[m.mes - 1] : _meses[m.mes - 1]],
                  destacada: indiceAlto,
                  descripcion:
                      'Ingresos por mes: ${[for (final m in r.meses) '${_mesesLargos[m.mes - 1]} ${enPesos(m.total)}'].join(', ')}',
                ),
              ),
            ),
          ],
          if (r.porCuenta.length > 1) ...[
            TituloAnalisis(
              etiqueta: 'A qué cuenta entra',
              titulo: '${r.porCuenta.first.cuenta.nombre} recibe el ${r.porCuenta.first.porcentaje}%',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TarjetaApp.lista(renglones: [
                for (final c in r.porCuenta)
                  RenglonApp(
                    emoji: c.cuenta.emoji,
                    titulo: c.cuenta.nombre,
                    subtitulo: '${c.porcentaje}% de lo que entró',
                    monto: enPesos(c.total),
                  ),
              ]),
            ),
          ],
          if (r.mayor case final mayor?) ...[
            TituloAnalisis(etiqueta: 'Tu ingreso más grande', titulo: enPesos(mayor.monto)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TarjetaApp.lista(renglones: [
                RenglonApp(
                  icono: Icons.south_west_rounded,
                  titulo: mayor.nota.isEmpty ? 'Abono' : mayor.nota,
                  subtitulo: '${fechaCorta(mayor.fecha)} ${mayor.fecha.year}',
                  monto: enPesos(mayor.monto),
                ),
              ]),
            ),
          ],
        ],
      ],
    );
  }
}
