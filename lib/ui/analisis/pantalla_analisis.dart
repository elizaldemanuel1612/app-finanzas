import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/analisis/recomendaciones.dart';
import '../../domain/analisis/reparto_ingreso.dart';
import '../../domain/analisis/reporte_analisis.dart';
import '../../domain/analisis/veredicto_ciclo.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../comun/aviso_gesto.dart';
import '../comun/guia_rapida.dart';
import '../comun/tema.dart';
import '../cuentas/color_saldo.dart';
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

  /// Para la vista "Cuentas" (spec §7.3.1); sin ellos no aparece.
  final CuentaRepositorio? cuentaRepositorio;
  final MovimientoCuentaRepositorio? movimientoCuentaRepositorio;

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
    this.cuentaRepositorio,
    this.movimientoCuentaRepositorio,
  });

  @override
  State<PantallaAnalisis> createState() => _PantallaAnalisisState();
}

class _Datos {
  final ReporteAnalisis reporte;
  final List<Recomendacion> recomendaciones;

  /// Lo que entra este ciclo: ingreso base más extras.
  final Dinero ingreso;

  /// Activas, con el presupuesto del ciclo: también las que aún no tienen gasto.
  final List<Categoria> categorias;

  /// `null` si no hay cuentas que mostrar.
  final List<ResumenCuenta>? cuentas;

  /// Lo que se piensa apartar este ciclo (meta más extras a apartar).
  final Dinero metaCiclo;

  const _Datos(this.reporte, this.recomendaciones, this.ingreso, this.categorias, this.cuentas, this.metaCiclo);
}

enum _Vista { basico, avanzado, cuentas }

class _PantallaAnalisisState extends State<PantallaAnalisis> {
  _Datos? _datos;
  _Vista _vista = _Vista.basico;

  /// Variables, Fijos o Total: lo comparten "¿Cuánto pesa cada parte?" y la
  /// dona de "¿En qué se va?".
  _Parte _parte = _Parte.total;

  static const _claveVista = 'vista_analisis';

  @override
  void initState() {
    super.initState();
    _cargarVista();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarGuiaRapidaPrimeraVez(context, GuiaRapida.analisis));
    _cargar();
  }

  /// Preferencia del dispositivo, como la apariencia: no viaja en el respaldo.
  Future<void> _cargarVista() async {
    try {
      final guardada = await SharedPreferencesAsync().getString(_claveVista);
      if (!mounted) return;
      setState(() {
        _vista = _Vista.values.firstWhere((v) => v.name == guardada, orElse: () => _vista);
      });
    } catch (_) {
      // Sin almacenamiento disponible: se queda en básico.
    }
  }

  Future<void> _elegirVista(_Vista vista) async {
    setState(() => _vista = vista);
    try {
      await SharedPreferencesAsync().setString(_claveVista, vista.name);
    } catch (_) {}
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
    final metaCiclo = calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresos);
    final recomendaciones = calcularRecomendaciones(
      reporte: reporte,
      ingresoCiclo: ingresos.total,
      metaCiclo: metaCiclo,
    );
    final repoCuentas = widget.cuentaRepositorio;
    final cuentas = repoCuentas == null
        ? null
        : resumenPorCuenta(
            cuentas: await repoCuentas.listarTodas(),
            categorias: todas,
            gastos: movimientos,
            movimientosCuenta: await widget.movimientoCuentaRepositorio?.listarTodos() ?? const [],
            cicloId: ciclo.id,
          );
    if (!mounted) return;
    setState(() => _datos = _Datos(
          reporte,
          recomendaciones,
          ingresos.total,
          [for (final c in efectivas) if (c.activa) c],
          cuentas,
          metaCiclo,
        ));
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

  Widget _selectorVista() => SegmentedButton<_Vista>(
        segments: [
          const ButtonSegment(value: _Vista.basico, label: Text('Básico')),
          const ButtonSegment(value: _Vista.avanzado, label: Text('Avanzado')),
          if (_datos?.cuentas != null) const ButtonSegment(value: _Vista.cuentas, label: Text('Cuentas')),
        ],
        selected: {_vista},
        onSelectionChanged: (s) => _elegirVista(s.first),
      );

  /// Para quien solo quiere echar un vistazo: cómo va, qué hacer y en qué se
  /// le va más. Lo demás queda a un toque, en la vista avanzada.
  Widget _contenidoBasico(BuildContext context, _Datos datos) {
    final r = datos.reporte;
    final variables = [
      for (final g in r.porCategoria)
        if (g.categoria is CategoriaVariable) g,
    ];
    return ListView(
      // Cada vista con su propio scroll: al cambiar, arranca hasta arriba.
      key: const ValueKey('basico'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _selectorVista(),
        const SizedBox(height: 16),
        _TarjetaVeredicto(reporte: r, veredicto: calcularVeredicto(reporte: r, hoy: DateTime.now())),
        if (datos.recomendaciones.isNotEmpty) ...[
          const _Titulo('Qué te recomiendo'),
          for (final rec in datos.recomendaciones.take(2)) _TarjetaRecomendacion(rec, alTocar: () => _accion(rec)),
        ],
        if (variables.isNotEmpty) ...[
          const _Titulo('En qué se te va más', subtitulo: 'Tus gastos del día a día'),
          _TopCategorias(gastos: variables.take(3).toList(), alVerCategoria: widget.alVerCategoria),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _elegirVista(_Vista.avanzado),
          child: const Text('Ver análisis completo'),
        ),
      ],
    );
  }

  /// Por tarjeta y efectivo: cuánto salió de cada una en el ciclo, en qué,
  /// y su saldo (spec §7.3.1).
  Widget _contenidoCuentas(BuildContext context, List<ResumenCuenta> cuentas) {
    final textos = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('cuentas'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _selectorVista(),
        const _Titulo('¿Con qué pagas?', subtitulo: 'Lo que salió de cada cuenta este ciclo'),
        for (final r in cuentas)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(child: Text(r.cuenta.emoji, style: textos.titleMedium)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.cuenta.nombre, style: textos.titleMedium),
                            Text(r.cuenta.tipo.etiqueta, style: textos.labelSmall),
                          ],
                        ),
                      ),
                      Text(r.gastado.formateado(), style: textos.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BarraProporcion(valor: r.porcentaje / 100, color: ColoresApp.azul, alto: 6),
                  const SizedBox(height: 6),
                  Text(
                    '${r.porcentaje}% de tu gasto · ${r.conteo} ${r.conteo == 1 ? 'gasto' : 'gastos'}',
                    style: textos.bodySmall,
                  ),
                  if (r.principales.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final p in r.principales)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            ExcludeSemantics(child: Text(p.categoria.emoji)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(p.categoria.nombre, style: textos.bodySmall)),
                            Text(p.total.formateado(), style: textos.bodySmall),
                          ],
                        ),
                      ),
                  ],
                  if (r.saldo case final saldo?) ...[
                    const SizedBox(height: 8),
                    if (lecturaDeSaldo(r.cuenta, saldo) case final l)
                      Text(
                        '${l.etiqueta}: ${l.monto.formateado()}',
                        style: textos.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorDeLectura(l),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _contenido(BuildContext context, _Datos datos) {
    if (_vista == _Vista.basico) return _contenidoBasico(context, datos);
    if (_vista == _Vista.cuentas) {
      final cuentas = datos.cuentas;
      if (cuentas != null) return _contenidoCuentas(context, cuentas);
    }
    final r = datos.reporte;
    return ListView(
      key: const ValueKey('avanzado'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _selectorVista(),
        const SizedBox(height: 16),
        _Resumen(reporte: r),
        if (datos.recomendaciones.isNotEmpty) ...[
          const _Titulo('Para ti', subtitulo: 'Lo más importante de tu ciclo, primero'),
          for (final rec in datos.recomendaciones) _TarjetaRecomendacion(rec, alTocar: () => _accion(rec)),
        ],
        const _Titulo('¿Cuánto pesa cada parte?'),
        _PesoDeCadaParte(
          datos: datos,
          parte: _parte,
          alCambiar: (p) => setState(() => _parte = p),
          alVerCategoria: widget.alVerCategoria,
        ),
        _Titulo(
          '¿En qué se va?',
          subtitulo: switch (_parte) {
            _Parte.variables => 'Solo tus gastos variables',
            _Parte.fijos => 'Solo tus gastos fijos',
            _Parte.total => null,
          },
        ),
        _EnQueSeVa(reporte: r, parte: _parte, alVerCategoria: widget.alVerCategoria),
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

/// "¿Cómo voy?" en una frase, y cuánto puede gastar hoy.
class _TarjetaVeredicto extends StatelessWidget {
  final ReporteAnalisis reporte;
  final VeredictoCiclo veredicto;

  const _TarjetaVeredicto({required this.reporte, required this.veredicto});

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final v = veredicto;
    final textos = Theme.of(context).textTheme;
    final (icono, color, fondo, barra) = switch (v.tono) {
      TonoVeredicto.bien => (Icons.check_circle_outline_rounded, ColoresApp.verdeTexto, ColoresApp.verdeSuave, ColoresApp.verde),
      TonoVeredicto.atencion => (Icons.speed_rounded, ColoresApp.ambarTexto, ColoresApp.ambarSuave, ColoresApp.ambar),
      TonoVeredicto.pasado => (Icons.error_outline_rounded, ColoresApp.coralTexto, ColoresApp.coralSuave, ColoresApp.coral),
      TonoVeredicto.neutro => (Icons.insights_rounded, ColoresApp.azul, ColoresApp.azulSuave, ColoresApp.azul),
    };
    final hayPresupuesto = r.presupuestoVariables.esPositivo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Text(v.titulo, style: textos.titleMedium?.copyWith(color: color)),
                      const SizedBox(height: 2),
                      Text(v.detalle, style: textos.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (v.disponibleHoy != null) ...[
              const SizedBox(height: 16),
              Text('Hoy puedes gastar', style: textos.bodySmall),
              Text(v.disponibleHoy!.formateado(), style: textos.displaySmall),
            ],
            if (hayPresupuesto) ...[
              const SizedBox(height: 14),
              BarraProporcion(
                valor: r.gastadoVariables.centavos / r.presupuestoVariables.centavos,
                color: barra,
              ),
              const SizedBox(height: 8),
              Text(
                '${r.gastadoVariables.formateado()} de ${r.presupuestoVariables.formateado()} · '
                'Van ${r.diaDelCiclo} de ${r.diasDelCiclo} días',
                style: textos.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopCategorias extends StatelessWidget {
  final List<GastoCategoria> gastos;
  final void Function(String categoriaId) alVerCategoria;

  const _TopCategorias({required this.gastos, required this.alVerCategoria});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          children: [
            for (final g in gastos)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => alVerCategoria(g.categoria.id),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExcludeSemantics(child: Text(g.categoria.emoji)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g.categoria.nombre,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            g.presupuesto.esPositivo
                                ? '${g.total.formateado()} de ${g.presupuesto.formateado()}'
                                : g.total.formateado(),
                            style: textos.bodySmall,
                          ),
                        ],
                      ),
                      if (g.presupuesto.esPositivo) ...[
                        const SizedBox(height: 6),
                        BarraProporcion(
                          valor: g.total.centavos / g.presupuesto.centavos,
                          color: g.total > g.presupuesto ? ColoresApp.coral : ColoresApp.azul,
                          alto: 6,
                        ),
                      ],
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
  final _Parte parte;
  final void Function(String categoriaId) alVerCategoria;

  const _EnQueSeVa({required this.reporte, required this.parte, required this.alVerCategoria});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    // Sigue al selector de "¿Cuánto pesa cada parte?": los porcentajes son
    // sobre lo que se ve.
    final cats = [
      for (final g in reporte.porCategoria)
        if (switch (parte) {
          _Parte.variables => g.categoria is CategoriaVariable,
          _Parte.fijos => g.categoria is CategoriaFija,
          _Parte.total => true,
        })
          g,
    ];
    final total = Dinero.suma([for (final g in cats) g.total]);
    int porcentaje(Dinero d) =>
        total.esPositivo ? (d.centavos * 100 + total.centavos ~/ 2) ~/ total.centavos : 0;
    if (cats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            parte == _Parte.fijos ? 'Aún no hay gastos fijos este ciclo.' : 'Aún no hay gastos variables este ciclo.',
            style: textos.bodySmall,
          ),
        ),
      );
    }
    final lectura = [for (final g in cats) '${g.categoria.nombre} ${porcentaje(g.total)}%'].join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GraficaDona(
              valores: [for (final g in cats) g.total],
              centroTitulo: switch (parte) {
                _Parte.variables => 'Variables',
                _Parte.fijos => 'Fijos',
                _Parte.total => 'Total',
              },
              centroValor: total.formateado(),
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
                              (parte == _Parte.total && cats[i].categoria is CategoriaFija ? ' · fija' : ''),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(cats[i].total.formateado(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(
                        width: 48,
                        child: Text('${porcentaje(cats[i].total)}%', textAlign: TextAlign.end, style: textos.bodySmall),
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

enum _Parte { variables, fijos, total }

/// Variables y fijos: cada categoría contra su presupuesto. Total: cuánto de
/// lo que entra se llevan unas y otras, y cuánto sobra.
class _PesoDeCadaParte extends StatefulWidget {
  final _Datos datos;
  final _Parte parte;
  final ValueChanged<_Parte> alCambiar;
  final void Function(String categoriaId) alVerCategoria;

  const _PesoDeCadaParte({
    required this.datos,
    required this.parte,
    required this.alCambiar,
    required this.alVerCategoria,
  });

  @override
  State<_PesoDeCadaParte> createState() => _PesoDeCadaParteState();
}

class _PesoDeCadaParteState extends State<_PesoDeCadaParte> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_Parte>(
              // Sin la palomita: con ella "Variables" no cabe en un teléfono angosto.
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Parte.variables, label: Text('Variables')),
                ButtonSegment(value: _Parte.fijos, label: Text('Fijos')),
                ButtonSegment(value: _Parte.total, label: Text('Total')),
              ],
              selected: {widget.parte},
              onSelectionChanged: (s) => widget.alCambiar(s.first),
            ),
            const SizedBox(height: 16),
            switch (widget.parte) {
              _Parte.variables => _porCategoria<CategoriaVariable>(context, 'Aún no tienes categorías variables.', 'variables'),
              _Parte.fijos => _porCategoria<CategoriaFija>(context, 'Aún no tienes gastos fijos.', 'fijos'),
              _Parte.total => _total(context),
            },
          ],
        ),
      ),
    );
  }

  /// Cómo está dividido el presupuesto de variables (o de fijos): cada
  /// categoría con su parte del total asignado (spec §5.7).
  Widget _porCategoria<T extends Categoria>(BuildContext context, String vacio, String tipo) {
    final textos = Theme.of(context).textTheme;
    final filas = [
      for (final c in widget.datos.categorias.whereType<T>()) (categoria: c, presupuesto: presupuestoDe(c)),
    ]..sort((a, b) => b.presupuesto.compareTo(a.presupuesto));
    if (filas.isEmpty) return Text(vacio, style: textos.bodySmall);
    final total = Dinero.suma([for (final f in filas) f.presupuesto]);
    double parte(Dinero d) => total.esPositivo ? d.centavos / total.centavos : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('De ${total.formateado()} asignados a $tipo', style: textos.bodySmall),
        const SizedBox(height: 8),
        for (final f in filas)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.alVerCategoria(f.categoria.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(child: Text(f.categoria.emoji)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.categoria.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${(parte(f.presupuesto) * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BarraProporcion(
                    valor: parte(f.presupuesto),
                    color: T == CategoriaFija ? colorFijas : colorVariables,
                    alto: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(f.presupuesto.formateado(), style: textos.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _total(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final datos = widget.datos;
    if (!datos.ingreso.esPositivo) {
      return Text('Registra lo que te entra para ver cuánto pesan tus gastos.', style: textos.bodySmall);
    }
    final reparto = calcularRepartoIngreso(reporte: datos.reporte, ingreso: datos.ingreso, metaCiclo: datos.metaCiclo);
    final quedanDias = datos.reporte.diasRestantes > 0;
    Widget barra(String titulo, String lectura, EstiloReparto estilo, RepartoIngreso r) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TituloReparto(titulo: titulo, lectura: lectura),
            const SizedBox(height: 6),
            BarraReparto(
              ingreso: r.ingreso,
              fijas: r.fijas,
              variables: r.variables,
              estilo: estilo,
              descripcion: '$titulo: fijos ${r.porcentaje(r.fijas)}%, variables '
                  '${r.porcentaje(r.variables)}% de lo que entra; '
                  '${r.sobra.esNegativo ? 'faltan ${Dinero(-r.sobra.centavos).formateado()}' : 'sobran ${r.sobra.formateado()}'}.',
            ),
            const SizedBox(height: 8),
            _FilaReparto(color: colorFijas, estilo: estilo, texto: 'Fijos', monto: r.fijas, porcentaje: r.porcentaje(r.fijas)),
            _FilaReparto(
              color: colorVariables,
              estilo: estilo,
              texto: 'Variables',
              monto: r.variables,
              porcentaje: r.porcentaje(r.variables),
            ),
            if (r.sobra.esNegativo)
              _FilaReparto(
                color: ColoresApp.coral,
                estilo: EstiloReparto.real,
                texto: 'Te faltan',
                monto: Dinero(-r.sobra.centavos),
                porcentaje: r.porcentaje(Dinero(-r.sobra.centavos)),
                destacado: ColoresApp.coralTexto,
              )
            else
              _FilaReparto(
                color: colorLibre,
                estilo: estilo,
                texto: 'Te sobra',
                monto: r.sobra,
                porcentaje: r.porcentaje(r.sobra),
                destacado: ColoresApp.verdeTexto,
              ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('De ${datos.ingreso.formateado()} que entran este ciclo', style: textos.bodySmall),
        const SizedBox(height: 12),
        _plan(context, reparto.plan),
        const SizedBox(height: 18),
        barra('Hasta hoy', 'Real', EstiloReparto.real, reparto.hoy),
        if (quedanDias) ...[
          const SizedBox(height: 18),
          barra('Al cierre, si sigues así', 'Estimado', EstiloReparto.estimado, reparto.alCierre),
        ],
      ],
    );
  }
}

/// Lo asignado: presupuestos del ciclo y el apartado ideal contra lo que entra.
Widget _plan(BuildContext context, RepartoIngreso r) {
  const estilo = EstiloReparto.plan;
  final pasa = r.sobra.esNegativo;
  final exceso = Dinero(-r.sobra.centavos);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _TituloReparto(titulo: 'Tu plan', lectura: 'Ideal'),
      const SizedBox(height: 6),
      BarraReparto(
        ingreso: r.ingreso,
        fijas: r.fijas,
        variables: r.variables,
        apartado: r.apartado,
        estilo: estilo,
        descripcion: 'Tu plan: fijos ${r.porcentaje(r.fijas)}%, variables ${r.porcentaje(r.variables)}%, '
            'apartado ideal ${r.porcentaje(r.apartado)}% de lo que entra; '
            '${pasa ? 'se pasa por ${exceso.formateado()}' : 'sin asignar ${r.sobra.formateado()}'}.',
      ),
      const SizedBox(height: 8),
      _FilaReparto(color: colorFijas, estilo: estilo, texto: 'Fijos', monto: r.fijas, porcentaje: r.porcentaje(r.fijas)),
      _FilaReparto(
        color: colorVariables,
        estilo: estilo,
        texto: 'Variables',
        monto: r.variables,
        porcentaje: r.porcentaje(r.variables),
      ),
      _FilaReparto(
        color: colorLibre,
        estilo: estilo,
        texto: 'Apartado ideal',
        monto: r.apartado,
        porcentaje: r.porcentaje(r.apartado),
        destacado: ColoresApp.verdeTexto,
      ),
      if (pasa)
        _FilaReparto(
          color: ColoresApp.coral,
          estilo: EstiloReparto.real,
          texto: 'Tu plan se pasa por',
          monto: exceso,
          porcentaje: r.porcentaje(exceso),
          destacado: ColoresApp.coralTexto,
        )
      else if (r.sobra.esPositivo)
        _FilaReparto(
          color: ColoresApp.pista,
          estilo: EstiloReparto.real,
          texto: 'Sin asignar',
          monto: r.sobra,
          porcentaje: r.porcentaje(r.sobra),
        ),
    ],
  );
}

/// "Tu plan · Ideal": el título de cada barra y cómo leerla.
class _TituloReparto extends StatelessWidget {
  final String titulo;
  final String lectura;

  const _TituloReparto({required this.titulo, required this.lectura});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        Flexible(child: Text(titulo, style: textos.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: ColoresApp.pista, borderRadius: BorderRadius.circular(20)),
          child: Text(lectura, style: textos.labelSmall),
        ),
      ],
    );
  }
}

class _FilaReparto extends StatelessWidget {
  final Color color;
  final EstiloReparto estilo;
  final String texto;
  final Dinero monto;
  final int porcentaje;
  final Color? destacado;

  const _FilaReparto({
    required this.color,
    required this.estilo,
    required this.texto,
    required this.monto,
    required this.porcentaje,
    this.destacado,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estiloTexto = textos.bodySmall?.copyWith(color: destacado, fontWeight: destacado == null ? null : FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          MuestraReparto(color: color, estilo: estilo),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: estiloTexto)),
          Text('${monto.formateado()} · $porcentaje%', style: estiloTexto),
        ],
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

/// Las 5 primeras; al tocar, la lista completa (lo agrupado más allá del
/// top 5).
class _DondeMasGastas extends StatelessWidget {
  final ReporteAnalisis reporte;

  const _DondeMasGastas({required this.reporte});

  @override
  Widget build(BuildContext context) {
    final todas = reporte.dondeMasGastas;
    final faltan = todas.length - 5;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Dónde más gastas')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${todas.length} lugares o conceptos este ciclo, de mayor a menor. Lo parecido va junto.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: _ListaDondeMas(lista: todas))),
                ],
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ListaDondeMas(lista: todas.take(5).toList()),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  faltan > 0 ? 'Ver los $faltan más  ›' : 'Ver detalle  ›',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ColoresApp.azul,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListaDondeMas extends StatelessWidget {
  final List<GastoDescripcion> lista;

  const _ListaDondeMas({required this.lista});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final maximo = lista.first.total.centavos;
    return Column(
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
