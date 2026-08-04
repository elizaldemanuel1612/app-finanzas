import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/presupuesto/plan_de_ajuste.dart';
import '../../domain/presupuesto/rebalanceo.dart';
import '../../domain/pronostico/pronostico_categoria.dart';
import '../../domain/pronostico/punto_monto.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../comun/barra_ritmo.dart';
import '../comun/tema.dart';
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

  const PantallaDetalleCategoria({
    super.key,
    required this.categoria,
    required this.ciclo,
    required this.avanceCiclo,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
  });

  @override
  State<PantallaDetalleCategoria> createState() => _PantallaDetalleCategoriaState();
}

class _PantallaDetalleCategoriaState extends State<PantallaDetalleCategoria> {
  late Future<_DatosDetalle> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<_DatosDetalle> _cargar() async {
    final todos = await widget.movimientoRepositorio.listarTodos();
    final movimientosCiclo = todos
        .where((m) =>
            m.categoriaId == widget.categoria.id &&
            m.estado == EstadoMovimiento.activo &&
            m.cicloId == widget.ciclo.id)
        .toList();

    PronosticoCategoria? pronostico;
    PlanDeAjuste? plan;
    Rebalanceo? rebalanceo;
    final categoria = widget.categoria;
    if (categoria is CategoriaVariable) {
      pronostico = _pronosticoPara(categoria, todos, widget.ciclo);

      plan = calcularPlanDeAjuste(
        categoria: categoria,
        pronostico: pronostico,
        ciclosCerradosRecienteAAntiguo: _ciclosCerrados(categoria.id, todos, widget.ciclo.id),
        fechaInicioCiclo: widget.ciclo.fechaInicio,
        fechaFinCiclo: widget.ciclo.fechaFin,
        hoy: DateTime.now(),
      );

      // El rebalanceo solo necesita mirar las demás categorías cuando el
      // plan de ajuste ya no alcanza (ya se pasó del presupuesto) — no
      // vale la pena calcular el pronóstico de todas las categorías en
      // cada visita si de entrada no aplica.
      if (pronostico.observado.centavos > categoria.presupuestoMensualCentavos.centavos) {
        final otrasCategorias =
            (await widget.categoriaRepositorio.listarActivas()).whereType<CategoriaVariable>().where(
                  (c) => c.id != categoria.id,
                );
        final otrosPronosticos = [
          for (final c in otrasCategorias) _pronosticoPara(c, todos, widget.ciclo),
        ];
        rebalanceo = calcularRebalanceo(
          categoriaObjetivo: categoria,
          pronosticoObjetivo: pronostico,
          otrasCategorias: otrasCategorias.toList(),
          otrosPronosticos: otrosPronosticos,
        );
      }
    }

    return _DatosDetalle(
      movimientos: movimientosCiclo,
      pronostico: pronostico,
      plan: plan,
      rebalanceo: rebalanceo,
    );
  }

  /// Aplica la categoría con más holgura de [rebalanceo.candidatas] hasta
  /// cubrir el faltante (o hasta agotar las 3, lo que ocurra primero) y
  /// persiste el resultado — "el usuario decide" (§2.5): esto solo corre
  /// cuando la persona toca el botón, nunca solo.
  Future<void> _aplicarRebalanceo(Rebalanceo rebalanceo) async {
    var faltanteCentavos = rebalanceo.faltante.centavos;
    final movimientos = <MovimientoRebalanceo>[];
    for (final candidata in rebalanceo.candidatas) {
      if (faltanteCentavos <= 0) break;
      final monto = faltanteCentavos < candidata.holgura.centavos
          ? Dinero(faltanteCentavos)
          : candidata.holgura;
      movimientos.add(MovimientoRebalanceo(categoriaOrigenId: candidata.categoria.id, monto: monto));
      faltanteCentavos -= monto.centavos;
    }
    if (movimientos.isEmpty) return;

    final resultado = aplicarRebalanceo(
      objetivo: widget.categoria as CategoriaVariable,
      origenes: [for (final c in rebalanceo.candidatas) c.categoria],
      movimientos: movimientos,
      cuando: DateTime.now(),
      dispositivo: 'app',
    );
    if (resultado case Falla(:final mensaje)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      }
      return;
    }
    final r = resultado.valorOLanza;
    await widget.categoriaRepositorio.guardar(r.objetivoActualizada);
    for (final origen in r.origenesActualizadas) {
      await widget.categoriaRepositorio.guardar(origen);
    }
    if (mounted) setState(() => _datos = _cargar());
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
                    categoriaExistente: widget.categoria,
                  ),
                ),
              );
              if (editada == true && context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: FutureBuilder<_DatosDetalle>(
        future: _datos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final movimientos = snapshot.data!.movimientos;
          final pronostico = snapshot.data!.pronostico;
          final plan = snapshot.data!.plan;
          final rebalanceo = snapshot.data!.rebalanceo;
          final rollup = calcularRollups(
            movimientos: movimientos,
            categorias: [widget.categoria],
            cicloId: widget.ciclo.id,
          ).single;
          final estado = calcularEstadoRitmo(
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
                          Text(rollup.totalCentavos.formateado(),
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, color: ColoresApp.tinta)),
                          if (rollup.presupuestoCentavos != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorEstadoRitmo(estado).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                etiquetaEstadoRitmo(estado),
                                style: TextStyle(
                                    color: colorEstadoRitmo(estado), fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      if (rollup.presupuestoCentavos != null) ...[
                        Text(
                          'de ${rollup.presupuestoCentavos!.formateado()}'
                          '${widget.categoria is CategoriaFija ? '' : ' este ciclo'}',
                          style: const TextStyle(color: ColoresApp.medio),
                        ),
                        const SizedBox(height: 16),
                        BarraRitmo(
                          porcentajeUsado: rollup.porcentajeUsado ?? 0,
                          avanceCiclo: widget.avanceCiclo,
                          estado: estado,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text('${rollup.conteoMovimientos} movimiento(s) en el ciclo',
                          style: const TextStyle(color: ColoresApp.medio, fontSize: 12)),
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
                  onAplicar: () => _aplicarRebalanceo(rebalanceo),
                ),
              ],
              const SizedBox(height: 20),
              if (movimientos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('Nada en esta categoría todavía.',
                        style: TextStyle(color: ColoresApp.medio)),
                  ),
                )
              else
                ...(movimientos..sort((a, b) => b.fecha.compareTo(a.fecha))).map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(m.descripcion),
                        subtitle: Text('${_fechaCorta(m.fecha)} · ${m.medio.name}'),
                        trailing: Text(m.monto.formateado(),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    )),
            ],
          );
        },
      ),
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

  const _DatosDetalle({
    required this.movimientos,
    required this.pronostico,
    required this.plan,
    required this.rebalanceo,
  });
}

/// Ciclos cerrados de [categoriaId] a partir de todos los movimientos —
/// cualquier `cicloId` distinto al del ciclo que se está viendo (ver nota
/// de clase sobre "ciclo cerrado" al inicio del archivo).
List<List<PuntoMonto>> _ciclosCerrados(String categoriaId, List<Movimiento> todos, String cicloActualId) {
  final porCiclo = <String, List<Movimiento>>{};
  for (final m in todos) {
    if (m.categoriaId != categoriaId) continue;
    if (m.estado != EstadoMovimiento.activo) continue;
    if (m.cicloId == cicloActualId) continue;
    porCiclo.putIfAbsent(m.cicloId, () => []).add(m);
  }
  final cicloIdsOrdenados = porCiclo.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final id in cicloIdsOrdenados)
      [for (final m in porCiclo[id]!) PuntoMonto(m.fecha, m.monto.centavos.toDouble())],
  ];
}

/// Pronóstico MPC de una categoría cualquiera a partir de todos los
/// movimientos — la misma llamada que arma la tarjeta de "cierre
/// estimado" de la categoría que se está viendo, reutilizada para las
/// candidatas de rebalanceo.
PronosticoCategoria _pronosticoPara(Categoria categoria, List<Movimiento> todos, Ciclo ciclo) {
  final movimientosCiclo = todos
      .where((m) => m.categoriaId == categoria.id && m.estado == EstadoMovimiento.activo && m.cicloId == ciclo.id)
      .toList();
  return calcularPronosticoCategoria(
    categoria: categoria,
    cicloId: ciclo.id,
    fechaInicioCiclo: ciclo.fechaInicio,
    fechaFinCiclo: ciclo.fechaFin,
    hoy: DateTime.now(),
    movimientosCicloActual: [
      for (final m in movimientosCiclo) PuntoMonto(m.fecha, m.monto.centavos.toDouble()),
    ],
    ciclosCerradosRecienteAAntiguo: _ciclosCerrados(categoria.id, todos, ciclo.id),
  );
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
      color: ColoresApp.violetaSuave,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cierre estimado',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.violeta)),
                _EtiquetaConfianza(confianza: pronostico.confianza),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pronostico.pronosticoP50.formateado(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ColoresApp.tinta),
            ),
            Text(
              'rango ${pronostico.pronosticoP10.formateado()} – ${pronostico.pronosticoP90.formateado()}',
              style: const TextStyle(color: ColoresApp.medio, fontSize: 12),
            ),
            for (final texto in pronostico.explicacion) ...[
              const SizedBox(height: 8),
              Text(texto, style: const TextStyle(color: ColoresApp.medio, fontSize: 11)),
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
            const Text('Plan de ajuste',
                style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.tinta)),
            const SizedBox(height: 8),
            Text(plan.piezaCuantoQueda, style: const TextStyle(color: ColoresApp.medio, fontSize: 13)),
            Text(plan.piezaContraCostumbre, style: const TextStyle(color: ColoresApp.medio, fontSize: 13)),
            const SizedBox(height: 6),
            Text(plan.piezaNumeroASeguir,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ColoresApp.tinta)),
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
            const Text('Rebalanceo sugerido',
                style: TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.tinta)),
            const SizedBox(height: 6),
            Text('Ya se pasó del presupuesto y falta ${rebalanceo.faltante.formateado()} este ciclo.',
                style: const TextStyle(color: ColoresApp.medio, fontSize: 13)),
            const SizedBox(height: 10),
            const Text('Categorías con holgura para mover:',
                style: TextStyle(color: ColoresApp.medio, fontSize: 12, fontWeight: FontWeight.w600)),
            for (final c in rebalanceo.candidatas)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${c.categoria.emoji} ${c.categoria.nombre}',
                        style: const TextStyle(fontSize: 13)),
                    Text(c.holgura.formateado(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onAplicar, child: const Text('Mover presupuesto')),
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
    final (texto, color) = switch (confianza) {
      ConfianzaMpc.alta => ('confianza alta', ColoresApp.verde),
      ConfianzaMpc.media => ('confianza media', ColoresApp.ambar),
      ConfianzaMpc.baja => ('confianza baja', ColoresApp.coral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
      child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}
