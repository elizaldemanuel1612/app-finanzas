import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/analisis/ciclo_comparable.dart';
import '../../domain/analisis/gastos_recurrentes.dart';
import '../../domain/analisis/corte_pareto.dart';
import '../../domain/analisis/presupuestos_del_cierre.dart';
import '../../domain/analisis/recomendaciones.dart';
import '../../domain/analisis/reparto_ingreso.dart';
import '../../domain/analisis/reporte_analisis.dart';
import '../../domain/analisis/veredicto_ciclo.dart';
import '../../domain/ciclo_de_vida/ciclos_para_consultar.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../comun/aviso_gesto.dart';
import '../comun/guia_rapida.dart';
import '../comun/selector_ciclo.dart';
import '../comun/tema.dart';
import '../comun/formato_fecha.dart';
import '../comun/tarjeta_app.dart';
import '../comun/renglon_app.dart';
import '../comun/formato_dinero.dart';
import '../comun/esqueleto.dart';
import '../comun/chip_estado.dart';
import '../comun/barra_ritmo.dart';
import '../comun/avatar_ajustes.dart';
import '../ciclo/pantalla_ciclos_anteriores.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../../domain/presupuesto/cobertura_excesos.dart';
import '../../domain/presupuesto/apartado_estimado.dart';
import '../../domain/analisis/frases_conclusion.dart';
import 'graficas_analisis.dart';
import 'vista_periodo.dart';

/// Pestaña Análisis (spec-app-finanzas-v2.md §5.7): reportes y
/// recomendaciones del ciclo en curso o, con el selector de arriba, de un
/// ciclo pasado tal como quedó. Todo el cálculo vive en
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

  /// Para elegir un ciclo pasado y para Historial; sin él solo se ve el
  /// ciclo en curso.
  final CicloRepositorio? cicloRepositorio;

  /// Como pestaña raíz: encabezado con el avatar que abre Ajustes.
  final String? nombre;
  final VoidCallback? alAbrirAjustes;

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
    this.cicloRepositorio,
    this.nombre,
    this.alAbrirAjustes,
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

  /// El ciclo que se está viendo y todos los que se pueden elegir (vacío
  /// sin `cicloRepositorio`).
  final Ciclo ciclo;
  final List<CicloConsultable> ciclos;

  /// Lo que se apartaría al cierre (MPC; en un ciclo terminado, lo real).
  final Dinero apartadoEstimado;

  /// La salida de cada categoría que se pasó: la misma de Inicio y Categoría.
  final List<Cobertura> coberturas;

  /// Lo que se repite en todo el historial, con el emoji de su categoría.
  final List<({GastoRecurrente gasto, String emoji})> recurrentes;

  const _Datos(
    this.reporte,
    this.recomendaciones,
    this.ingreso,
    this.categorias,
    this.cuentas,
    this.metaCiclo,
    this.ciclo,
    this.ciclos,
    this.apartadoEstimado,
    this.coberturas,
    this.recurrentes,
  );

}

/// Análisis › Resumen · Detalle · Historial (`docs/rediseno/plan-rediseno.md`,
/// Etapa 5). Historial reemplaza a "Ciclos anteriores" de Inicio.
enum _Vista { resumen, detalle, historial, periodo }

class _PantallaAnalisisState extends State<PantallaAnalisis> {
  _Datos? _datos;
  _Vista _vista = _Vista.resumen;

  /// Siempre abre en el ciclo en curso.
  late String _cicloVisto = widget.ciclo.id;

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

  void _verCiclo(String cicloId) {
    setState(() => _cicloVisto = cicloId);
    _cargar();
  }

  Future<void> _cargar() async {
    final todas = await widget.categoriaRepositorio.listarTodas();
    final movimientos = await widget.movimientoRepositorio.listarTodos();

    // El ciclo a ver: el en curso, o uno pasado elegido en el selector. De un
    // ciclo cerrado se usa su fotografía del cierre (presupuestos, ingreso y
    // meta de ese día), para verlo como quedó.
    final calculadora = widget.perfil.calculadoraCiclo;
    final guardados = await widget.cicloRepositorio?.listarTodos() ?? const [];
    final ciclos = widget.cicloRepositorio == null
        ? const <CicloConsultable>[]
        : ciclosParaConsultar(
            enCurso: widget.ciclo,
            movimientos: movimientos,
            guardados: guardados,
            calculadora: calculadora,
          );
    final ciclo = ciclos.where((c) => c.ciclo.id == _cicloVisto).firstOrNull?.ciclo ?? widget.ciclo;
    final guardado = guardados.where((g) => g.ciclo.id == ciclo.id).firstOrNull;
    final cierre = ciclo.estado == EstadoCiclo.cerrado ? guardado?.snapshot : null;

    final ajustes = await widget.ajustePresupuestoCicloRepositorio.listarPorCiclo(ciclo.id);
    final extras = await widget.ingresoExtraRepositorio.listarPorCiclo(ciclo.id);

    final efectivas = presupuestosDelCierre(
      categorias: presupuestosEfectivosParaCiclo(base: todas, ajustesDelCiclo: ajustes),
      snapshot: cierre,
    );
    final anterior = calculadora.calcularPara(
      ciclo.fechaInicio.subtract(const Duration(days: 1)),
    );
    // "Contra el ciclo pasado" solo con un ciclo cerrado y completo
    // (docs/rediseno/plan-rediseno.md, Etapa 0).
    final comparable = cicloComparable(anterior: anterior, guardados: guardados, movimientos: movimientos);
    final reporte = calcularReporteAnalisis(
      ciclo: ciclo,
      cicloAnterior: comparable ? anterior : null,
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
    final metaCiclo = cierre?.metaApartado ?? calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresos);
    final ingreso = cierre?.ingresoTotal ?? ingresos.total;
    final recomendaciones = calcularRecomendaciones(
      reporte: reporte,
      ingresoCiclo: ingreso,
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
          ingreso,
          [for (final c in efectivas) if (c.activa) c],
          cuentas,
          metaCiclo,
          ciclo,
          ciclos,
          calcularApartadoEstimado(
            ingreso: ingreso,
            presupuestoFijas: reporte.presupuestoFijas,
            gastadoFijas: reporte.gastadoFijas,
            presupuestoVariables: reporte.presupuestoVariables,
            proyeccionVariables: reporte.proyeccionVariables,
          ),
          calcularCoberturas(reporte.variables),
          [
            for (final g in detectarRecurrentes(movimientos, hoy: DateTime.now()))
              (gasto: g, emoji: todas.where((c) => c.id == g.categoriaId).firstOrNull?.emoji ?? '🔁'),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final raiz = widget.alAbrirAjustes != null;
    final conHistorial = widget.cicloRepositorio != null;
    final vista = !conHistorial && _vista == _Vista.historial ? _Vista.resumen : _vista;
    final segmentado = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: SegmentedButton<_Vista>(
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(value: _Vista.resumen, label: Text('Resumen')),
          const ButtonSegment(value: _Vista.detalle, label: Text('Detalle')),
          if (conHistorial) const ButtonSegment(value: _Vista.historial, label: Text('Historial')),
          const ButtonSegment(value: _Vista.periodo, label: Text('Periodo')),
        ],
        selected: {vista},
        onSelectionChanged: (s) => _elegirVista(s.first),
      ),
    );
    final Widget cuerpo;
    if (vista == _Vista.periodo) {
      cuerpo = VistaPeriodo(
        categoriaRepositorio: widget.categoriaRepositorio,
        movimientoRepositorio: widget.movimientoRepositorio,
        alVerCategoria: widget.alVerCategoria,
      );
    } else if (vista == _Vista.historial) {
      cuerpo = PantallaCiclosAnteriores(
        embebida: true,
        perfil: widget.perfil,
        cicloActual: widget.ciclo,
        categoriaRepositorio: widget.categoriaRepositorio,
        movimientoRepositorio: widget.movimientoRepositorio,
        cicloRepositorio: widget.cicloRepositorio!,
        ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        cuentaRepositorio: widget.cuentaRepositorio,
        movimientoCuentaRepositorio: widget.movimientoCuentaRepositorio,
      );
    } else if (datos == null) {
      cuerpo = const CargandoPantalla(formas: [
        Esqueleto(alto: 44, radio: Radios.m),
        Esqueleto.tarjeta(alto: 180),
        Esqueleto(ancho: 120, alto: 18),
        Esqueleto.tarjeta(alto: 140),
      ]);
    } else {
      cuerpo = Column(
        children: [
          if (datos.ciclos.length > 1)
            SelectorCiclo(ciclos: datos.ciclos, vistoId: datos.ciclo.id, enCursoId: widget.ciclo.id, alCambiar: _verCiclo),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _cargar();
                if (context.mounted) await avisarGestoPrimeraVez(context, GestoApp.recargar);
              },
              child: datos.reporte.sinMovimientos
                  ? _vacio(context)
                  : vista == _Vista.resumen
                      ? _contenidoResumen(context, datos)
                      : _contenidoDetalle(context, datos),
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: raiz ? null : AppBar(title: const Text('Análisis')),
      body: SafeArea(
        bottom: false,
        top: raiz,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (raiz) EncabezadoRaiz(titulo: 'Análisis', nombre: widget.nombre, alAbrirAjustes: widget.alAbrirAjustes!),
            segmentado,
            Expanded(child: cuerpo),
          ],
        ),
      ),
    );
  }

  /// Resumen: el veredicto, "Qué hacer" (máximo 2) y "En qué se fue".
  Widget _contenidoResumen(BuildContext context, _Datos datos) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final r = datos.reporte;
    final avance = r.diaDelCiclo / r.diasDelCiclo;
    final presupuesto = r.presupuestoVariables;
    final porcentaje = presupuesto.esPositivo ? r.gastadoVariables.centavos / presupuesto.centavos : 0.0;
    final tono = tonoDeRitmo(porcentajeUsado: presupuesto.esPositivo ? porcentaje : null, avanceCiclo: avance);
    final meta = datos.metaCiclo;
    final apartado = datos.apartadoEstimado;
    final veredicto = calcularVeredicto(reporte: r, hoy: DateTime.now());

    // Qué hacer: primero las coberturas (la misma salida que Inicio y
    // Categoría), luego el ritmo diario. Máximo dos.
    final queHacer = <Widget>[
      for (final c in datos.coberturas.take(2))
        RenglonApp(
          icono: Icons.swap_horiz_rounded,
          fondoIcono: p.peligroFondo,
          colorIcono: p.peligroTexto,
          titulo: c.origen == null ? 'Te pasaste en ${c.categoria.nombre}' : 'Cubre ${c.categoria.nombre} con ${c.origen!.nombre}',
          subtitulo: c.origen == null
              ? 'Sale de lo que apartas'
              : c.falta.esPositivo
                  ? 'Alcanza para ${enPesos(c.cubre)} de ${enPesos(c.exceso)}'
                  : 'A ${c.origen!.nombre} le sobrarán ${enPesos(c.sobranteDespues)}',
          derecha: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () => widget.alVerCategoria(c.categoria.id),
            child: Text(c.origen == null ? 'Ver' : 'Mover ${enPesos(c.cubre)}'),
          ),
        ),
      if (datos.coberturas.length < 2 && !r.terminado && veredicto.disponibleHoy != null)
        RenglonApp(
          icono: Icons.speed_rounded,
          fondoIcono: p.atencionFondo,
          colorIcono: p.atencionTexto,
          titulo: 'Gasta hasta ${enPesos(veredicto.disponibleHoy!)} al día',
          subtitulo: meta.esPositivo ? 'Así llegas a tu meta completa' : 'Así no te pasas de lo planeado',
        ),
    ];

    final variables = [
      for (final e in r.variables)
        if (e.gastado.esPositivo) e,
    ]..sort((a, b) => b.gastado.compareTo(a.gastado));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        TarjetaApp(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipEstado(
                tono: tonoEstadoDeRitmo(tono),
                texto: r.terminado ? veredicto.titulo : etiquetaTonoRitmo(tono),
              ),
              const SizedBox(height: 14),
              Text(r.terminado ? 'Apartaste' : 'Si sigues así, apartas', style: textos.etiqueta),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      apartado.esNegativo ? r'$0' : enPesos(apartado),
                      style: textos.cifraHeroe,
                      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                    ),
                  ),
                  if (meta.esPositivo) ...[const SizedBox(width: 8), Text('de ${enPesos(meta)}', style: textos.etiqueta)],
                ],
              ),
              const SizedBox(height: 14),
              BarraRitmo(
                porcentajeUsado: porcentaje,
                avanceCiclo: avance,
                descripcion: 'Tus variables',
                gastado: r.gastadoVariables,
                presupuesto: presupuesto,
              ),
              const SizedBox(height: 4),
              Text('${enPesos(r.gastadoVariables)} de ${enPesos(presupuesto)} en variables', style: textos.etiqueta),
            ],
          ),
        ),
        if (queHacer.isNotEmpty) ...[
          const EncabezadoSeccion(titulo: 'Qué hacer'),
          TarjetaApp.lista(renglones: queHacer),
        ],
        if (variables.isNotEmpty) ...[
          EncabezadoSeccion(
            titulo: 'En qué se fue',
            accion: TextButton(onPressed: () => _elegirVista(_Vista.detalle), child: const Text('Ver detalle')),
          ),
          TarjetaApp.lista(renglones: [
            for (final e in variables.take(4))
              RenglonApp(
                emoji: e.categoria.emoji,
                titulo: e.categoria.nombre,
                monto: enPesos(e.gastado),
                onTap: () => widget.alVerCategoria(e.categoria.id),
                abajo: BarraRitmo(
                  porcentajeUsado: e.presupuesto.esPositivo ? e.gastado.centavos / e.presupuesto.centavos : 0,
                  avanceCiclo: avance,
                  descripcion: e.categoria.nombre,
                  gastado: e.gastado,
                  presupuesto: e.presupuesto,
                ),
              ),
          ]),
        ],
      ],
    );
  }

  /// Detalle: cada gráfica con una frase-conclusión como título.
  Widget _contenidoDetalle(BuildContext context, _Datos datos) {
    final r = datos.reporte;
    final parejo = Dinero(r.presupuestoVariables.centavos * r.diaDelCiclo ~/ r.diasDelCiclo);
    final arriba = r.gastadoVariables > parejo;
    final diferencia = (r.gastadoVariables - parejo).absoluto;
    final ritmo = r.terminado
        ? 'Cerraste ${enPesos(diferencia)} ${arriba ? 'arriba' : 'abajo'} de tu presupuesto'
        : 'Vas ${enPesos(diferencia)} ${arriba ? 'arriba' : 'abajo'} del ritmo parejo';
    final faltaMeta = datos.metaCiclo - datos.apartadoEstimado;
    final plan = !datos.metaCiclo.esPositivo
        ? 'Así se reparte lo que entra'
        : faltaMeta.esPositivo
            ? 'Las variables se comen ${enPesos(faltaMeta)} de tu meta'
            : (r.terminado ? 'Apartaste toda tu meta' : 'Si sigues así, apartas toda tu meta');

    final variablesConGasto = [for (final g in r.porCategoria) if (g.categoria is CategoriaVariable) g];
    final principal = variablesConGasto.firstOrNull;
    final porCategoria = principal == null || !r.gastadoVariables.esPositivo
        ? 'Tus categorías'
        : '${principal.categoria.nombre} es ${fraccionEnPalabras(principal.total.centavos / r.gastadoVariables.centavos)} de tus variables';

    final masSubio = [for (final c in r.contraAnterior) if (c.diferencia.esPositivo) c]
      ..sort((a, b) => b.diferencia.compareTo(a.diferencia));
    final nombreAnterior = _mesAnterior(r.ciclo);
    final contra = masSubio.isEmpty
        ? 'Gastas menos que en $nombreAnterior'
        : '${masSubio.first.categoria.nombre} subió ${enPesos(masSubio.first.diferencia)}';

    var mayor = 0;
    for (var i = 1; i < 7; i++) {
      if (r.promedioPorDiaSemana[i] > r.promedioPorDiaSemana[mayor]) mayor = i;
    }
    final resto = [for (var i = 0; i < 7; i++) if (i != mayor) r.promedioPorDiaSemana[i].centavos];
    final promedioResto = resto.reduce((a, b) => a + b) ~/ resto.length;
    final veces = vecesMas(r.promedioPorDiaSemana[mayor].centavos, promedioResto);
    final dia = veces == null ? 'Tus gastos por día de la semana' : 'Los ${nombresDiaSemana[mayor]} gastas $veces';

    final total = r.conTarjeta + r.enEfectivo;
    final pago = !total.esPositivo
        ? 'Cómo pagas'
        : r.conTarjeta >= r.enEfectivo
            ? '${_mayuscula(deCadaPeso(r.conTarjeta.centavos / total.centavos))} van a tarjeta'
            : '${_mayuscula(deCadaPeso(r.enEfectivo.centavos / total.centavos))} van en efectivo';

    final cerrados = [for (final c in r.ultimosCiclos) if (!c.enCurso) c.total.centavos];
    final ultimos = cerrados.isEmpty
        ? 'Tu primer ciclo'
        : 'En promedio gastas ${enPesos(Dinero(cerrados.reduce((a, b) => a + b) ~/ cerrados.length))} por ciclo';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (r.acumuladoVariablesPorDia.isNotEmpty) ...[
          _Conclusion(etiqueta: 'Ritmo del ciclo', titulo: ritmo),
          _Ritmo(reporte: r),
        ],
        _Conclusion(etiqueta: 'Plan contra cierre', titulo: plan),
        _PesoDeCadaParte(
          datos: datos,
          parte: _parte,
          alCambiar: (p) => setState(() => _parte = p),
          alVerCategoria: widget.alVerCategoria,
        ),
        _Conclusion(etiqueta: 'Por categoría', titulo: porCategoria),
        _EnQueSeVa(reporte: r, parte: _parte, alVerCategoria: widget.alVerCategoria),
        if (r.contraAnterior.isNotEmpty) ...[
          _Conclusion(
            etiqueta: r.terminado ? 'Contra $nombreAnterior, completo' : 'Contra $nombreAnterior, a los ${r.diaDelCiclo} días',
            titulo: contra,
          ),
          _ContraAnterior(reporte: r),
        ],
        if (r.ultimosCiclos.length > 1) ...[
          _Conclusion(etiqueta: 'Últimos ciclos', titulo: ultimos),
          _UltimosCiclos(reporte: r),
        ],
        if (r.diasConDatos >= 7) ...[
          _Conclusion(etiqueta: 'Día de la semana · últimos 90 días', titulo: dia),
          _PorDiaSemana(reporte: r),
        ],
        if (r.dondeMasGastas.isNotEmpty) ...[
          _Conclusion(
            etiqueta: 'Dónde más gastas',
            titulo: '${r.dondeMasGastas.first.descripcion}: ${enPesos(r.dondeMasGastas.first.total)}',
          ),
          _DondeMasGastas(reporte: r),
        ],
        // Suscripciones y pagos periódicos de todo el historial (spec §5.7).
        if (datos.recurrentes.isNotEmpty) ...[
          _Conclusion(
            etiqueta: 'Lo que se repite',
            titulo: 'Suma ${enPesos(totalAlAnio([for (final x in datos.recurrentes) x.gasto]))} al año',
          ),
          TarjetaApp.lista(renglones: [
            for (final (:gasto, :emoji) in datos.recurrentes)
              RenglonApp(
                emoji: emoji,
                titulo: gasto.nombre,
                subtitulo: '${gasto.frecuencia.etiqueta} · próximo ${fechaCorta(gasto.proximo)}',
                monto: enPesos(gasto.monto),
                abajo: Text('${enPesos(gasto.alAnio)} al año', style: Theme.of(context).textTheme.etiqueta),
              ),
          ]),
        ],
        _Conclusion(etiqueta: 'Cómo pagas', titulo: pago),
        _TarjetaYEfectivo(reporte: r),
      ],
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

  /// "octubre": el mes del ciclo anterior, en minúsculas.
  String _mesAnterior(Ciclo ciclo) {
    const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final anterior = ciclo.fechaInicio.subtract(const Duration(days: 1));
    return meses[widget.perfil.calculadoraCiclo.calcularPara(anterior).fechaInicio.month - 1];
  }
}

String _mayuscula(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// La frase-conclusión arriba de cada gráfica de Detalle: una etiqueta
/// chica que dice qué es y un título que dice qué significa.
class _Conclusion extends StatelessWidget {
  final String etiqueta;
  final String titulo;

  const _Conclusion({required this.etiqueta, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
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

/// Divisoria discreta entre las categorías que juntas llegan al 80 % de lo
/// asignado y el resto (spec §5.7).
class _LineaPareto extends StatelessWidget {
  final CortePareto corte;

  const _LineaPareto(this.corte);

  @override
  Widget build(BuildContext context) {
    final linea = Expanded(child: Divider(color: ColoresApp.linea, height: 1));
    final texto = corte.cuantas == 1 ? 'Esta suma el ${corte.porcentaje}%' : 'Estas ${corte.cuantas} suman el ${corte.porcentaje}%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          linea,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('↑ $texto', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ColoresApp.medio)),
          ),
          linea,
        ],
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
    final pareto = calcularCortePareto([for (final f in filas) f.presupuesto]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('De ${total.formateado()} asignados a $tipo', style: textos.bodySmall),
        const SizedBox(height: 8),
        for (final (i, f) in filas.indexed) ...[
          // La línea del 80/20: arriba, las pocas que se llevan casi todo.
          if (pareto != null && i == pareto.cuantas) _LineaPareto(pareto),
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
        Text(
          datos.reporte.terminado
              ? 'De ${datos.ingreso.formateado()} que entraron ese ciclo'
              : 'De ${datos.ingreso.formateado()} que entran este ciclo',
          style: textos.bodySmall,
        ),
        const SizedBox(height: 12),
        _plan(context, reparto.plan),
        const SizedBox(height: 18),
        barra(datos.reporte.terminado ? 'Al cierre' : 'Hasta hoy', 'Real', EstiloReparto.real, reparto.hoy),
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
              descripcion: r.terminado
                  ? 'Gastaste ${r.gastadoVariables.formateado()} en variables de ${r.presupuestoVariables.formateado()}.'
                  : 'Llevas ${r.gastadoVariables.formateado()} en variables; '
                      'a ritmo parejo llevarías ${parejo.formateado()}.'
                  '${quedanDias ? ' Si sigues así, cerrarías en ${r.proyeccionVariables.formateado()}.' : ''}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Leyenda(color: ColoresApp.azul, texto: r.terminado ? 'Lo que gastaste' : 'Lo que llevas'),
                _Leyenda(color: ColoresApp.oro, texto: 'Ritmo parejo'),
                if (quedanDias)
                  _Leyenda(
                    color: colorPronostico(r.proyeccionVariables, r.presupuestoVariables),
                    texto: 'Pronóstico',
                  ),
              ],
            ),
            // "Vas $X arriba/abajo del ritmo parejo" ya es el título de la
            // tarjeta (frase-conclusión de Detalle): aquí solo el pronóstico.
            if (quedanDias) ...[
              const SizedBox(height: 4),
              Text(
                'Estimado al cierre: ${enPesos(r.proyeccionVariables)} de ${enPesos(r.presupuestoVariables)}.',
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
