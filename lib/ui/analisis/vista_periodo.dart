import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/analisis/resumen_periodo.dart';
import '../comun/esqueleto.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import 'graficas_analisis.dart';

/// Análisis › Periodo: resumen del año y de cualquier rango de fechas
/// (spec-app-finanzas-v2.md §5.7, 2026-11-15). Solo consulta.
class VistaPeriodo extends StatefulWidget {
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ValueChanged<String> alVerCategoria;

  const VistaPeriodo({
    super.key,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.alVerCategoria,
  });

  @override
  State<VistaPeriodo> createState() => _VistaPeriodoState();
}

enum _Atajo { esteAnio, ultimos12, anioPasado, elegido }

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _iniciales = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class _VistaPeriodoState extends State<VistaPeriodo> {
  _Atajo _atajo = _Atajo.esteAnio;
  late RangoFechas _rango = rangoEsteAnio(DateTime.now());
  ResumenPeriodo? _resumen;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final categorias = await widget.categoriaRepositorio.listarTodas();
    final movimientos = await widget.movimientoRepositorio.listarTodos();
    if (!mounted) return;
    setState(() => _resumen = calcularResumenPeriodo(movimientos: movimientos, categorias: categorias, rango: _rango));
  }

  Future<void> _elegir(_Atajo atajo) async {
    final hoy = DateTime.now();
    RangoFechas? rango = switch (atajo) {
      _Atajo.esteAnio => rangoEsteAnio(hoy),
      _Atajo.ultimos12 => rangoUltimos12Meses(hoy),
      _Atajo.anioPasado => rangoAnioPasado(hoy),
      _Atajo.elegido => null,
    };
    if (rango == null) {
      final elegido = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(hoy.year, hoy.month, hoy.day),
        initialDateRange: DateTimeRange(start: _rango.desde, end: _rango.hasta),
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
    final r = _resumen;
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    // En renglones (Wrap), no en fila desplazable: así los cuatro se ven
    // siempre, también en la web con mouse.
    final atajos = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (atajo, texto) in [
            (_Atajo.esteAnio, 'Este año'),
            (_Atajo.ultimos12, 'Últimos 12 meses'),
            (_Atajo.anioPasado, 'Año pasado'),
            (_Atajo.elegido, 'Elegir fechas'),
          ])
            ChoiceChip(
              label: Text(texto),
              selected: _atajo == atajo,
              // "Elegir fechas" siempre abre el calendario, aunque ya esté elegido.
              onSelected: (_) => _elegir(atajo),
            ),
        ],
      ),
    );
    if (r == null) {
      return const CargandoPantalla(formas: [Esqueleto(alto: 36, radio: Radios.pill), Esqueleto.tarjeta(alto: 160)]);
    }
    final cambio = r.cambioContraAnioAnterior;
    final indiceAlto = r.mesMasAlto == null ? null : r.meses.indexOf(r.mesMasAlto!);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        atajos,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TarjetaApp(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_textoRango(r.rango), style: textos.etiqueta),
                const SizedBox(height: 6),
                Text('Gastaste', style: textos.etiqueta),
                Text(
                  enPesos(r.total),
                  style: textos.cifraHeroe,
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                ),
                Text(
                  r.vacio
                      ? 'No hay gastos registrados en estas fechas.'
                      : '${r.conteo} ${r.conteo == 1 ? 'gasto' : 'gastos'} · ${enPesos(r.promedioMensual)} al mes en promedio',
                  style: textos.cuerpo,
                ),
                if (!r.vacio) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Dato(etiqueta: 'Fijos', valor: enPesos(r.fijas))),
                      Expanded(child: _Dato(etiqueta: 'Variables', valor: enPesos(r.variables))),
                    ],
                  ),
                ],
                if (cambio != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    cambio == 0
                        ? 'Igual que en las mismas fechas de ${r.rango.desde.year - 1}.'
                        : '${cambio.abs()}% ${cambio > 0 ? 'más' : 'menos'} que en las mismas fechas de '
                            '${r.rango.desde.year - 1} (${enPesos(r.totalAnioAnterior!)}).',
                    style: textos.cuerpoFuerte.copyWith(color: cambio > 0 ? p.atencionTexto : p.exitoTexto),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (r.meses.length > 1 && !r.vacio) ...[
          _Titulo(
            etiqueta: 'Mes por mes',
            titulo: r.mesMasAlto == null
                ? 'Tus meses'
                : 'Tu mes más alto fue ${_mesesLargos[r.mesMasAlto!.mes - 1]}: ${enPesos(r.mesMasAlto!.total)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TarjetaApp(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: GraficaBarras(
                valores: [for (final m in r.meses) m.total],
                // Con muchos meses la abreviatura no cabe: solo la inicial.
                etiquetas: [for (final m in r.meses) r.meses.length > 6 ? _iniciales[m.mes - 1] : _meses[m.mes - 1]],
                destacada: indiceAlto,
                descripcion: 'Gasto por mes: ${[for (final m in r.meses) '${_mesesLargos[m.mes - 1]} ${enPesos(m.total)}'].join(', ')}',
              ),
            ),
          ),
        ],
        if (r.categorias.isNotEmpty) ...[
          _Titulo(
            etiqueta: 'Por categoría',
            titulo: '${r.categorias.first.categoria.nombre} se llevó el ${r.categorias.first.porcentaje}%',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TarjetaApp.lista(renglones: [
              for (final g in r.categorias)
                RenglonApp(
                  emoji: g.categoria.emoji,
                  titulo: g.categoria.nombre,
                  monto: enPesos(g.total),
                  onTap: () => widget.alVerCategoria(g.categoria.id),
                  abajo: Row(
                    children: [
                      Expanded(
                        child: BarraProporcion(
                          valor: r.total.esPositivo ? g.total.centavos / r.total.centavos : 0,
                          color: p.graf1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${g.porcentaje}%', style: textos.etiqueta),
                    ],
                  ),
                ),
            ]),
          ),
        ],
        if (r.mayorGasto case final mayor?) ...[
          _Titulo(etiqueta: 'Tu gasto más grande', titulo: '${enPesos(mayor.monto)} en ${mayor.descripcion.isEmpty ? 'un solo gasto' : mayor.descripcion}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TarjetaApp.lista(renglones: [
              RenglonApp(
                icono: Icons.receipt_long_rounded,
                titulo: mayor.descripcion.isEmpty ? 'Sin descripción' : mayor.descripcion,
                subtitulo: '${fechaCorta(mayor.fecha)} ${mayor.fecha.year}',
                monto: enPesos(mayor.monto),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _Dato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(etiqueta, style: textos.etiqueta), Text(valor, style: textos.cuerpoFuerte)],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String etiqueta;
  final String titulo;
  const _Titulo({required this.etiqueta, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: textos.etiqueta),
          Semantics(header: true, child: Text(titulo, style: textos.seccion)),
        ],
      ),
    );
  }
}
