import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/firebase/servicio_auth.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/local/almacen_local.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/perfil_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/ciclo_de_vida/alcance.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/disponible_por_dia.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../../domain/rollups/rollup.dart';
import '../../plataforma/accesos_rapidos.dart';
import '../ajustes/pantalla_ajustes.dart';
import '../captura/pantalla_captura.dart';
import '../categorias/pantalla_categorias.dart';
import '../categorias/pantalla_detalle_categoria.dart';
import '../ciclo/pantalla_ciclos_anteriores.dart';
import '../comun/barra_ritmo.dart';
import '../comun/formato_dinero.dart';
import '../comun/tarjeta_resumen_ciclo.dart';
import '../comun/tema.dart';
import '../gastos/pantalla_gastos.dart';
import '../ingresos/pantalla_ingresos_del_ciclo.dart';
import '../meta/pantalla_meta_ahorro.dart';

/// app-finanzas-mockup-v2.html §1, con rollups precalculados (Fase 2) y la
/// marca de ritmo en su versión simple — el motor de pronóstico completo
/// (domain/pronostico/) llega en la Fase 4.
class PantallaInicio extends StatefulWidget {
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final CicloRepositorio cicloRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;
  final AjustePresupuestoCicloRepositorio ajustePresupuestoCicloRepositorio;
  final PerfilRepositorio perfilRepositorio;
  final ServicioAuth servicioAuth;
  final AlmacenLocal almacenLocal;

  const PantallaInicio({
    super.key,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.cicloRepositorio,
    required this.ingresoExtraRepositorio,
    required this.ajustePresupuestoCicloRepositorio,
    required this.perfilRepositorio,
    required this.servicioAuth,
    required this.almacenLocal,
  });

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late Ciclo _ciclo;
  late double _avanceCiclo;
  late Perfil _perfil = widget.perfil;
  _DatosInicio? _datos;
  bool _variablesExpandido = true;
  bool _fijasExpandido = true;
  bool _capturaAbierta = false;

  @override
  void initState() {
    super.initState();
    _ciclo = CalculadoraCiclo(_perfil.diaCorte).calcularPara(DateTime.now());
    _avanceCiclo = avanceDelCiclo(
      fechaInicio: _ciclo.fechaInicio,
      fechaFin: _ciclo.fechaFin,
      ahora: DateTime.now(),
    );
    _cargar();
    AccesosRapidos.escuchar(_abrirAccesoRapido);
  }

  @override
  void dispose() {
    AccesosRapidos.dejarDeEscuchar();
    super.dispose();
  }

  /// El widget de inicio o Siri pidieron abrir la captura (§5.6). Se abre
  /// encima de lo que haya, sin cerrar pantallas. Si ya hay una captura
  /// abierta no se apila otra: el usuario ya está ahí (y el micrófono está
  /// a un toque).
  void _abrirAccesoRapido(AccesoRapido acceso) {
    if (!mounted || _capturaAbierta) return;
    _irACaptura(iniciarDictado: acceso == AccesoRapido.dictar);
  }

  Future<void> _cargar() async {
    final datos = await _cargarDatos();
    if (!mounted) return;
    setState(() => _datos = datos);
    final hoy = DateTime.now();
    AccesosRapidos.publicarDisponibleHoy(
      calcularDisponiblePorDia(
        presupuestoVariables: datos.presupuestoVariables,
        gastadoVariables: datos.gastadoVariables,
        ciclo: _ciclo,
        hoy: hoy,
      ),
      hoy,
    );
  }

  Future<_DatosInicio> _cargarDatos() async {
    final categorias = await widget.categoriaRepositorio.listarActivas();
    final movimientos = await widget.movimientoRepositorio.listarPorCiclo(
      _ciclo.id,
    );
    final extras = await widget.ingresoExtraRepositorio.listarPorCiclo(
      _ciclo.id,
    );
    final ajustes = await widget.ajustePresupuestoCicloRepositorio
        .listarPorCiclo(_ciclo.id);
    final deltaPorCategoria = sumarDeltasPorCategoria(ajustes);
    final categoriasEfectivas = presupuestosEfectivosParaCiclo(
      base: categorias,
      ajustesDelCiclo: ajustes,
    );
    final rollups = calcularRollups(
      movimientos: movimientos,
      categorias: categoriasEfectivas,
      cicloId: _ciclo.id,
      ahora: DateTime.now(),
    );
    final rollupPorCategoria = {for (final r in rollups) r.categoriaId: r};

    // fijas/variables se quedan con la categoría base (no la efectiva): se
    // usan también para navegar a PantallaDetalleCategoria, que vuelve a
    // aplicar los ajustes del ciclo por su cuenta — pasarle ya la versión
    // ajustada la aplicaría dos veces. Lo que sí debe verse ajustado (el
    // presupuesto mostrado en la fila) sale de `rollupPorCategoria`, que
    // se calculó con `categoriasEfectivas`.
    final fijas = categorias.whereType<CategoriaFija>().toList();
    final variables = categorias.whereType<CategoriaVariable>().toList()
      ..sort((a, b) {
        final ea = calcularEstadoRitmo(
          porcentajeUsado: rollupPorCategoria[a.id]?.porcentajeUsado,
        );
        final eb = calcularEstadoRitmo(
          porcentajeUsado: rollupPorCategoria[b.id]?.porcentajeUsado,
        );
        return eb.index.compareTo(ea.index); // excedido primero
      });

    final totalGastado = Dinero.suma(rollups.map((r) => r.totalCentavos));
    final gastadoVariables = Dinero.suma(
      variables.map((c) => rollupPorCategoria[c.id]?.totalCentavos ?? const Dinero.cero()),
    );
    final presupuestoVariables = Dinero.suma(
      variables.map(
        (c) => rollupPorCategoria[c.id]?.presupuestoCentavos ?? c.presupuestoMensualCentavos,
      ),
    );
    final gastadoFijas = Dinero.suma(
      fijas.map((c) => rollupPorCategoria[c.id]?.totalCentavos ?? const Dinero.cero()),
    );
    final presupuestoFijas = Dinero.suma(
      fijas.map((c) => rollupPorCategoria[c.id]?.presupuestoCentavos ?? c.montoFijoCentavos),
    );
    final ingresos = calcularIngresosDelCiclo(
      ingresoBase: _perfil.ingresoBaseMensual,
      cicloId: _ciclo.id,
      extras: extras,
    );
    final disponibleParaInvertir = ingresos.total - totalGastado;

    final metaBase = calcularMetaBase(perfil: _perfil, categorias: categorias);
    final metaDelCiclo = calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresos);
    final metricasMeta = calcularMetricasApartado(
      ingresoTotal: ingresos.total,
      totalGastado: totalGastado,
      meta: metaDelCiclo,
      extraAApartado: ingresos.extraAApartado,
      extraAGasto: ingresos.extraAGasto,
    );

    return _DatosInicio(
      categorias: categorias,
      rollupPorCategoria: rollupPorCategoria,
      fijas: fijas,
      variables: variables,
      totalGastado: totalGastado,
      gastadoVariables: gastadoVariables,
      presupuestoVariables: presupuestoVariables,
      gastadoFijas: gastadoFijas,
      presupuestoFijas: presupuestoFijas,
      ingresos: ingresos,
      disponibleParaInvertir: disponibleParaInvertir,
      deltaPorCategoria: deltaPorCategoria,
      metaDelCiclo: metaDelCiclo,
      metricasMeta: metricasMeta,
    );
  }

  Future<void> _irACaptura({bool iniciarDictado = false}) async {
    // Object? en vez de Movimiento: el dictado por voz puede registrar
    // varios movimientos de golpe y regresa un sentinel (true), no un
    // único Movimiento — cualquier resultado no nulo dispara el refresco.
    _capturaAbierta = true;
    final registrado = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => PantallaCaptura(
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          documentos: widget.almacenLocal.directorio,
          iniciarDictado: iniciarDictado,
        ),
      ),
    );
    _capturaAbierta = false;
    if (registrado != null) await _cargar();
  }

  void _irAGastos() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PantallaGastos(
              cicloId: _ciclo.id,
              perfil: _perfil,
              categoriaRepositorio: widget.categoriaRepositorio,
              movimientoRepositorio: widget.movimientoRepositorio,
              reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
              cicloRepositorio: widget.cicloRepositorio,
              documentos: widget.almacenLocal.directorio,
            ),
          ),
        )
        .then((_) => _cargar());
  }

  Future<void> _irACategorias() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCategorias(
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
        ),
      ),
    );
    await _cargar();
  }

  void _irACiclosAnteriores() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCiclosAnteriores(
          perfil: _perfil,
          cicloActual: _ciclo,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        ),
      ),
    );
  }

  Future<void> _irAIngresos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaIngresosDelCiclo(
          ciclo: _ciclo,
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
          perfilRepositorio: widget.perfilRepositorio,
        ),
      ),
    );
    final perfilActualizado = await widget.perfilRepositorio.obtener();
    if (!mounted || perfilActualizado == null) {
      await _cargar();
      return;
    }
    setState(() => _perfil = perfilActualizado);
    await _cargar();
  }

  Future<void> _irAAjustes() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaAjustes(
          perfil: _perfil,
          servicioAuth: widget.servicioAuth,
          almacenLocal: widget.almacenLocal,
        ),
      ),
    );
    final perfilActualizado = await widget.perfilRepositorio.obtener();
    if (!mounted) return;
    if (perfilActualizado != null) setState(() => _perfil = perfilActualizado);
    await _cargar();
  }

  Future<void> _irAMeta() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaMetaAhorro(
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          perfilRepositorio: widget.perfilRepositorio,
          onIrACategorias: _irACategorias,
        ),
      ),
    );
    final perfilActualizado = await widget.perfilRepositorio.obtener();
    if (!mounted) return;
    if (perfilActualizado != null) setState(() => _perfil = perfilActualizado);
    await _cargar();
  }

  void _irADetalle(Categoria categoria) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PantallaDetalleCategoria(
              categoria: categoria,
              ciclo: _ciclo,
              avanceCiclo: _avanceCiclo,
              categoriaRepositorio: widget.categoriaRepositorio,
              movimientoRepositorio: widget.movimientoRepositorio,
              reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
              ajustePresupuestoCicloRepositorio:
                  widget.ajustePresupuestoCicloRepositorio,
              cicloRepositorio: widget.cicloRepositorio,
            ),
          ),
        )
        .then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ciclo ${_ciclo.etiqueta}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Gastos',
            onPressed: _irAGastos,
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Categorías',
            onPressed: _irACategorias,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: _irAAjustes,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _irACaptura,
        backgroundColor: ColoresApp.violeta,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _datos == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContenido(_datos!),
    );
  }

  Widget _buildContenido(_DatosInicio datos) {
    if (datos.categorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                child: Text('👋', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Todavía no tienes categorías. Crea la primera para empezar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColoresApp.medio),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _irACategorias,
                child: const Text('Ir a Categorías'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TarjetaResumenCiclo(
          ciclo: _ciclo,
          diasParaTerminar: _ciclo.diasParaTerminar(DateTime.now()),
          ingreso: datos.ingresos.total,
          subtituloIngreso: datos.ingresos.huboExtra
              ? '${datos.ingresos.base.formateado()} de siempre + '
                    '${datos.ingresos.extraTotal.formateado()} extra'
              : 'de siempre',
          totalGastado: datos.totalGastado,
          disponibleParaInvertir: datos.disponibleParaInvertir,
          onTapIngreso: _irAIngresos,
        ),
        _TarjetaMeta(
          meta: datos.metaDelCiclo,
          metricas: datos.metricasMeta,
          onTap: _irAMeta,
        ),
        Card(
          margin: const EdgeInsets.only(top: 16),
          child: ListTile(
            onTap: _irACiclosAnteriores,
            leading: const Icon(Icons.history, color: ColoresApp.medio),
            title: const Text(
              'Ciclos anteriores',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Revisa cómo te fue en meses pasados'),
            trailing: const Icon(Icons.chevron_right, color: ColoresApp.medio),
          ),
        ),
        if (datos.variables.isNotEmpty) ...[
          const SizedBox(height: 24),
          _EncabezadoSeccion(
            titulo: 'Gastos Variables',
            resumen: '${datos.gastadoVariables.formateado()} de '
                '${datos.presupuestoVariables.formateado()}',
            expandido: _variablesExpandido,
            onToggle: () => setState(() => _variablesExpandido = !_variablesExpandido),
          ),
          if (_variablesExpandido) ...[
            const SizedBox(height: 10),
            ...datos.variables.map((c) {
            final rollup = datos.rollupPorCategoria[c.id];
            final estado = calcularEstadoRitmo(
              porcentajeUsado: rollup?.porcentajeUsado,
            );
            final vaRapido = vaMuyRapido(
              porcentajeUsado: rollup?.porcentajeUsado,
              avanceCiclo: _avanceCiclo,
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _irADetalle(c),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                ExcludeSemantics(
                                  child: Text(
                                    c.emoji,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.nombre,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorEstadoRitmo(
                                estado,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              etiquetaEstadoRitmo(estado),
                              style: TextStyle(
                                color: colorTextoEstadoRitmo(estado),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BarraRitmo(
                        porcentajeUsado: rollup?.porcentajeUsado ?? 0,
                        avanceCiclo: _avanceCiclo,
                        estado: estado,
                        descripcion: c.nombre,
                        vaMuyRapido: vaRapido,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(rollup?.totalCentavos ?? const Dinero.cero()).formateado()} de '
                            '${(rollup?.presupuestoCentavos ?? c.presupuestoMensualCentavos).formateado()}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      if (datos.deltaPorCategoria[c.id] != null &&
                          !datos.deltaPorCategoria[c.id]!.esCero)
                        Text(
                          'ajustado por ${signoYMonto(datos.deltaPorCategoria[c.id]!)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ),
            );
            }),
          ],
        ],
        if (datos.fijas.isNotEmpty) ...[
          const SizedBox(height: 24),
          _EncabezadoSeccion(
            titulo: 'Gastos fijos',
            resumen: '${datos.gastadoFijas.formateado()} de '
                '${datos.presupuestoFijas.formateado()}',
            expandido: _fijasExpandido,
            onToggle: () => setState(() => _fijasExpandido = !_fijasExpandido),
          ),
          if (_fijasExpandido) ...[
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: datos.fijas.map((c) {
                  final rollup = datos.rollupPorCategoria[c.id];
                  final gastado = rollup?.totalCentavos ?? const Dinero.cero();
                  final presupuesto = rollup?.presupuestoCentavos ?? c.montoFijoCentavos;
                  final estadoTexto = !gastado.esPositivo
                      ? 'Pendiente'
                      : (gastado > presupuesto ? 'Excedido' : 'Pagado');
                  return ListTile(
                    onTap: () => _irADetalle(c),
                    leading: ExcludeSemantics(
                      child: Text(c.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(c.nombre),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6, right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(estadoTexto),
                          const SizedBox(height: 6),
                          _BarraCobertura(
                            porcentajeUsado: rollup?.porcentajeUsado,
                            descripcion: c.nombre,
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      c.montoFijoCentavos.formateado(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _DatosInicio {
  final List<Categoria> categorias;
  final Map<String, Rollup> rollupPorCategoria;
  final List<CategoriaFija> fijas;
  final List<CategoriaVariable> variables;
  final Dinero totalGastado;
  final Dinero gastadoVariables;
  final Dinero presupuestoVariables;
  final Dinero gastadoFijas;
  final Dinero presupuestoFijas;
  final IngresosDelCiclo ingresos;
  final Dinero disponibleParaInvertir;
  final Map<String, Dinero> deltaPorCategoria;
  final Dinero metaDelCiclo;
  final MetricasApartado metricasMeta;

  const _DatosInicio({
    required this.categorias,
    required this.rollupPorCategoria,
    required this.fijas,
    required this.variables,
    required this.totalGastado,
    required this.gastadoVariables,
    required this.presupuestoVariables,
    required this.gastadoFijas,
    required this.presupuestoFijas,
    required this.ingresos,
    required this.disponibleParaInvertir,
    required this.deltaPorCategoria,
    required this.metaDelCiclo,
    required this.metricasMeta,
  });
}

/// Tarjeta propia (no un campo más dentro de [TarjetaResumenCiclo], para no
/// mover el layout que `test/ui/escalado_test.dart` ya vigila) con la meta
/// de apartado del ciclo y qué tanto se lleva — toca a [PantallaMetaAhorro].
class _TarjetaMeta extends StatelessWidget {
  final Dinero meta;
  final MetricasApartado metricas;
  final VoidCallback onTap;

  const _TarjetaMeta({required this.meta, required this.metricas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final alcance = metricas.alcance;
    final nivel = calcularNivelAlcance(alcance);
    final (colorTexto, colorFondo) = switch (nivel) {
      null => (ColoresApp.violeta, ColoresApp.violetaSuave),
      NivelAlcance.logrado => (ColoresApp.verdeTexto, ColoresApp.verdeSuave),
      NivelAlcance.cerca => (ColoresApp.ambarTexto, ColoresApp.ambarSuave),
      NivelAlcance.corto => (ColoresApp.coralTexto, ColoresApp.coralSuave),
    };

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Meta de este ciclo', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Llevas ${metricas.apartado.formateado()} de ${meta.formateado()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: colorFondo, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  alcance == null ? '—' : '${(alcance * 100).round()}%',
                  style: TextStyle(color: colorTexto, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: ColoresApp.medio),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado de "Gastos Variables"/"Gastos fijos": el resumen (gastado de
/// presupuestado de la sección completa) se queda visible sin importar si
/// la lista está desplegada o contraída — tocar cualquier parte del
/// encabezado alterna entre las dos.
class _EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final String resumen;
  final bool expandido;
  final VoidCallback onToggle;

  const _EncabezadoSeccion({
    required this.titulo,
    required this.resumen,
    required this.expandido,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  resumen,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ColoresApp.medio),
                ),
              ],
            ),
          ),
          Icon(
            expandido ? Icons.expand_less : Icons.expand_more,
            color: ColoresApp.medio,
            semanticLabel: expandido ? 'Contraer' : 'Expandir',
          ),
        ],
      ),
    );
  }
}

/// Barra de cobertura para gastos fijos: a diferencia de [BarraRitmo], no
/// dibuja marca de avance del ciclo ni proyección de ritmo — una fija no
/// se paga poco a poco a lo largo del ciclo, tiene un monto conocido que
/// se cubre o no (estado_ritmo.dart), así que esto solo pinta qué
/// proporción de ese monto ya se registró, con el mismo código de color de
/// severidad que el resto de la app.
class _BarraCobertura extends StatelessWidget {
  final double? porcentajeUsado;
  final String descripcion;

  const _BarraCobertura({required this.porcentajeUsado, required this.descripcion});

  @override
  Widget build(BuildContext context) {
    final fraccion = (porcentajeUsado ?? 0).clamp(0.0, 1.0);
    final estado = calcularEstadoRitmo(porcentajeUsado: porcentajeUsado);
    final porcentaje = ((porcentajeUsado ?? 0) * 100).round();

    return Semantics(
      label: 'Cobertura de $descripcion: $porcentaje% del monto fijo.',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEFF6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Container(
                  width: constraints.maxWidth * fraccion,
                  decoration: BoxDecoration(
                    color: colorEstadoRitmo(estado),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
