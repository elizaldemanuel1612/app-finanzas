import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../../domain/rollups/rollup.dart';
import '../captura/pantalla_captura.dart';
import '../categorias/pantalla_categorias.dart';
import '../categorias/pantalla_detalle_categoria.dart';
import '../comun/barra_ritmo.dart';
import '../comun/tema.dart';
import '../gastos/pantalla_gastos.dart';

/// app-finanzas-mockup-v2.html §1, con rollups precalculados (Fase 2) y la
/// marca de ritmo en su versión simple — el motor de pronóstico completo
/// (domain/pronostico/) llega en la Fase 4.
class PantallaInicio extends StatefulWidget {
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final ReglasAprendidasRepositorio reglasAprendidasRepositorio;

  const PantallaInicio({
    super.key,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.reglasAprendidasRepositorio,
  });

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late Ciclo _ciclo;
  late double _avanceCiclo;
  late Future<_DatosInicio> _datos;

  @override
  void initState() {
    super.initState();
    _ciclo = CalculadoraCiclo(widget.perfil.diaCorte).calcularPara(DateTime.now());
    _avanceCiclo = avanceDelCiclo(
      fechaInicio: _ciclo.fechaInicio,
      fechaFin: _ciclo.fechaFin,
      ahora: DateTime.now(),
    );
    _cargar();
  }

  void _cargar() {
    _datos = _cargarDatos();
  }

  Future<_DatosInicio> _cargarDatos() async {
    final categorias = await widget.categoriaRepositorio.listarActivas();
    final movimientos = await widget.movimientoRepositorio.listarPorCiclo(_ciclo.id);
    final rollups = calcularRollups(
      movimientos: movimientos,
      categorias: categorias,
      cicloId: _ciclo.id,
    );
    final rollupPorCategoria = {for (final r in rollups) r.categoriaId: r};

    final fijas = categorias.whereType<CategoriaFija>().toList();
    final variables = categorias.whereType<CategoriaVariable>().toList()
      ..sort((a, b) {
        final ea = calcularEstadoRitmo(
          porcentajeUsado: rollupPorCategoria[a.id]?.porcentajeUsado,
          avanceCiclo: _avanceCiclo,
        );
        final eb = calcularEstadoRitmo(
          porcentajeUsado: rollupPorCategoria[b.id]?.porcentajeUsado,
          avanceCiclo: _avanceCiclo,
        );
        return eb.index.compareTo(ea.index); // pasado primero
      });

    final totalGastado = Dinero.suma(rollups.map((r) => r.totalCentavos));
    final disponibleParaInvertir = widget.perfil.ingresoBaseMensual - totalGastado;

    return _DatosInicio(
      categorias: categorias,
      rollupPorCategoria: rollupPorCategoria,
      fijas: fijas,
      variables: variables,
      totalGastado: totalGastado,
      disponibleParaInvertir: disponibleParaInvertir,
    );
  }

  Future<void> _irACaptura() async {
    // Object? en vez de Movimiento: el dictado por voz puede registrar
    // varios movimientos de golpe y regresa un sentinel (true), no un
    // único Movimiento — cualquier resultado no nulo dispara el refresco.
    final registrado = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => PantallaCaptura(
          perfil: widget.perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
        ),
      ),
    );
    if (registrado != null && mounted) setState(_cargar);
  }

  void _irAGastos() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaGastos(
          cicloId: _ciclo.id,
          perfil: widget.perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          reglasAprendidasRepositorio: widget.reglasAprendidasRepositorio,
        ),
      ),
    ).then((_) => setState(_cargar));
  }

  Future<void> _irACategorias() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCategorias(
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
        ),
      ),
    );
    if (mounted) setState(_cargar);
  }

  void _irADetalle(Categoria categoria) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalleCategoria(
          categoria: categoria,
          ciclo: _ciclo,
          avanceCiclo: _avanceCiclo,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
        ),
      ),
    ).then((_) => setState(_cargar));
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _irACaptura,
        backgroundColor: ColoresApp.violeta,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<_DatosInicio>(
        future: _datos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final datos = snapshot.data!;

          if (datos.categorias.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👋', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    const Text(
                      'Todavía no tienes categorías. Crea la primera para empezar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ColoresApp.medio),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _irACategorias, child: const Text('Ir a Categorías')),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ciclo del ${_fechaCorta(_ciclo.fechaInicio)} al ${_fechaCorta(_ciclo.fechaFin)}',
                          style: const TextStyle(color: ColoresApp.medio, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(datos.totalGastado.formateado(),
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w800, color: ColoresApp.tinta)),
                      const Text('gastado este ciclo', style: TextStyle(color: ColoresApp.medio)),
                    ],
                  ),
                ),
              ),
              if (datos.variables.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Dónde está la atención',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ColoresApp.tinta)),
                const SizedBox(height: 10),
                ...datos.variables.map((c) {
                  final rollup = datos.rollupPorCategoria[c.id];
                  final estado = calcularEstadoRitmo(
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
                                Row(children: [
                                  Text(c.emoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorEstadoRitmo(estado).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(etiquetaEstadoRitmo(estado),
                                      style: TextStyle(
                                          color: colorEstadoRitmo(estado),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            BarraRitmo(
                              porcentajeUsado: rollup?.porcentajeUsado ?? 0,
                              avanceCiclo: _avanceCiclo,
                              estado: estado,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(rollup?.totalCentavos ?? const Dinero.cero()).formateado()} de '
                                  '${c.presupuestoMensualCentavos.formateado()}',
                                  style: const TextStyle(fontSize: 12, color: ColoresApp.medio),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              if (datos.fijas.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Gastos fijos',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ColoresApp.tinta)),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: datos.fijas.map((c) {
                      final pagado = (datos.rollupPorCategoria[c.id]?.conteoMovimientos ?? 0) > 0;
                      return ListTile(
                        onTap: () => _irADetalle(c),
                        leading: Text(c.emoji, style: const TextStyle(fontSize: 18)),
                        title: Text(c.nombre),
                        subtitle: Text(pagado ? 'Pagado' : 'Pendiente'),
                        trailing: Text(c.montoFijoCentavos.formateado(),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Card(
                color: ColoresApp.tinta,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lo que importa de verdad',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(datos.disponibleParaInvertir.formateado(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('es lo que vas a poder invertir este ciclo si no gastas más.',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
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

class _DatosInicio {
  final List<Categoria> categorias;
  final Map<String, Rollup> rollupPorCategoria;
  final List<CategoriaFija> fijas;
  final List<CategoriaVariable> variables;
  final Dinero totalGastado;
  final Dinero disponibleParaInvertir;

  const _DatosInicio({
    required this.categorias,
    required this.rollupPorCategoria,
    required this.fijas,
    required this.variables,
    required this.totalGastado,
    required this.disponibleParaInvertir,
  });
}
