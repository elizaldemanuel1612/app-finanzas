import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/firebase/servicio_auth.dart';
import '../../data/repositorios/anular_gasto.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/local/almacen_local.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/perfil_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/cuentas/fechas_tarjeta.dart';
import '../../domain/modelos/cuenta.dart';
import '../cuentas/frase_pago.dart';
import '../cuentas/pantalla_detalle_cuenta.dart';
import '../ia/servicio_ia_app.dart';
import '../../domain/presupuesto/resumen_variables.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/apartado_estimado.dart';
import '../../domain/presupuesto/cobertura_excesos.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../../domain/presupuesto/traslado_sobrante.dart';
import '../ciclo/hoja_traslado_sobrante.dart';
import 'hoja_orden_presupuesto.dart';
import '../../domain/pronostico/pronostico_del_ciclo.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../../domain/rollups/orden_categorias.dart';
import '../../domain/rollups/rollup.dart';
import '../../domain/voz/monto_hablado.dart';
import '../../plataforma/accesos_rapidos.dart';
import '../ajustes/pantalla_ajustes.dart';
import '../analisis/pantalla_analisis.dart';
import '../captura/pantalla_captura.dart';
import '../categorias/pantalla_categorias.dart';
import '../categorias/pantalla_detalle_categoria.dart';
import '../comun/avatar_ajustes.dart';
import '../comun/borde_para_regresar.dart';
import '../comun/aviso.dart';
import '../comun/aviso_gesto.dart';
import '../comun/barra_ritmo.dart';
import '../comun/chip_estado.dart';
import '../comun/esqueleto.dart';
import '../comun/formato_dinero.dart';
import '../comun/formato_fecha.dart';
import '../comun/guia_rapida.dart';
import '../comun/renglon_app.dart';
import '../comun/tarjeta_app.dart';
import '../comun/tema.dart';
import '../gastos/pantalla_gastos.dart';
import '../ingresos/pantalla_ingresos_del_ciclo.dart';
import '../meta/pantalla_meta_ahorro.dart';
import '../patrimonio/pantalla_patrimonio.dart';
import '../comun/hoja.dart';

/// Las cuatro pantallas raíz de la barra inferior
/// (`docs/rediseno/plan-rediseno.md`, navegación nueva).
enum Pestana { inicio, gastos, analisis, patrimonio }

/// La app ya con sesión: la barra **Inicio · Gastos · ＋ · Análisis ·
/// Patrimonio** y, en la pestaña Inicio, la respuesta a "¿voy bien y cuánto
/// puedo gastar hoy?" (`docs/rediseno/pantallas/Inicio.dc.html`).
///
/// Las pestañas son raíces: sin flecha ←, con la barra siempre visible. Al
/// volver a una pestaña se recarga (su `key` cambia), así nunca muestra
/// cifras viejas. Ajustes se abre desde el avatar.
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

  /// Cambia cuando la sincronización con el respaldo en Drive trajo datos nuevos.
  final Listenable? recargar;

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
    this.recargar,
  });

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late Ciclo _ciclo;
  late double _avanceCiclo;
  late Perfil _perfil = widget.perfil;
  _DatosInicio? _datos;
  bool _capturaAbierta = false;

  /// Si ya se revisó en esta sesión si toca ofrecer el traslado de sobrante.
  bool _trasladoRevisado = false;
  Pestana _pestana = Pestana.inicio;

  /// Sube cada vez que se entra a una pestaña o se registra algo: es la
  /// `key` de la pestaña, así se vuelve a cargar con datos frescos.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _recalcularCiclo();
    _cargar();
    AccesosRapidos.escuchar(_abrirAccesoRapido, alCambiarDatos: () {
      // Siri registró un gasto (§5.6.3): se recarga lo que se ve.
      if (!mounted) return;
      setState(() => _version++);
      _cargar();
    });
    widget.recargar?.addListener(_alSincronizar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _guiaDeRegistrar());
  }

  @override
  void dispose() {
    widget.recargar?.removeListener(_alSincronizar);
    AccesosRapidos.dejarDeEscuchar();
    super.dispose();
  }

  /// El nombre de la cuenta, para el avatar. Sin Firebase (sin red al
  /// abrir, o la demo) no hay nombre y el avatar muestra una silueta.
  String? get _nombre {
    try {
      return widget.servicioAuth.usuarioActual?.displayName;
    } catch (_) {
      return null;
    }
  }

  /// La primera vez, obligatoria: registrar gastos es la base de todo lo
  /// demás (guia_rapida.dart).
  Future<void> _guiaDeRegistrar() async {
    final registrar = await mostrarGuiaRapidaPrimeraVez(
      context,
      GuiaRapida.registrarGasto,
      obligatoria: true,
      accionFinal: 'Registrar mi primer gasto',
    );
    if (registrar && mounted && !_capturaAbierta) await _irACaptura();
  }

  Future<void> _alSincronizar() async {
    final perfil = await widget.perfilRepositorio.obtener();
    if (!mounted) return;
    if (perfil != null) {
      setState(() {
        _perfil = perfil;
        _recalcularCiclo();
      });
    }
    await _cargar();
  }

  /// Con el historial de cortes del perfil (spec §2.4): si el usuario
  /// cambió su día de corte, el ciclo en curso puede ser de transición.
  void _recalcularCiclo() {
    final ahora = DateTime.now();
    _ciclo = _perfil.calculadoraCiclo.calcularPara(ahora);
    _avanceCiclo = avanceDelCiclo(fechaInicio: _ciclo.fechaInicio, fechaFin: _ciclo.fechaFin, ahora: ahora);
  }

  /// El widget de inicio o Siri pidieron abrir la captura (§5.6). Si ya hay
  /// una captura abierta no se apila otra.
  void _abrirAccesoRapido(AccesoRapido acceso) {
    if (!mounted || _capturaAbierta) return;
    _irACaptura(iniciarDictado: acceso == AccesoRapido.dictar);
  }

  void _elegirPestana(Pestana pestana) {
    setState(() {
      _pestana = pestana;
      _version++;
    });
    if (pestana == Pestana.inicio) _cargar();
  }

  Future<void> _cargar() async {
    final datos = await _cargarDatos();
    if (!mounted) return;
    setState(() => _datos = datos);
    AccesosRapidos.publicarGastado(
      datos.soloRegistro ? datos.totalGastado : datos.gastadoVariables,
      datos.presupuestoVariables,
      DateTime.now(),
    );
    _ofrecerTrasladoSiToca();
  }

  /// Ciclo nuevo: ¿pasar lo que sobró del anterior? (addendum-v3 §2.5.2).
  /// Una vez por ciclo; nada cambia si se elige "No trasladar nada".
  Future<void> _ofrecerTrasladoSiToca() async {
    if (_trasladoRevisado) return;
    _trasladoRevisado = true;
    final anterior = _perfil.calculadoraCiclo.calcularPara(_ciclo.fechaInicio.subtract(const Duration(days: 1)));
    final sobrantes = sobrantesDelCiclo(
      categorias: await widget.categoriaRepositorio.listarActivas(),
      ajustesDelCiclo: await widget.ajustePresupuestoCicloRepositorio.listarPorCiclo(anterior.id),
      movimientos: await widget.movimientoRepositorio.listarTodos(),
      cicloId: anterior.id,
    );
    if (!mounted || !debePreguntarTraslado(_perfil, _ciclo.id, sobrantes)) return;
    final decision = await mostrarHojaTraslado(
      context,
      sobrantes: sobrantes,
      preseleccion: trasladoPreseleccionado(_perfil, sobrantes),
    );
    final elegidas = [for (final x in sobrantes) if (decision?.elegidas.contains(x.categoria.id) ?? false) x];
    if (elegidas.isNotEmpty) {
      await widget.ajustePresupuestoCicloRepositorio.agregarLote(
        ajustesDeTraslado(elegidas, cicloNuevoId: _ciclo.id, ahora: DateTime.now()),
      );
    }
    final perfil = perfilTrasDecidir(
      _perfil,
      _ciclo.id,
      recordar: decision != null && decision.recordar ? decision.elegidas : null,
    );
    await widget.perfilRepositorio.guardar(perfil);
    if (!mounted) return;
    setState(() => _perfil = perfil);
    if (elegidas.isEmpty) return;
    final total = Dinero(elegidas.fold<int>(0, (t, x) => t + x.sobrante.centavos));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(elegidas.length == 1
            ? 'Listo, ${elegidas.single.categoria.nombre} tiene ${enPesos(total)} más este ciclo'
            : 'Listo, trasladaste ${enPesos(total)} a ${elegidas.length} categorías'),
      ));
    await _cargar();
  }

  Future<_DatosInicio> _cargarDatos() async {
    final hoy = DateTime.now();
    final categorias = await widget.categoriaRepositorio.listarActivas();
    // Todos: el pronóstico (MPC) necesita el historial; los totales del
    // ciclo filtran por `cicloId` en los rollups.
    final todos = await widget.movimientoRepositorio.listarTodos();
    final movimientos = [for (final m in todos) if (m.cicloId == _ciclo.id) m];
    final extras = await widget.ingresoExtraRepositorio.listarPorCiclo(_ciclo.id);
    final ajustes = await widget.ajustePresupuestoCicloRepositorio.listarPorCiclo(_ciclo.id);
    final efectivas = presupuestosEfectivosParaCiclo(base: categorias, ajustesDelCiclo: ajustes);
    final rollups = calcularRollups(movimientos: movimientos, categorias: efectivas, cicloId: _ciclo.id, ahora: hoy);
    final rollupPorCategoria = {for (final r in rollups) r.categoriaId: r};

    // fijas/variables se quedan con la categoría base (no la efectiva): se
    // usan para navegar a PantallaDetalleCategoria, que vuelve a aplicar los
    // ajustes del ciclo. Lo que se ve ajustado sale de `rollupPorCategoria`.
    final fijas = categorias.whereType<CategoriaFija>().toList();
    final variables = categorias.whereType<CategoriaVariable>().toList();
    // Solo lo de las categorías con presupuesto se compara contra él; lo de
    // las demás va aparte (spec §7.3.6).
    // El mismo resumen que el widget y Siri (`resumirVariables`).
    final resumen = resumirVariables(variables, rollupPorCategoria, fijas: fijas);
    final gastadoVariables = resumen.gastadoConPresupuesto;
    final gastadoSinPresupuesto = resumen.gastadoSinPresupuesto;
    final presupuestoVariables = resumen.presupuesto;
    final gastadoFijas = Dinero.suma(fijas.map((c) => rollupPorCategoria[c.id]?.totalCentavos ?? const Dinero.cero()));
    final presupuestoFijas = Dinero.suma(
      fijas.map((c) => rollupPorCategoria[c.id]?.presupuestoCentavos ?? c.montoFijoCentavos),
    );
    final ingresos = calcularIngresosDelCiclo(ingresoBase: _perfil.ingresoBaseMensual, cicloId: _ciclo.id, extras: extras);
    final metaDelCiclo = calcularMetaDelCiclo(
      metaBase: calcularMetaBase(perfil: _perfil, categorias: categorias),
      ingresos: ingresos,
    );

    // Un solo pronóstico (MPC) y una sola recomendación, los mismos de
    // Análisis y del detalle de categoría (docs/rediseno/plan-rediseno.md,
    // Etapa 0).
    final estados = estadosDeVariables(categorias: efectivas, movimientos: todos, ciclo: _ciclo, hoy: hoy);
    final apartadoEstimado = calcularApartadoEstimado(
      ingreso: ingresos.total,
      presupuestoFijas: presupuestoFijas,
      gastadoFijas: gastadoFijas,
      presupuestoVariables: presupuestoVariables,
      proyeccionVariables: proyeccionTotal(estados),
    );

    return _DatosInicio(
      hayCategorias: categorias.isNotEmpty,
      rollupPorCategoria: rollupPorCategoria,
      fijas: fijas,
      variables: variables,
      gastadoVariables: gastadoVariables,
      gastadoSinPresupuesto: gastadoSinPresupuesto,
      presupuestoVariables: presupuestoVariables,
      totalGastado: Dinero.suma(rollups.map((r) => r.totalCentavos)),
      ingresos: ingresos,
      metaDelCiclo: metaDelCiclo,
      apartadoEstimado: apartadoEstimado,
      coberturas: calcularCoberturas(estados),
      hayGastos: movimientos.any((m) => m.estado == EstadoMovimiento.activo),
      pagoUrgente: pagoMasUrgente(
        await widget.almacenLocal.cuentas.listarTodas(),
        todos,
        await widget.almacenLocal.movimientosCuenta.listarTodos(),
        hoy: hoy,
      ),
    );
  }

  /// El ＋ abre Registrar desde cualquier raíz. Al guardar, el snackbar dice
  /// el resultado y ofrece Deshacer (componentes/Aviso.md).
  Future<void> _irACaptura({bool iniciarDictado = false}) async {
    // Object? en vez de Movimiento: el dictado por voz puede registrar
    // varios movimientos de golpe y regresa un sentinel (true).
    _capturaAbierta = true;
    final registrado = await Navigator.of(context).push<Object?>(
      // Sin fullscreenDialog: así iOS deja deslizar desde el borde para
      // cerrarla, igual que cualquier otra pantalla.
      MaterialPageRoute(
        builder: (_) => PantallaCaptura(
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          documentos: widget.almacenLocal.directorio,
          iniciarDictado: iniciarDictado,
          servicioIA: servicioIADe(widget.almacenLocal),
          cuentaRepositorio: widget.almacenLocal.cuentas,
          ajustePresupuestoCicloRepositorio: widget.ajustePresupuestoCicloRepositorio,
        ),
      ),
    );
    _capturaAbierta = false;
    if (registrado == null || !mounted) return;
    setState(() => _version++);
    await _cargar();
    if (registrado is Movimiento && mounted) _avisarGuardado(registrado);
  }

  void _avisarGuardado(Movimiento m) {
    final datos = _datos;
    final rollup = datos?.rollupPorCategoria[m.categoriaId];
    final categoria = [...?datos?.variables, ...?datos?.fijas].where((c) => c.id == m.categoriaId).firstOrNull;
    final presupuesto = rollup?.presupuestoCentavos;
    final String texto;
    if (categoria is CategoriaVariable && rollup != null && presupuesto != null && !presupuesto.esPositivo) {
      // Sin presupuesto: solo cuánto lleva (spec §7.3.6).
      texto = 'Listo, llevas ${enPesos(rollup.totalCentavos)} en ${categoria.nombre}';
    } else if (categoria is CategoriaVariable && rollup != null && presupuesto != null) {
      final quedan = presupuesto - rollup.totalCentavos;
      texto = quedan.esNegativo
          ? 'Listo. Te pasaste ${enPesos(quedan.absoluto)} en ${categoria.nombre}'
          : 'Listo, te quedan ${enPesos(quedan)} en ${categoria.nombre}';
    } else {
      texto = categoria == null ? 'Listo, quedó registrado' : 'Listo, quedó en ${categoria.nombre}';
    }
    final meses = m.meses;
    final aviso = m.esAMeses && meses != null
        ? '$texto · $meses meses de ${enPesos(m.monto)}'
        : texto;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(aviso),
        duration: const Duration(seconds: 7),
        // Con botón, Flutter la deja fija hasta tocarla; se va sola.
        persist: false,
        action: SnackBarAction(
          label: 'Deshacer',
          // Nada se borra: se anula (regla #3).
          onPressed: () async {
            await anularGasto(widget.movimientoRepositorio, m);
            if (!mounted) return;
            setState(() => _version++);
            await _cargar();
          },
        ),
      ));
  }

  Future<void> _irAAjustes() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaAjustes(perfil: _perfil, servicioAuth: widget.servicioAuth, almacenLocal: widget.almacenLocal),
      ),
    );
    final perfilActualizado = await widget.perfilRepositorio.obtener();
    if (!mounted) return;
    if (perfilActualizado != null) {
      setState(() {
        _perfil = perfilActualizado;
        _recalcularCiclo();
        _version++;
      });
    }
    await _cargar();
  }

  Future<void> _irACategorias() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCategorias(
          categoriaIngresoRepositorio: widget.almacenLocal.categoriasIngreso,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
        ),
      ),
    );
    await _cargar();
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
    if (mounted && perfilActualizado != null) setState(() => _perfil = perfilActualizado);
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
    if (mounted && perfilActualizado != null) setState(() => _perfil = perfilActualizado);
    await _cargar();
  }

  Future<void> _irADetalle(Categoria categoria) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalleCategoria(
          categoria: categoria,
          ciclo: _ciclo,
          avanceCiclo: _avanceCiclo,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          ajustePresupuestoCicloRepositorio: widget.ajustePresupuestoCicloRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          perfil: _perfil,
          documentos: widget.almacenLocal.directorio,
          cuentaRepositorio: widget.almacenLocal.cuentas,
        ),
      ),
    );
    await _cargar();
  }

  /// Desde Análisis: abre una categoría por id.
  /// Desde un ciclo de Historial: sus gastos de esa categoría, en Gastos ya
  /// filtrado (con flecha para volver al ciclo).
  Future<void> _irAGastosDe(String cicloId, String categoriaId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaGastos(
          cicloId: cicloId,
          categoriaInicial: categoriaId,
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          documentos: widget.almacenLocal.directorio,
          cuentaRepositorio: widget.almacenLocal.cuentas,
        ),
      ),
    );
  }

  /// Del aviso de pago a la tarjeta, donde está "Pagar esta tarjeta".
  Future<void> _irACuenta(Cuenta cuenta) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalleCuenta(
          categoriaIngresoRepositorio: widget.almacenLocal.categoriasIngreso,
          cuenta: cuenta,
          perfil: _perfil,
          cuentaRepositorio: widget.almacenLocal.cuentas,
          movimientoRepositorio: widget.movimientoRepositorio,
          movimientoCuentaRepositorio: widget.almacenLocal.movimientosCuenta,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        ),
      ),
    );
    _cargar();
  }

  Future<void> _irADetallePorId(String id) async {
    final categoria = (await widget.categoriaRepositorio.listarTodas()).where((c) => c.id == id).firstOrNull;
    if (categoria != null && mounted) await _irADetalle(categoria);
  }

  @override
  Widget build(BuildContext context) {
    final pestana = switch (_pestana) {
      Pestana.inicio => _cuerpoInicio(),
      Pestana.gastos => PantallaGastos(
          key: ValueKey('gastos-$_version'),
          cicloId: _ciclo.id,
          perfil: _perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          documentos: widget.almacenLocal.directorio,
          cuentaRepositorio: widget.almacenLocal.cuentas,
          nombre: _nombre,
          alAbrirAjustes: _irAAjustes,
          alRegistrar: _irACaptura,
        ),
      Pestana.analisis => PantallaAnalisis(
          key: ValueKey('analisis-$_version'),
          perfil: _perfil,
          ciclo: _ciclo,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          ajustePresupuestoCicloRepositorio: widget.ajustePresupuestoCicloRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
          cuentaRepositorio: widget.almacenLocal.cuentas,
          movimientoCuentaRepositorio: widget.almacenLocal.movimientosCuenta,
          cicloRepositorio: widget.cicloRepositorio,
          alVerCategoria: _irADetallePorId,
          alVerMovimientos: _irAGastosDe,
          categoriaIngresoRepositorio: widget.almacenLocal.categoriasIngreso,
          alVerGastos: () => _elegirPestana(Pestana.gastos),
          alVerMeta: _irAMeta,
          nombre: _nombre,
          alAbrirAjustes: _irAAjustes,
        ),
      Pestana.patrimonio => PantallaPatrimonio(
          categoriaIngresoRepositorio: widget.almacenLocal.categoriasIngreso,
          key: ValueKey('patrimonio-$_version'),
          perfil: _perfil,
          cuentaRepositorio: widget.almacenLocal.cuentas,
          movimientoRepositorio: widget.movimientoRepositorio,
          movimientoCuentaRepositorio: widget.almacenLocal.movimientosCuenta,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
          objetivoRepositorio: widget.almacenLocal.objetivos,
          categoriaRepositorio: widget.categoriaRepositorio,
          nombre: _nombre,
          alAbrirAjustes: _irAAjustes,
        ),
    };
    // Atrás en otra pestaña regresa a Inicio, no cierra la app.
    return PopScope(
      canPop: _pestana == Pestana.inicio,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _elegirPestana(Pestana.inicio);
      },
      child: Scaffold(
        body: _pestana == Pestana.inicio
            ? pestana
            : BordeParaRegresar(alRegresar: () => _elegirPestana(Pestana.inicio), child: pestana),
        bottomNavigationBar: BarraNavegacion(
          actual: _pestana,
          alElegir: _elegirPestana,
          alRegistrar: _irACaptura,
        ),
      ),
    );
  }

  Widget _cuerpoInicio() {
    final datos = _datos;
    final hoy = DateTime.now();
    final faltan = _ciclo.diasParaTerminar(hoy);
    final diaDelCiclo = _ciclo.diasDelCiclo - faltan;
    final rango = _ciclo.fechaInicio.month == _ciclo.fechaFin.month
        ? '${_ciclo.fechaInicio.day} – ${fechaCorta(_ciclo.fechaFin)}'
        : '${fechaCorta(_ciclo.fechaInicio)} – ${fechaCorta(_ciclo.fechaFin)}';
    final cuando = diaDelCiclo <= 1
        ? 'empieza hoy'
        : faltan == 0
            ? 'último día'
            : 'faltan $faltan ${faltan == 1 ? 'día' : 'días'}';
    final encabezado = EncabezadoRaiz(
      titulo: 'Ciclo ${_ciclo.etiquetaConAnio}',
      subtitulo: '$rango · $cuando',
      nombre: _nombre,
      alAbrirAjustes: _irAAjustes,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: datos == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  encabezado,
                  const Expanded(
                    child: CargandoPantalla(formas: [
                      Esqueleto.tarjeta(alto: 248),
                      SizedBox(height: 8),
                      Esqueleto(ancho: 140, alto: 18),
                      Esqueleto.tarjeta(alto: 92),
                      Esqueleto.tarjeta(alto: 92),
                      Esqueleto.tarjeta(alto: 92),
                    ]),
                  ),
                ],
              )
            : RefreshIndicator(
                // Deslizar hacia abajo recarga (p. ej. tras registrar desde
                // el widget o Siri con la app ya abierta).
                onRefresh: () async {
                  await _cargar();
                  if (mounted) await avisarGestoPrimeraVez(context, GestoApp.recargar);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    encabezado,
                    if (!datos.hayCategorias)
                      _SinCategorias(alCrear: _irACategorias)
                    else
                      ..._contenido(datos, diaDelCiclo),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _contenido(_DatosInicio datos, int diaDelCiclo) {
    final textos = Theme.of(context).textTheme;
    final p = ColoresApp.actual;
    final quedanVariables = datos.presupuestoVariables - datos.gastadoVariables;
    final coberturas = datos.coberturas;
    final urgente = coberturas.firstOrNull;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _Heroe(
          datos: datos,
          avanceCiclo: _avanceCiclo,
          dia: diaDelCiclo,
          dias: _ciclo.diasDelCiclo,
          alExplicar: () => _explicarHoy(datos),
          alVerMeta: _irAMeta,
        ),
      ),
      // Un solo banner: el más urgente, con su salida (componentes/Aviso.md).
      // Un pago de tarjeta por vencer va antes que un exceso: tiene fecha.
      if (datos.pagoUrgente case final pago?)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Builder(builder: (context) {
            final frases = frasesDePago(pago);
            return Aviso(
              tono: frases.tono,
              titulo: frases.titulo,
              apoyo: frases.apoyo,
              accion: 'Ver ${pago.cuenta.nombre}',
              onAccion: () => _irACuenta(pago.cuenta),
            );
          }),
        )
      else if (urgente != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Aviso(
            tono: TonoEstado.peligro,
            titulo: 'Te pasaste en ${urgente.categoria.nombre} por ${enPesos(urgente.exceso)}',
            apoyo: coberturas.length > 1 ? 'Y ${coberturas.length - 1} más en Análisis.' : null,
            accion: urgente.origen == null ? 'Ver ${urgente.categoria.nombre}' : 'Cubrir con ${urgente.origen!.nombre}',
            onAccion: () => _irADetalle(urgente.categoria),
          ),
        )
      else if (!datos.hayGastos)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: TarjetaApp(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded, color: p.texto),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registra tu primer gasto', style: textos.cuerpoFuerte),
                      Text('Toca ＋ cada vez que pagues algo.', style: textos.etiqueta),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _irACaptura,
                  child: const Text('Empezar'),
                ),
              ],
            ),
          ),
        ),
      if (datos.variables.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EncabezadoSeccion(
            titulo: datos.soloRegistro ? 'En qué se va' : 'Presupuesto',
            dato: datos.soloRegistro
                ? 'Llevas ${enPesos(datos.gastadoSinPresupuesto)}'
                : quedanVariables.esNegativo
                    ? 'Te pasaste ${enPesos(quedanVariables.absoluto)}'
                    : 'Quedan ${enPesos(quedanVariables)}',
            accion: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: const Icon(Icons.swap_vert),
                tooltip: 'Ordenar',
                visualDensity: VisualDensity.compact,
                onPressed: () => _ordenar(datos),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TarjetaApp.lista(
            renglones: [
              for (final c in _variablesOrdenadas(datos)) _renglonVariable(c, datos.rollupPorCategoria[c.id]),
            ],
          ),
        ),
      ],
      if (datos.fijas.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TarjetaApp.lista(renglones: [_renglonFijos(datos)]),
        ),
    ];
  }

  /// El presupuesto en el orden que eligió el usuario (spec §5.6.4); por
  /// omisión, lo que necesita atención primero.
  List<CategoriaVariable> _variablesOrdenadas(_DatosInicio datos) => ordenarPresupuesto(
        datos.variables,
        datos.rollupPorCategoria,
        orden: OrdenPresupuesto.deNombre(_perfil.ordenPresupuesto),
        avanceCiclo: _avanceCiclo,
        ordenPropio: _perfil.ordenPropio,
      );

  Future<void> _ordenar(_DatosInicio datos) async {
    final eleccion = await mostrarHojaOrdenPresupuesto(
      context,
      orden: OrdenPresupuesto.deNombre(_perfil.ordenPresupuesto),
      actuales: _variablesOrdenadas(datos),
      ordenPropio: _perfil.ordenPropio,
    );
    if (eleccion == null || !mounted) return;
    final perfil = _perfil.copyWith(ordenPresupuesto: eleccion.orden.name, ordenPropio: eleccion.propio);
    setState(() => _perfil = perfil);
    await widget.perfilRepositorio.guardar(perfil);
  }

  Widget _renglonVariable(CategoriaVariable c, Rollup? rollup) {
    final p = ColoresApp.actual;
    final gastado = rollup?.totalCentavos ?? const Dinero.cero();
    final presupuesto = rollup?.presupuestoCentavos ?? c.presupuestoMensualCentavos;
    // Sin presupuesto (spec §7.3.6): cuánto lleva, sin barra ni juicio.
    if (!presupuesto.esPositivo) {
      return RenglonApp(
        emoji: c.emoji,
        titulo: c.nombre,
        subtitulo: 'Sin presupuesto',
        monto: 'Llevas ${enPesos(gastado)}',
        onTap: () => _irADetalle(c),
        etiquetaSemantica: '${c.nombre}: llevas ${montoEnPalabras(gastado)}, sin presupuesto.',
      );
    }
    final quedan = presupuesto - gastado;
    final porcentaje = presupuesto.esPositivo ? gastado.centavos / presupuesto.centavos : 0.0;
    final tono = tonoDeRitmo(porcentajeUsado: rollup?.porcentajeUsado, avanceCiclo: _avanceCiclo);
    final resto = quedan.esNegativo ? 'Te pasaste ${enPesos(quedan.absoluto)}' : 'Quedan ${enPesos(quedan)}';
    return RenglonApp(
      emoji: c.emoji,
      titulo: c.nombre,
      monto: resto,
      colorMonto: quedan.esNegativo ? p.peligroTexto : null,
      onTap: () => _irADetalle(c),
      etiquetaSemantica: '${c.nombre}: gastaste ${montoEnPalabras(gastado)} de ${montoEnPalabras(presupuesto)}. '
          '${etiquetaTonoRitmo(tono)}. $resto.',
      abajo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BarraRitmo(porcentajeUsado: porcentaje, avanceCiclo: _avanceCiclo, descripcion: c.nombre),
          const SizedBox(height: 2),
          Text('${enPesos(gastado)} de ${enPesos(presupuesto)}', style: Theme.of(context).textTheme.etiqueta),
        ],
      ),
    );
  }

  /// Un solo renglón para las fijas: "Al día" o "Por pagar"
  /// (Inicio.dc.html); el detalle va en una hoja.
  Widget _renglonFijos(_DatosInicio datos) {
    final pagada = {
      for (final c in datos.fijas) c.id: (datos.rollupPorCategoria[c.id]?.conteoMovimientos ?? 0) > 0,
    };
    final pendientes = [for (final c in datos.fijas) if (!pagada[c.id]!) c]
      ..sort((a, b) => a.diaDelCiclo.compareTo(b.diaDelCiclo));
    final alDia = pendientes.isEmpty;
    final referencia = alDia ? datos.fijas.first : pendientes.first;
    final otras = datos.fijas.length - 1;
    final subtitulo = alDia
        ? '${referencia.nombre}${otras > 0 ? ' y $otras más' : ''} · pagado'
        : '${referencia.nombre} · vence ${fechaCorta(_fechaDeCobro(referencia))}'
            '${pendientes.length > 1 ? ' · y ${pendientes.length - 1} más' : ''}';
    return RenglonApp(
      icono: Icons.event_repeat_rounded,
      titulo: 'Fijos',
      subtitulo: subtitulo,
      derecha: alDia
          ? const ChipEstado(tono: TonoEstado.exito, texto: 'Al día')
          : const ChipEstado(tono: TonoEstado.neutro, texto: 'Por pagar', icono: Icons.calendar_today_rounded),
      onTap: () => _verFijas(datos, pagada),
    );
  }

  /// El día de cobro de una fija dentro del ciclo en curso.
  DateTime _fechaDeCobro(CategoriaFija c) {
    final inicio = _ciclo.fechaInicio;
    return DateTime(inicio.year, inicio.month, inicio.day + (c.diaDelCiclo - 1).clamp(0, _ciclo.diasDelCiclo - 1));
  }

  Future<void> _verFijas(_DatosInicio datos, Map<String, bool> pagada) async {
    final textos = Theme.of(context).textTheme;
    final elegida = await mostrarHoja<CategoriaFija>(
      context,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Fijos', style: textos.seccion),
              const SizedBox(height: 12),
              TarjetaApp.lista(
                renglones: [
                  for (final c in datos.fijas)
                    RenglonApp(
                      emoji: c.emoji,
                      titulo: c.nombre,
                      subtitulo: pagada[c.id]! ? 'Pagado' : 'Vence ${fechaCorta(_fechaDeCobro(c))}',
                      monto: enPesos(datos.rollupPorCategoria[c.id]?.presupuestoCentavos ?? c.montoFijoCentavos),
                      onTap: () => Navigator.of(contexto).pop(c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (elegida != null) await _irADetalle(elegida);
  }

  /// ⓘ "Cómo se calcula": las explicaciones viven en una hoja, nunca fijas
  /// en la pantalla (regla 1 · 6 · 12). Es también la puerta a los
  /// ingresos del ciclo.
  Future<void> _explicarHoy(_DatosInicio datos) async {
    final textos = Theme.of(context).textTheme;
    final quedan = datos.presupuestoVariables - datos.gastadoVariables;
    final faltan = _ciclo.diasParaTerminar(DateTime.now());
    final irAIngresos = await mostrarHoja<bool>(
      context,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cómo se calcula', style: textos.seccion),
              const SizedBox(height: 12),
              Text(
                datos.soloRegistro
                    ? 'Llevas gastado: lo de tus categorías variables en este ciclo. No tienen presupuesto, '
                        'así que solo ves en qué se te va; si algún día quieres uno, ponle monto a la '
                        'categoría. Las fijas (renta, colegiaturas…) van aparte, en el renglón Fijos.'
                    : 'Llevas gastado: lo de tus categorías variables en este ciclo, contra lo que les '
                        'asignaste. Te quedan ${enPesos(quedan)} para los $faltan ${faltan == 1 ? 'día' : 'días'} '
                        'que faltan. Las fijas (renta, colegiaturas…) van aparte, en el renglón Fijos.'
                        '${datos.gastadoSinPresupuesto.esPositivo ? ' Lo de las categorías sin presupuesto '
                            '(${enPesos(datos.gastadoSinPresupuesto)}) no entra en la cuenta.' : ''}',
                style: textos.cuerpo,
              ),
              const SizedBox(height: 16),
              TarjetaApp.lista(renglones: [
                RenglonApp(icono: Icons.south_west_rounded, titulo: 'Entró este ciclo', monto: enPesos(datos.ingresos.total)),
                RenglonApp(icono: Icons.receipt_long_outlined, titulo: 'Gastaste', monto: enPesos(datos.totalGastado)),
                RenglonApp(
                  icono: Icons.savings_outlined,
                  titulo: 'Sin gastar',
                  monto: enPesos(datos.ingresos.total - datos.totalGastado),
                ),
              ]),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => Navigator.of(contexto).pop(true), child: const Text('Ver ingresos del ciclo')),
            ],
          ),
        ),
      ),
    );
    if (irAIngresos == true) await _irAIngresos();
  }
}

/// La tarjeta héroe de Inicio: veredicto, "Llevas gastado" (variables del
/// ciclo contra su presupuesto, 2026-11-15; antes "Hoy puedes gastar"),
/// ritmo de las variables y la meta del ciclo.
class _Heroe extends StatelessWidget {
  final _DatosInicio datos;
  final double avanceCiclo;
  final int dia;
  final int dias;
  final VoidCallback alExplicar;
  final VoidCallback alVerMeta;

  const _Heroe({
    required this.datos,
    required this.avanceCiclo,
    required this.dia,
    required this.dias,
    required this.alExplicar,
    required this.alVerMeta,
  });

  String get _textoMeta {
    final meta = datos.metaDelCiclo;
    final apartado = datos.apartadoEstimado;
    if (!meta.esPositivo) return 'Ponte una meta de apartado';
    if (!datos.hayGastos) return 'Apartas ${enPesos(meta)} si sigues el plan';
    if (apartado.esNegativo) return 'Si sigues así, no alcanzas a apartar';
    if (apartado >= meta) return 'Apartas ${enPesos(meta)} de ${enPesos(meta)}';
    return 'Si sigues así, apartas ${enPesos(apartado)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final presupuesto = datos.presupuestoVariables;
    final porcentaje = presupuesto.esPositivo ? datos.gastadoVariables.centavos / presupuesto.centavos : 0.0;
    final tono = tonoDeRitmo(porcentajeUsado: presupuesto.esPositivo ? porcentaje : null, avanceCiclo: avanceCiclo);
    // Solo registro (spec §7.3.6): sin presupuesto no hay ritmo que juzgar.
    final solo = datos.soloRegistro;
    final chip = datos.hayGastos && !solo
        ? ChipEstado.ritmo(tono, enHeroe: true)
        : ChipEstado(
            tono: TonoEstado.neutro,
            texto: 'Día $dia de $dias',
            icono: Icons.calendar_today_rounded,
            enHeroe: true,
          );
    // Sin presupuestos, todo lo gastado del ciclo, fijas incluidas.
    final gastado = solo ? datos.totalGastado : datos.gastadoVariables;
    final (pesos, centavos) = partesDeMonto(gastado);
    final quedan = presupuesto - gastado;
    // Igual que el encabezado ("faltan N días"): sin contar hoy.
    final faltan = dias - dia;
    final dicenDias = switch (faltan) {
      <= 0 => 'último día',
      1 => 'falta 1 día',
      _ => 'faltan $faltan días',
    };
    final veredicto = datos.hayGastos && !solo ? etiquetaTonoRitmo(tono) : 'Día $dia de $dias';
    // Sin presupuestos: lo que entró y lo que queda de ello (con las fijas).
    final deLoQueEntro = datos.ingresos.total - datos.totalGastado;
    final pie = solo
        ? 'Entró ${enPesos(datos.ingresos.total)} · '
            '${deLoQueEntro.esNegativo ? 'gastaste ${enPesos(deLoQueEntro.absoluto)} de más' : 'te quedan ${enPesos(deLoQueEntro)}'}'
            ' · $dicenDias'
        : quedan.esNegativo
            ? 'Te pasaste por ${enPesos(quedan.absoluto)} · $dicenDias'
            : 'Te quedan ${enPesos(quedan)} · $dicenDias';
    final aparte = !solo && datos.gastadoSinPresupuesto.esPositivo
        ? 'Además, ${enPesos(datos.gastadoSinPresupuesto)} en categorías sin presupuesto'
        : null;

    return TarjetaApp.heroe(
      etiquetaSemantica: solo
          ? 'Llevas gastado ${montoEnPalabras(gastado)} en este ciclo. $pie.'
          : 'Llevas gastado ${montoEnPalabras(gastado)} de ${montoEnPalabras(presupuesto)} en variables. $veredicto.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: ExcludeSemantics(child: chip)),
              IconButton(
                tooltip: 'Cómo se calcula',
                onPressed: alExplicar,
                icon: Icon(Icons.info_outline_rounded, color: p.heroeTexto2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(child: Text('Llevas gastado', style: textos.etiqueta.copyWith(color: p.heroeTexto2))),
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: pesos),
                      TextSpan(
                        text: centavos,
                        style: TextStyle(fontSize: textos.cifraHeroe.fontSize! / 2, color: p.heroeTexto2),
                      ),
                    ]),
                    style: textos.cifraHeroe.copyWith(color: p.heroeTexto),
                    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                  ),
                ),
                if (!solo) ...[
                  const SizedBox(width: 8),
                  Text('de ${enPesos(presupuesto)}', style: textos.cuerpoFuerte.copyWith(color: p.heroeTexto2)),
                ],
              ],
            ),
          ),
          if (!solo) ...[
            const SizedBox(height: 14),
            BarraRitmo(
              porcentajeUsado: porcentaje,
              avanceCiclo: avanceCiclo,
              descripcion: 'Tus variables',
              gastado: datos.gastadoVariables,
              presupuesto: presupuesto,
              enHeroe: true,
            ),
          ],
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(pie, style: textos.etiqueta.copyWith(color: p.heroeTexto2)),
          ),
          if (aparte != null)
            ExcludeSemantics(
              child: Text(aparte, style: textos.etiqueta.copyWith(color: p.heroeTexto2)),
            ),
          const SizedBox(height: 14),
          Divider(height: 1, color: p.heroePista),
          InkWell(
            onTap: alVerMeta,
            borderRadius: BorderRadius.circular(Radios.m),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle),
                    child: Icon(Icons.track_changes_rounded, color: p.oro, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Meta del ciclo', style: textos.etiqueta.copyWith(color: p.heroeTexto2)),
                        Text(_textoMeta, style: textos.cuerpoFuerte.copyWith(color: p.heroeTexto)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.heroeTexto2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinCategorias extends StatelessWidget {
  final VoidCallback alCrear;

  const _SinCategorias({required this.alCrear});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Arma tu plan', style: textos.cuerpoFuerte),
            Text('Crea tus categorías para ver cuánto puedes gastar.', style: textos.etiqueta),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: alCrear, child: const Text('Crear categorías')),
          ],
        ),
      ),
    );
  }
}

/// La barra inferior: cuatro destinos y el ＋ dorado al centro
/// (`docs/rediseno/design-system/componentes/Navegacion.md`). El ＋ es el
/// único uso de oro en controles y nunca se oculta en las raíces.
class BarraNavegacion extends StatelessWidget {
  final Pestana actual;
  final ValueChanged<Pestana> alElegir;
  final VoidCallback alRegistrar;

  const BarraNavegacion({super.key, required this.actual, required this.alElegir, required this.alRegistrar});

  /// Barra flotante en cápsula (estilo de las apps de iOS, como WhatsApp):
  /// las pestañas en una burbuja con la activa resaltada y el ＋ dorado al
  /// centro, dentro de la misma cápsula.
  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    Widget destino(Pestana pestana, IconData icono, IconData iconoActivo, String etiqueta) {
      final activo = actual == pestana;
      return Expanded(
        child: Semantics(
          selected: activo,
          button: true,
          label: etiqueta,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => alElegir(pestana),
            child: AnimatedContainer(
              duration: Duracion.rapida,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: activo ? p.accion.withValues(alpha: p.esOscura ? 0.22 : 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(Radios.pill),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(activo ? iconoActivo : icono, size: 22, color: activo ? p.accion : p.texto2),
                  const SizedBox(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    // En pantallas angostas "Patrimonio" no cabe completo:
                    // se encoge un poco en vez de cortarse.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        etiqueta,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.etiqueta.copyWith(
                              color: activo ? p.accion : p.texto2,
                              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: p.fondo,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        // Alto fijo: las etiquetas crecen con el texto del sistema, acotadas.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: SizedBox(
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: p.superficie,
                  borderRadius: BorderRadius.circular(Radios.pill),
                  border: Border.all(color: p.borde),
                  boxShadow: sombra1(p),
                ),
                child: Row(
                  children: [
                    destino(Pestana.inicio, Icons.home_outlined, Icons.home_rounded, 'Inicio'),
                    destino(Pestana.gastos, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Gastos'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        button: true,
                        label: 'Registrar gasto',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: alRegistrar,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(color: p.oro, shape: BoxShape.circle, boxShadow: sombraFab(p)),
                            child: Icon(Icons.add_rounded, size: 30, color: p.sobreOro),
                          ),
                        ),
                      ),
                    ),
                    destino(Pestana.analisis, Icons.insights_outlined, Icons.insights_rounded, 'Análisis'),
                    destino(
                      Pestana.patrimonio,
                      Icons.account_balance_wallet_outlined,
                      Icons.account_balance_wallet_rounded,
                      'Patrimonio',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DatosInicio {
  final bool hayCategorias;
  final Map<String, Rollup> rollupPorCategoria;
  final List<CategoriaFija> fijas;

  /// Ya ordenadas: lo que necesita atención primero.
  final List<CategoriaVariable> variables;

  /// Lo gastado en las variables **con** presupuesto: lo que se compara
  /// contra [presupuestoVariables] (spec §7.3.6).
  final Dinero gastadoVariables;

  /// Lo gastado en variables sin presupuesto.
  final Dinero gastadoSinPresupuesto;
  final Dinero presupuestoVariables;
  final Dinero totalGastado;
  final IngresosDelCiclo ingresos;
  final Dinero metaDelCiclo;
  final Dinero apartadoEstimado;
  final List<Cobertura> coberturas;
  final bool hayGastos;

  /// La tarjeta que hay que pagar pronto o que se pasó (spec §7.3.1).
  final PagoTarjeta? pagoUrgente;

  /// Ninguna variable con presupuesto: solo se registra (spec §7.3.6).
  bool get soloRegistro => !presupuestoVariables.esPositivo;

  const _DatosInicio({
    required this.hayCategorias,
    required this.rollupPorCategoria,
    required this.fijas,
    required this.variables,
    required this.gastadoVariables,
    this.gastadoSinPresupuesto = const Dinero.cero(),
    required this.presupuestoVariables,
    required this.totalGastado,
    required this.ingresos,
    required this.metaDelCiclo,
    required this.apartadoEstimado,
    required this.coberturas,
    required this.hayGastos,
    this.pagoUrgente,
  });
}
