import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/analisis/recomendaciones.dart';
import '../../domain/analisis/reporte_analisis.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../comun/aviso_gesto.dart';
import '../comun/tema.dart';
import 'graficas_analisis.dart';

/// Pestaña Análisis (spec-app-finanzas-v2.md §5.7): reportes y
/// recomendaciones del ciclo en curso. Todo el cálculo vive en
/// `domain/analisis/`; aquí solo se carga y se dibuja.
class PantallaAnalisis extends StatefulWidget {
  final Perfil perfil;
  final Ciclo ciclo;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final AjustePresupuestoCicloRepositorio ajustePresupuestoCicloRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;

  /// Salidas de las recomendaciones (regla #22), las provee Inicio.
  final void Function(String categoriaId) alVerCategoria;
  final VoidCallback alVerGastos;
  final VoidCallback alVerMeta;

  const PantallaAnalisis({
    super.key,
    required this.perfil,
    required this.ciclo,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.ajustePresupuestoCicloRepositorio,
    required this.ingresoExtraRepositorio,
    required this.alVerCategoria,
    required this.alVerGastos,
    required this.alVerMeta,
  });

  @override
  State<PantallaAnalisis> createState() => _PantallaAnalisisState();
}

class _Datos {
  final ReporteAnalisis reporte;
  final List<Recomendacion> recomendaciones;

  const _Datos(this.reporte, this.recomendaciones);
}

class _PantallaAnalisisState extends State<PantallaAnalisis> {
  _Datos? _datos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final ciclo = widget.ciclo;
    final todas = await widget.categoriaRepositorio.listarTodas();
    final ajustes = await widget.ajustePresupuestoCicloRepositorio.listarPorCiclo(ciclo.id);
    final movimientos = await widget.movimientoRepositorio.listarTodos();
    final extras = await widget.ingresoExtraRepositorio.listarPorCiclo(ciclo.id);

    final efectivas = presupuestosEfectivosParaCiclo(base: todas, ajustesDelCiclo: ajustes);
    final anterior = widget.perfil.calculadoraCiclo.calcularPara(
      ciclo.fechaInicio.subtract(const Duration(days: 1)),
    );
    final reporte = calcularReporteAnalisis(
      ciclo: ciclo,
      cicloAnterior: anterior,
      movimientos: movimientos,
      categorias: efectivas,
      hoy: DateTime.now(),
    );
    final ingresos = calcularIngresosDelCiclo(
      ingresoBase: widget.perfil.ingresoBaseMensual,
      cicloId: ciclo.id,
      extras: extras,
    );
    final metaBase = calcularMetaBase(
      perfil: widget.perfil,
      categorias: [for (final c in todas) if (c.activa) c],
    );
    final recomendaciones = calcularRecomendaciones(
      reporte: reporte,
      ingresoCiclo: ingresos.total,
      metaCiclo: calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresos),
    );
    if (!mounted) return;
    setState(() => _datos = _Datos(reporte, recomendaciones));
  }

  void _accion(Recomendacion r) {
    switch (r.accion) {
      case AccionRecomendacion.verCategoria:
        widget.alVerCategoria(r.categoriaId!);
      case AccionRecomendacion.verGastos:
        widget.alVerGastos();
      case AccionRecomendacion.verMeta:
        widget.alVerMeta();
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ciclo ${widget.ciclo.etiqueta}', style: Theme.of(context).textTheme.labelSmall),
            const Text('Análisis'),
          ],
        ),
      ),
      body: datos == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _cargar();
                if (context.mounted) await avisarGestoPrimeraVez(context, GestoApp.recargar);
              },
              child: datos.reporte.sinMovimientos ? _vacio(context) : _contenido(context, datos),
            ),
    );
  }

  Widget _vacio(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: ColoresApp.oroSuave, shape: BoxShape.circle),
            child: Icon(Icons.insights_rounded, size: 40, color: ColoresApp.oroTexto),
          ),
        ),
        const SizedBox(height: 20),
        Text('Aquí verás tu análisis', textAlign: TextAlign.center, style: textos.titleMedium),
        const SizedBox(height: 8),
        Text(
          'En cuanto registres tus primeros gastos del ciclo, aparecen tus reportes, '
          'cómo vas contra el ciclo pasado y recomendaciones para llegar a tu meta.',
          textAlign: TextAlign.center,
          style: textos.bodySmall,
        ),
      ],
    );
  }

  Widget _contenido(BuildContext context, _Datos datos) {
    final r = datos.reporte;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _Resumen(reporte: r),
        if (datos.recomendaciones.isNotEmpty) ...[
          const _Titulo('Para ti', subtitulo: 'Lo más importante de tu ciclo, primero'),
          for (final rec in datos.recomendaciones) _TarjetaRecomendacion(rec, alTocar: () => _accion(rec)),
        ],
        const _Titulo('¿En qué se va?'),
        _EnQueSeVa(reporte: r, alVerCategoria: widget.alVerCategoria),
        if (r.presupuestoVariables.esPositivo) ...[
          const _Titulo('Ritmo del ciclo', subtitulo: 'Tus gastos variables, día a día'),
          _Ritmo(reporte: r),
        ],
        if (r.contraAnterior.isNotEmpty) ...[
          _Titulo('Contra el ciclo pasado', subtitulo: 'A los mismos ${r.diaDelCiclo} días'),
          _ContraAnterior(reporte: r),
        ],
        if (r.ultimosCiclos.length > 1) ...[
          const _Titulo('Últimos ciclos', subtitulo: 'Total gastado por ciclo'),
          _UltimosCiclos(reporte: r),
        ],
        if (r.diasConDatos >= 7) ...[
          const _Titulo('¿Qué día gastas más?', subtitulo: 'Promedio de tus variables, últimos 90 días'),
          _PorDiaSemana(reporte: r),
        ],
        if (r.dondeMasGastas.isNotEmpty) ...[
          const _Titulo('Dónde más gastas', subtitulo: 'Según la descripción de tus gastos'),
          _DondeMasGastas(reporte: r),
        ],
        const _Titulo('Tarjeta y efectivo'),
        _TarjetaYEfectivo(reporte: r),
      ],
    );
  }
}

// ───────────────────────── bloques ─────────────────────────

class _Titulo extends StatelessWidget {
  final String texto;
  final String? subtitulo;

  const _Titulo(this.texto, {this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: textos.titleMedium),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(subtitulo!, style: textos.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _Resumen({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final textos = Theme.of(context).textTheme;
    final blanco70 = textos.bodySmall?.copyWith(color: const Color(0xFFC9D1E3));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColoresApp.noche, ColoresApp.azulMarino],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Van ${r.diaDelCiclo} de ${r.diasDelCiclo} días', style: blanco70),
          const SizedBox(height: 6),
          Text('Llevas gastado', style: blanco70),
          Text(r.gastado.formateado(), style: textos.displaySmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 14),
          BarraProporcion(valor: r.diaDelCiclo / r.diasDelCiclo, color: ColoresApp.oro, alto: 6),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DatoOscuro(
                  titulo: 'Promedio por día',
                  valor: r.promedioDiarioVariables.formateado(),
                  pie: 'en variables',
                ),
              ),
              Expanded(
                child: _DatoOscuro(
                  titulo: 'Si sigues así',
                  valor: r.proyeccionVariables.formateado(),
                  pie: r.presupuestoVariables.esPositivo
                      ? 'de ${r.presupuestoVariables.formateado()} en variables'
                      : 'en variables al cierre',
                ),
              ),
            ],
          ),
          if (r.presupuestoVariables.esPositivo && r.diasRestantes > 0) ...[
            const SizedBox(height: 12),
            Text(
              r.proyeccionVariables <= r.presupuestoVariables
                  ? 'A este ritmo, tus variables cierran dentro de lo planeado.'
                  : 'A este ritmo, tus variables cerrarían '
                      '${(r.proyeccionVariables - r.presupuestoVariables).formateado()} arriba de lo planeado.',
              style: textos.bodySmall?.copyWith(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _DatoOscuro extends StatelessWidget {
  final String titulo;
  final String valor;
  final String pie;

  const _DatoOscuro({required this.titulo, required this.valor, required this.pie});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final suave = textos.labelSmall?.copyWith(color: const Color(0xFFC9D1E3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: suave),
        const SizedBox(height: 2),
        Text(valor, style: textos.titleMedium?.copyWith(color: Colors.white)),
        Text(pie, style: suave),
      ],
    );
  }
}

class _TarjetaRecomendacion extends StatelessWidget {
  final Recomendacion recomendacion;
  final VoidCallback alTocar;

  const _TarjetaRecomendacion(this.recomendacion, {required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final rec = recomendacion;
    final textos = Theme.of(context).textTheme;
    final (icono, color, fondo) = switch (rec.tono) {
      TonoRecomendacion.alerta => (Icons.error_outline_rounded, ColoresApp.coralTexto, ColoresApp.coralSuave),
      TonoRecomendacion.atencion => (Icons.speed_rounded, ColoresApp.ambarTexto, ColoresApp.ambarSuave),
      TonoRecomendacion.positivo => (Icons.check_circle_outline_rounded, ColoresApp.verdeTexto, ColoresApp.verdeSuave),
      TonoRecomendacion.informativo => (Icons.lightbulb_outline_rounded, ColoresApp.oroTexto, ColoresApp.oroSuave),
    };
    final etiquetaAccion = switch (rec.accion) {
      AccionRecomendacion.verCategoria => 'Ver categoría',
      AccionRecomendacion.verGastos => 'Ver gastos',
      AccionRecomendacion.verMeta => 'Ver mi meta',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.titulo, style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(rec.detalle, style: textos.bodySmall),
                    const SizedBox(height: 8),
                    Text(
                      '$etiquetaAccion  ›',
                      style: textos.labelSmall?.copyWith(color: ColoresApp.azul, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnQueSeVa extends StatelessWidget {
  final ReporteAnalisis reporte;
  final void Function(String categoriaId) alVerCategoria;

  const _EnQueSeVa({required this.reporte, required this.alVerCategoria});

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final textos = Theme.of(context).textTheme;
    final cats = r.porCategoria;
    final lectura = [for (final g in cats) '${g.categoria.nombre} ${g.porcentaje}%'].join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GraficaDona(
              valores: [for (final g in cats) g.total],
              centroTitulo: 'Total',
              centroValor: r.gastado.formateado(),
              descripcion: 'Gasto por categoría: $lectura',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < cats.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => alVerCategoria(cats[i].categoria.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colorDeCategoria(i), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      ExcludeSemantics(child: Text(cats[i].categoria.emoji)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cats[i].categoria.nombre +
                              (cats[i].categoria is CategoriaFija ? ' · fija' : ''),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(cats[i].total.formateado(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(
                        width: 48,
                        child: Text('${cats[i].porcentaje}%', textAlign: TextAlign.end, style: textos.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Ritmo extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _Ritmo({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final textos = Theme.of(context).textTheme;
    final parejo = Dinero(r.presupuestoVariables.centavos * r.diaDelCiclo ~/ r.diasDelCiclo);
    final arriba = r.gastadoVariables > parejo;
    final quedanDias = r.diaDelCiclo < r.diasDelCiclo;
    final cierreSeRebasa = r.proyeccionVariables > r.presupuestoVariables;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GraficaRitmo(
              acumulado: r.acumuladoVariablesPorDia,
              diasDelCiclo: r.diasDelCiclo,
              presupuesto: r.presupuestoVariables,
              proyeccion: quedanDias ? r.proyeccionVariables : null,
              descripcion: 'Llevas ${r.gastadoVariables.formateado()} en variables; '
                  'a ritmo parejo llevarías ${parejo.formateado()}.'
                  '${quedanDias ? ' Si sigues así, cerrarías en ${r.proyeccionVariables.formateado()}.' : ''}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Leyenda(color: ColoresApp.azul, texto: 'Lo que llevas'),
                _Leyenda(color: ColoresApp.oro, texto: 'Ritmo parejo'),
                if (quedanDias)
                  _Leyenda(
                    color: colorPronostico(r.proyeccionVariables, r.presupuestoVariables),
                    texto: 'Pronóstico',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              arriba
                  ? 'Vas ${(r.gastadoVariables - parejo).formateado()} arriba del ritmo parejo.'
                  : 'Vas ${(parejo - r.gastadoVariables).formateado()} abajo del ritmo parejo. Bien.',
              style: textos.bodySmall?.copyWith(color: arriba ? ColoresApp.ambarTexto : ColoresApp.verdeTexto),
            ),
            if (quedanDias) ...[
              const SizedBox(height: 4),
              Text(
                'Si sigues así, cerrarías en ${r.proyeccionVariables.formateado()} de '
                '${r.presupuestoVariables.formateado()}.',
                style: textos.bodySmall?.copyWith(
                  color: cierreSeRebasa ? ColoresApp.coralTexto : ColoresApp.verdeTexto,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;

  const _Leyenda({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ContraAnterior extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _ContraAnterior({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final filas = reporte.contraAnterior.take(6).toList();
    final maximo = filas.fold<int>(1, (a, c) => [a, c.actual.centavos, c.anterior.centavos].reduce((x, y) => x > y ? x : y));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final c in filas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(
                  label: '${c.categoria.nombre}: este ciclo ${c.actual.formateado()}, '
                      'ciclo pasado ${c.anterior.formateado()}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(c.categoria.emoji),
                            const SizedBox(width: 6),
                            Expanded(child: Text(c.categoria.nombre)),
                            _Delta(c.diferencia),
                          ],
                        ),
                        const SizedBox(height: 6),
                        BarraProporcion(valor: c.actual.centavos / maximo, color: ColoresApp.azul),
                        const SizedBox(height: 4),
                        BarraProporcion(valor: c.anterior.centavos / maximo, color: const Color(0xFFB8C1D1)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Leyenda(color: ColoresApp.azul, texto: 'Este ciclo'),
                const SizedBox(width: 16),
                const _Leyenda(color: Color(0xFFB8C1D1), texto: 'Ciclo pasado'),
                const Spacer(),
                Text('a los mismos días', style: textos.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  final Dinero diferencia;

  const _Delta(this.diferencia);

  @override
  Widget build(BuildContext context) {
    final sube = diferencia.esPositivo;
    final igual = diferencia.esCero;
    final color = igual ? ColoresApp.medio : (sube ? ColoresApp.coralTexto : ColoresApp.verdeTexto);
    final fondo = igual ? ColoresApp.linea : (sube ? ColoresApp.coralSuave : ColoresApp.verdeSuave);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(99)),
      child: Text(
        igual ? 'igual' : '${sube ? '+' : '−'}${diferencia.absoluto.formateado()}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _UltimosCiclos extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _UltimosCiclos({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final ciclos = reporte.ultimosCiclos;
    final enCurso = {for (var i = 0; i < ciclos.length; i++) if (ciclos[i].enCurso) i};
    final cerrados = [for (final c in ciclos) if (!c.enCurso) c.total.centavos];
    final promedio = cerrados.isEmpty ? null : Dinero(cerrados.reduce((a, b) => a + b) ~/ cerrados.length);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GraficaBarras(
              valores: [for (final c in ciclos) c.total],
              etiquetas: [for (final c in ciclos) c.etiqueta],
              atenuadas: enCurso,
              conMontos: true,
              descripcion: [for (final c in ciclos) '${c.etiqueta} ${c.total.formateado()}'].join(', '),
            ),
            const SizedBox(height: 10),
            Text(
              promedio == null
                  ? 'El ciclo en curso va en tono claro: todavía no termina.'
                  : 'Promedio de tus ciclos cerrados: ${promedio.formateado()}. '
                      'El ciclo en curso va en tono claro: todavía no termina.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PorDiaSemana extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _PorDiaSemana({required this.reporte});

  static const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final valores = reporte.promedioPorDiaSemana;
    var mayor = 0;
    for (var i = 1; i < 7; i++) {
      if (valores[i] > valores[mayor]) mayor = i;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GraficaBarras(
              valores: valores,
              etiquetas: _iniciales,
              destacada: valores[mayor].esPositivo ? mayor : null,
              descripcion: [
                for (var i = 0; i < 7; i++) '${nombresDiaSemana[i]} ${valores[i].formateado()}',
              ].join(', '),
            ),
            if (valores[mayor].esPositivo) ...[
              const SizedBox(height: 10),
              Text(
                'Los ${nombresDiaSemana[mayor]} gastas más: ${valores[mayor].formateado()} en promedio.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DondeMasGastas extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _DondeMasGastas({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final lista = reporte.dondeMasGastas;
    final maximo = lista.first.total.centavos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < lista.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == 0 ? ColoresApp.oroSuave : ColoresApp.azulSuave,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: textos.labelSmall?.copyWith(
                          color: i == 0 ? ColoresApp.oroTexto : ColoresApp.azul,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(lista[i].descripcion, overflow: TextOverflow.ellipsis)),
                              Text(lista[i].total.formateado(), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          BarraProporcion(
                            valor: lista[i].total.centavos / maximo,
                            color: i == 0 ? ColoresApp.oro : ColoresApp.azul,
                            alto: 5,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lista[i].conteo == 1 ? '1 vez' : '${lista[i].conteo} veces',
                            style: textos.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaYEfectivo extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _TarjetaYEfectivo({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final total = r.conTarjeta.centavos + r.enEfectivo.centavos;
    final proporcion = total == 0 ? 0.0 : r.conTarjeta.centavos / total;
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarraProporcion(valor: proporcion, color: ColoresApp.azul, alto: 12),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Leyenda(color: ColoresApp.azul, texto: 'Tarjeta'),
                      const SizedBox(height: 4),
                      Text(r.conTarjeta.formateado(), style: textos.titleMedium),
                      Text('${(proporcion * 100).round()}%', style: textos.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Leyenda(color: ColoresApp.linea, texto: 'Efectivo'),
                      const SizedBox(height: 4),
                      Text(r.enEfectivo.formateado(), style: textos.titleMedium),
                      Text('${total == 0 ? 0 : 100 - (proporcion * 100).round()}%', style: textos.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
