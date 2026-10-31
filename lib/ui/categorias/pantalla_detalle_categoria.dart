import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/plan_de_ajuste.dart';
import '../../domain/presupuesto/rebalanceo.dart';
import '../../domain/pronostico/historico_desde_movimientos.dart';
import '../../domain/pronostico/pronostico_categoria.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../captura/pantalla_captura.dart';
import '../comun/asegurar_ciclo_abierto.dart';
import '../comun/barra_ritmo.dart';
import '../comun/formato_dinero.dart';
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

      // El rebalanceo solo necesita mirar las demás categorías cuando el
      // plan de ajuste ya no alcanza (ya se pasó del presupuesto) — no
      // vale la pena calcular el pronóstico de todas las categorías en
      // cada visita si de entrada no aplica.
      if (pronostico.observado.centavos >
          categoriaEfectiva.presupuestoMensualCentavos.centavos) {
        final otrasCategoriasBase =
            (await widget.categoriaRepositorio.listarActivas())
                .where((c) => c.id != categoriaEfectiva.id)
                .toList();
        // Pasan también por el ajuste del ciclo: una categoría que ya
        // prestó presupuesto en un rebalanceo anterior de este mismo
        // ciclo debe aparecer con menos holgura en el siguiente — los
        // ajustes se acumulan, nunca se reemplazan (§2.5).
        final otrasCategorias = presupuestosEfectivosParaCiclo(
          base: otrasCategoriasBase,
          ajustesDelCiclo: ajustes,
        ).whereType<CategoriaVariable>().toList();
        final otrosPronosticos = [
          for (final c in otrasCategorias)
            pronosticoDeCategoria(
              categoria: c,
              todos: todos,
              ciclo: widget.ciclo,
              hoy: hoy,
            ),
        ];
        rebalanceo = calcularRebalanceo(
          categoriaObjetivo: categoriaEfectiva,
          pronosticoObjetivo: pronostico,
          otrasCategorias: otrasCategorias,
          otrosPronosticos: otrosPronosticos,
        );
      }
    }

    return _DatosDetalle(
      movimientos: movimientosCiclo,
      pronostico: pronostico,
      plan: plan,
      rebalanceo: rebalanceo,
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

  Widget _buildContenido(_DatosDetalle datos) {
    final movimientos = datos.movimientos;
    final pronostico = datos.pronostico;
    final plan = datos.plan;
    final rebalanceo = datos.rebalanceo;
    final rollup = calcularRollups(
      movimientos: movimientos,
      categorias: [datos.categoriaEfectiva],
      cicloId: widget.ciclo.id,
    ).single;
    // Una fija no tiene "presupuesto" que se pueda exceder — tiene un
    // monto conocido que se paga o no (spec-app-finanzas-v2.md §1.5:
    // "Barra de ritmo: No aplica" / "Estado: Pagado / pendiente" para
    // fijas). El chip de ritmo (Vas bien/Justo/Excedido) y la barra son
    // solo para variables; `pantalla_inicio.dart` ya sigue esta regla en
    // su lista de "Gastos fijos" — aquí faltaba aplicarla también.
    final esFija = widget.categoria is CategoriaFija;
    final pagado = rollup.conteoMovimientos > 0;
    final estado = calcularEstadoRitmo(porcentajeUsado: rollup.porcentajeUsado);
    final vaRapido = vaMuyRapido(
      porcentajeUsado: rollup.porcentajeUsado,
      avanceCiclo: widget.avanceCiclo,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      rollup.totalCentavos.formateado(),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.tinta,
                      ),
                    ),
                    if (rollup.presupuestoCentavos != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (esFija
                                  ? (pagado ? ColoresApp.verde : ColoresApp.medio)
                                  : colorEstadoRitmo(estado))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          esFija
                              ? (pagado ? 'Pagado' : 'Pendiente')
                              : etiquetaEstadoRitmo(estado),
                          style: TextStyle(
                            color: esFija
                                ? (pagado ? ColoresApp.verdeTexto : ColoresApp.medio)
                                : colorTextoEstadoRitmo(estado),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (rollup.presupuestoCentavos != null) ...[
                  Text(
                    'de ${rollup.presupuestoCentavos!.formateado()}'
                    '${esFija ? '' : ' este ciclo'}',
                    style: TextStyle(color: ColoresApp.medio),
                  ),
                  if (datos.deltaCategoria != null &&
                      !datos.deltaCategoria!.esCero)
                    Text(
                      'ajustado por ${signoYMonto(datos.deltaCategoria!)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  if (!esFija) ...[
                    const SizedBox(height: 16),
                    BarraRitmo(
                      porcentajeUsado: rollup.porcentajeUsado ?? 0,
                      avanceCiclo: widget.avanceCiclo,
                      estado: estado,
                      descripcion: widget.categoria.nombre,
                      vaMuyRapido: vaRapido,
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Text(
                  '${rollup.conteoMovimientos} movimiento(s) en el ciclo',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        if (pronostico != null) ...[
          const SizedBox(height: 12),
          _TarjetaPronostico(pronostico: pronostico),
        ],
        if (plan != null) ...[
          const SizedBox(height: 12),
          _TarjetaPlanDeAjuste(plan: plan),
        ],
        if (rebalanceo != null && rebalanceo.candidatas.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TarjetaRebalanceo(
            rebalanceo: rebalanceo,
            onAplicar: () => _abrirMoverPresupuesto(rebalanceo),
          ),
        ],
        const SizedBox(height: 20),
        if (movimientos.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Nada en esta categoría todavía.',
                style: TextStyle(color: ColoresApp.medio),
              ),
            ),
          )
        else
          ...(movimientos..sort((a, b) => b.fecha.compareTo(a.fecha))).map(
            (m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _editar(m),
                title: Text(m.descripcion),
                subtitle: Text('${_fechaCorta(m.fecha)} · ${m.medio.name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.monto.formateado(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: ColoresApp.medio, semanticLabel: 'Editar'),
                  ],
                ),
              ),
            ),
          ),
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
  final Categoria categoriaEfectiva;
  final Dinero? deltaCategoria;

  const _DatosDetalle({
    required this.movimientos,
    required this.pronostico,
    required this.plan,
    required this.rebalanceo,
    required this.categoriaEfectiva,
    required this.deltaCategoria,
  });
}

/// Presentación de §6 del MPC: "Súper/Comida — cierre estimado $9,200
/// (rango $7,800 – $11,400)". El mensaje del nivel de madurez (§7) se
/// muestra como advertencia mientras el modelo no llegue a "completo".
class _TarjetaPronostico extends StatelessWidget {
  final PronosticoCategoria pronostico;

  const _TarjetaPronostico({required this.pronostico});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColoresApp.azulSuave,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cierre estimado',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.azul,
                  ),
                ),
                _EtiquetaConfianza(confianza: pronostico.confianza),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pronostico.pronosticoP50.formateado(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ColoresApp.tinta,
              ),
            ),
            Text(
              'rango ${pronostico.pronosticoP10.formateado()} – ${pronostico.pronosticoP90.formateado()}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            for (final texto in pronostico.explicacion) ...[
              const SizedBox(height: 8),
              Text(
                texto,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Las tres piezas fijas de addendum-v3-ajuste-y-ux.md §2.3, en su orden:
/// cuánto queda, contra tu costumbre, el número a seguir. Nunca un
/// porcentaje de recorte solo.
class _TarjetaPlanDeAjuste extends StatelessWidget {
  final PlanDeAjuste plan;

  const _TarjetaPlanDeAjuste({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColoresApp.ambarSuave,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan de ajuste',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ColoresApp.tinta,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plan.piezaCuantoQueda,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              plan.piezaContraCostumbre,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              plan.piezaNumeroASeguir,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// addendum-v3-ajuste-y-ux.md §2.5: cuando la categoría ya se pasó del
/// presupuesto y el Plan de Ajuste ya no alcanza, ofrece mover
/// presupuesto desde las 3 categorías con más holgura proyectada. El
/// usuario decide — nunca se rebalancea solo.
class _TarjetaRebalanceo extends StatelessWidget {
  final Rebalanceo rebalanceo;
  final VoidCallback onAplicar;

  const _TarjetaRebalanceo({required this.rebalanceo, required this.onAplicar});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColoresApp.coralSuave,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rebalanceo sugerido',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ColoresApp.tinta,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ya se pasó del presupuesto y falta ${rebalanceo.faltante.formateado()} este ciclo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Categorías con holgura para mover:',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            for (final c in rebalanceo.candidatas)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${c.categoria.emoji} ${c.categoria.nombre}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      c.holgura.formateado(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onAplicar,
              child: const Text('Mover presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaConfianza extends StatelessWidget {
  final ConfianzaMpc confianza;

  const _EtiquetaConfianza({required this.confianza});

  @override
  Widget build(BuildContext context) {
    final (texto, color, colorTexto) = switch (confianza) {
      ConfianzaMpc.alta => ('confianza alta', ColoresApp.verde, ColoresApp.verdeTexto),
      ConfianzaMpc.media => ('confianza media', ColoresApp.ambar, ColoresApp.ambarTexto),
      ConfianzaMpc.baja => ('confianza baja', ColoresApp.coral, ColoresApp.coralTexto),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // El fondo se queda con el color brillante (elemento gráfico,
        // umbral 3:1); el texto usa la variante oscurecida (umbral 4.5:1).
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: colorTexto,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
