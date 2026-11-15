import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/result.dart';

import '../../domain/voz/monto_hablado.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/cuenta_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/plan_de_ajuste.dart';
import '../../domain/presupuesto/cobertura_excesos.dart';
import '../../domain/presupuesto/rebalanceo.dart';
import '../../domain/pronostico/historico_desde_movimientos.dart';
import '../../domain/pronostico/pronostico_categoria.dart';
import '../../domain/pronostico/pronostico_del_ciclo.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../captura/pantalla_captura.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/barra_ritmo.dart';
import '../comun/formato_dinero.dart';
import '../comun/tarjeta_app.dart';
import '../comun/renglon_app.dart';
import '../comun/chip_estado.dart';
import '../comun/aviso.dart';
import '../comun/tema.dart';
import 'pantalla_mover_presupuesto.dart';
import 'pantalla_nueva_categoria.dart';

/// app-finanzas-gastos-v3.html §4 — "aquí vive el pronóstico". El motor
/// completo (modelo-pronostico-ciclo.md) vive en domain/pronostico/; aquí
/// solo se arman sus insumos a partir de los movimientos guardados y se
/// muestra la salida (§6: rango, no número único).
///
/// "Ciclo cerrado" todavía no existe como estado gestionado (llega en la
/// Fase 5, cierre de ciclo) — mientras tanto, cualquier `cicloId` distinto
/// al del ciclo que se está viendo se trata como histórico cerrado para
/// el pronóstico. Es una aproximación razonable hoy: no hay forma de que
/// un ciclo pasado siga "abierto" en la práctica.
class PantallaDetalleCategoria extends StatefulWidget {
  final Categoria categoria;
  final Ciclo ciclo;
  final double avanceCiclo;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;
  final AjustePresupuestoCicloRepositorio ajustePresupuestoCicloRepositorio;
  final CicloRepositorio cicloRepositorio;

  /// Para abrir la edición de un gasto (ver `PantallaCaptura.documentos`).
  final Perfil perfil;
  final Directory documentos;
  final CuentaRepositorio? cuentaRepositorio;

  const PantallaDetalleCategoria({
    super.key,
    required this.categoria,
    required this.ciclo,
    required this.avanceCiclo,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
    required this.ajustePresupuestoCicloRepositorio,
    required this.cicloRepositorio,
    required this.perfil,
    required this.documentos,
    this.cuentaRepositorio,
  });

  @override
  State<PantallaDetalleCategoria> createState() =>
      _PantallaDetalleCategoriaState();
}

class _PantallaDetalleCategoriaState extends State<PantallaDetalleCategoria> {
  _DatosDetalle? _datos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// La misma edición que abre "Gastos". Si se reasigna a otra categoría, al
  /// recargar el gasto deja de aparecer aquí.
  Future<void> _editar(Movimiento m) async {
    final puedeModificar = await asegurarCicloAbierto(
      context,
      cicloId: m.cicloId,
      cicloRepositorio: widget.cicloRepositorio,
    );
    if (!puedeModificar || !mounted) return;
    final editado = await Navigator.of(context).push<Movimiento>(
      MaterialPageRoute(
        builder: (_) => PantallaCaptura(
          perfil: widget.perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          documentos: widget.documentos,
          paraEditar: m,
          cuentaRepositorio: widget.cuentaRepositorio,
        ),
      ),
    );
    if (editado != null) await _cargar();
  }

  Future<void> _cargar() async {
    final datos = await _cargarDatos();
    if (!mounted) return;
    setState(() => _datos = datos);
  }

  Future<_DatosDetalle> _cargarDatos() async {
    final todos = await widget.movimientoRepositorio.listarTodos();
    final movimientosCiclo = todos
        .where(
          (m) =>
              m.categoriaId == widget.categoria.id &&
              m.estado == EstadoMovimiento.activo &&
              m.cicloId == widget.ciclo.id,
        )
        .toList();

    final ajustes = await widget.ajustePresupuestoCicloRepositorio
        .listarPorCiclo(widget.ciclo.id);
    final deltaCategoria =
        sumarDeltasPorCategoria(ajustes)[widget.categoria.id];
    final categoriaEfectiva = presupuestosEfectivosParaCiclo(
      base: [widget.categoria],
      ajustesDelCiclo: ajustes,
    ).single;

    PronosticoCategoria? pronostico;
    PlanDeAjuste? plan;
    Rebalanceo? rebalanceo;
    Cobertura? cobertura;
    final hoy = DateTime.now();
    if (categoriaEfectiva is CategoriaVariable) {
      pronostico = pronosticoDeCategoria(
        categoria: categoriaEfectiva,
        todos: todos,
        ciclo: widget.ciclo,
        hoy: hoy,
      );

      plan = calcularPlanDeAjuste(
        categoria: categoriaEfectiva,
        pronostico: pronostico,
        ciclosCerradosRecienteAAntiguo: ciclosCerradosDeCategoria(
          todos: todos,
          categoriaId: categoriaEfectiva.id,
          cicloActualId: widget.ciclo.id,
        ),
        fechaInicioCiclo: widget.ciclo.fechaInicio,
        fechaFinCiclo: widget.ciclo.fechaFin,
        hoy: hoy,
      );

      // Solo si ya se pasó: entonces mira todas las variables con el mismo
      // pronóstico (MPC) y el mismo motor de cobertura que Inicio y Análisis
      // (docs/rediseno/plan-rediseno.md, Etapa 0: una sola recomendación).
      if (pronostico.observado.centavos >
          categoriaEfectiva.presupuestoMensualCentavos.centavos) {
        // Pasan también por el ajuste del ciclo: una categoría que ya
        // prestó presupuesto en un rebalanceo anterior de este mismo
        // ciclo debe aparecer con menos holgura en el siguiente — los
        // ajustes se acumulan, nunca se reemplazan (§2.5).
        final otrasBase = (await widget.categoriaRepositorio.listarActivas())
            .where((c) => c.id != categoriaEfectiva.id)
            .toList();
        final estados = estadosDeVariables(
          categorias: [
            categoriaEfectiva,
            ...presupuestosEfectivosParaCiclo(base: otrasBase, ajustesDelCiclo: ajustes),
          ],
          movimientos: todos,
          ciclo: widget.ciclo,
          hoy: hoy,
        );
        final propio = estados.firstWhere((e) => e.categoria.id == categoriaEfectiva.id);
        rebalanceo = calcularRebalanceo(objetivo: propio, otras: estados);
        cobertura = calcularCoberturas(estados)
            .where((c) => c.categoria.id == categoriaEfectiva.id)
            .firstOrNull;
      }
    }

    return _DatosDetalle(
      movimientos: movimientosCiclo,
      pronostico: pronostico,
      plan: plan,
      rebalanceo: rebalanceo,
      cobertura: cobertura,
      categoriaEfectiva: categoriaEfectiva,
      deltaCategoria: deltaCategoria,
    );
  }

  /// Abre la pantalla donde el usuario decide, candidata por candidata,
  /// cuánto mover — "el usuario decide" (§2.5): esto solo corre cuando la
  /// persona toca el botón, nunca solo. El resultado es temporal (solo
  /// para este ciclo), por eso recarga en vez de guardar una categoría.
  Future<void> _abrirMoverPresupuesto(Rebalanceo rebalanceo) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaMoverPresupuesto(
          rebalanceo: rebalanceo,
          ciclo: widget.ciclo,
          ajustePresupuestoCicloRepositorio:
              widget.ajustePresupuestoCicloRepositorio,
        ),
      ),
    );
    if (guardado == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoria.emoji} ${widget.categoria.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar categoría',
            onPressed: () async {
              final editada = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PantallaNuevaCategoria(
                    categoriaRepositorio: widget.categoriaRepositorio,
                    movimientoRepositorio: widget.movimientoRepositorio,
                    reglasAprendidasRepositorio:
                        widget.reglasAprendidasRepositorio,
                    cicloRepositorio: widget.cicloRepositorio,
                    categoriaExistente: widget.categoria,
                  ),
                ),
              );
              if (editada == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: _datos == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContenido(_datos!),
    );
  }

  /// La acción primaria de una categoría que se pasó: mover desde la
  /// categoría que propone `calcularCoberturas` (la misma de Inicio y
  /// Análisis). Confirma porque cambia el presupuesto del ciclo.
  Future<void> _moverCobertura(Cobertura c, Rebalanceo rebalanceo) async {
    final origen = c.origen!;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Mover ${enPesos(c.cubre)} desde ${origen.nombre}?'),
        content: Text('Solo para este ciclo. A ${origen.nombre} le quedarán ${enPesos(c.sobranteDespues)} de sobra.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(contexto).pop(true), child: Text('Mover ${enPesos(c.cubre)}')),
        ],
      ),
    );
    if (confirmado != true) return;
    final resultado = construirAjustesDeRebalanceo(
      rebalanceo: rebalanceo,
      movimientos: [MovimientoRebalanceo(categoriaOrigenId: origen.id, monto: c.cubre)],
      cicloId: widget.ciclo.id,
      cuando: DateTime.now(),
      dispositivo: 'app',
    );
    switch (resultado) {
      case Exito(:final valor):
        await widget.ajustePresupuestoCicloRepositorio.agregarLote(valor);
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Listo, moviste ${enPesos(c.cubre)} desde ${origen.nombre}')),
          );
        }
      case Falla():
        // La candidata ya no alcanza (otro movimiento la usó): que el
        // usuario elija en la pantalla completa.
        await _abrirMoverPresupuesto(rebalanceo);
    }
  }

  Widget _buildContenido(_DatosDetalle datos) {
    final p = ColoresApp.actual;
    final textos = Theme.of(context).textTheme;
    final movimientos = [...datos.movimientos]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final pronostico = datos.pronostico;
    final plan = datos.plan;
    final rebalanceo = datos.rebalanceo;
    final cobertura = datos.cobertura;
    final rollup = calcularRollups(
      movimientos: movimientos,
      categorias: [datos.categoriaEfectiva],
      cicloId: widget.ciclo.id,
    ).single;
    // Una fija no tiene "presupuesto" que se pueda exceder: se paga o no
    // (spec-app-finanzas-v2.md §1.5). Sin barra ni chip de ritmo.
    final esFija = widget.categoria is CategoriaFija;
    final gastado = rollup.totalCentavos;
    final presupuesto = rollup.presupuestoCentavos;
    final quedan = presupuesto == null ? null : presupuesto - gastado;
    final pasada = quedan != null && quedan.esNegativo;
    final tono = tonoDeRitmo(porcentajeUsado: rollup.porcentajeUsado, avanceCiclo: widget.avanceCiclo);
    final pagado = rollup.conteoMovimientos > 0;

    final chip = esFija
        ? (pagado
            ? const ChipEstado(tono: TonoEstado.exito, texto: 'Pagado')
            : const ChipEstado(tono: TonoEstado.neutro, texto: 'Por pagar', icono: Icons.calendar_today_rounded))
        : ChipEstado.ritmo(tono);
    final etiquetaCifra = esFija
        ? (pagado ? 'Pagaste' : 'Monto fijo')
        : pasada
            ? 'Te pasaste por'
            : 'Te quedan';
    final cifra = esFija ? (pagado ? gastado : presupuesto ?? gastado) : (quedan == null ? gastado : quedan.absoluto);
    final (pesos, centavos) = partesDeMonto(cifra);

    Widget dato(String etiqueta, String valor) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(etiqueta, style: textos.etiqueta), Text(valor, style: textos.cuerpoFuerte)],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        TarjetaApp(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chip,
              const SizedBox(height: 14),
              Text(etiquetaCifra, style: textos.etiqueta),
              Semantics(
                label: '$etiquetaCifra ${montoEnPalabras(cifra)}',
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: pesos),
                    TextSpan(text: centavos, style: textos.seccion.copyWith(color: p.texto2)),
                  ]),
                  style: textos.cifraHeroe.copyWith(color: pasada ? p.peligroTexto : p.texto),
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
                ),
              ),
              if (!esFija && presupuesto != null) ...[
                const SizedBox(height: 14),
                BarraRitmo(
                  porcentajeUsado: rollup.porcentajeUsado ?? 0,
                  avanceCiclo: widget.avanceCiclo,
                  descripcion: widget.categoria.nombre,
                  gastado: gastado,
                  presupuesto: presupuesto,
                  grande: true,
                ),
                const SizedBox(height: 6),
                Text('${enPesos(gastado)} de ${enPesos(presupuesto)}', style: textos.etiqueta),
              ],
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
              Row(
                children: [
                  dato(esFija ? 'Monto' : 'Presupuesto', presupuesto == null ? '—' : enPesos(presupuesto)),
                  dato('Gastado', enPesos(gastado)),
                  if (pronostico != null)
                    dato(
                      'Al cierre',
                      // El MPC con poca historia es preliminar: se dice
                      // "estimado" con una tilde, no "confianza baja".
                      pronostico.confianza == ConfianzaMpc.alta
                          ? enPesos(pronostico.pronosticoP50)
                          : '~${enPesos(pronostico.pronosticoP50)}',
                    )
                  else
                    dato('Gastos', '${rollup.conteoMovimientos}'),
                ],
              ),
              if (datos.deltaCategoria != null && !datos.deltaCategoria!.esCero) ...[
                const SizedBox(height: 10),
                Text('Este ciclo, ajustado por ${signoYMonto(datos.deltaCategoria!)}', style: textos.etiqueta),
              ],
            ],
          ),
        ),
        if (cobertura != null) ...[
          const SizedBox(height: 12),
          TarjetaApp(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.superficieHundida, shape: BoxShape.circle),
                      child: cobertura.origen == null
                          ? Icon(Icons.savings_outlined, color: p.texto)
                          : Text(cobertura.origen!.emoji, style: textos.seccion, textScaler: TextScaler.noScaling),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cobertura.origen == null ? 'Sale de lo que apartas' : 'Cúbrelo con ${cobertura.origen!.nombre}',
                            style: textos.cuerpoFuerte,
                          ),
                          Text(
                            cobertura.origen == null
                                ? 'Ninguna categoría tiene de dónde.'
                                : cobertura.falta.esPositivo
                                    ? 'Alcanza para ${enPesos(cobertura.cubre)}; el resto sale de lo que apartas.'
                                    : 'A ${cobertura.origen!.nombre} le sobrarán ${enPesos(cobertura.sobranteDespues)}',
                            style: textos.etiqueta,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (cobertura.origen != null && rebalanceo != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _moverCobertura(cobertura, rebalanceo),
                    child: Text('Mover ${enPesos(cobertura.cubre)} desde ${cobertura.origen!.nombre}'),
                  ),
                ],
                if (rebalanceo != null && rebalanceo.candidatas.isNotEmpty)
                  TextButton(
                    onPressed: () => _abrirMoverPresupuesto(rebalanceo),
                    child: const Text('Elegir otra categoría'),
                  ),
              ],
            ),
          ),
        ] else if (plan != null) ...[
          const SizedBox(height: 12),
          Aviso(tono: TonoEstado.atencion, titulo: plan.piezaNumeroASeguir, apoyo: plan.piezaCuantoQueda),
        ],
        EncabezadoSeccion(
          titulo: '${movimientos.length} ${movimientos.length == 1 ? 'gasto' : 'gastos'}',
          dato: 'Este ciclo',
        ),
        if (movimientos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Nada en esta categoría todavía.', textAlign: TextAlign.center, style: textos.etiqueta),
          )
        else
          TarjetaApp.lista(renglones: [
            for (final m in movimientos)
              RenglonApp(
                titulo: m.descripcion,
                subtitulo: _fechaCorta(m.fecha),
                monto: m.monto.formateado(),
                onTap: () => _editar(m),
              ),
          ]),
      ],
    );
  }
}

String _fechaCorta(DateTime f) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${f.day} ${meses[f.month - 1]}';
}

class _DatosDetalle {
  final List<Movimiento> movimientos;
  final PronosticoCategoria? pronostico;
  final PlanDeAjuste? plan;
  final Rebalanceo? rebalanceo;

  /// La salida de "te pasaste": la misma que Inicio y Análisis.
  final Cobertura? cobertura;
  final Categoria categoriaEfectiva;
  final Dinero? deltaCategoria;

  const _DatosDetalle({
    required this.movimientos,
    required this.pronostico,
    required this.plan,
    required this.rebalanceo,
    required this.cobertura,
    required this.categoriaEfectiva,
    required this.deltaCategoria,
  });
}

