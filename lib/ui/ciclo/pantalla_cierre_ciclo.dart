import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/result.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/ciclo_de_vida/alcance.dart';
import '../../domain/ciclo_de_vida/cierre_ciclo.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/modelos/ciclo_guardado.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/modelos/snapshot_ciclo.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../comun/barra_ritmo.dart';
import '../comun/formato_fecha.dart';
import '../comun/tema.dart';

/// Cierre de ciclo (app-finanzas-fijos-cierre-v6.html §5): lo primero que
/// se ve no es cuánto gastaste, es qué tanto lograste.
///
/// `metaBase` sale de [calcularMetaBase]: la meta declarada en
/// `Perfil.metaApartado` si existe, o `ResultadoReparto.sinAsignar` (lo que
/// queda del ingreso después de fijas y presupuesto variable, "lo que vas a
/// poder invertir" del addendum-v3) si no. El ingreso extra se suma vía
/// `calcularIngresosDelCiclo`/`calcularMetaDelCiclo` (ingresos_ciclo.dart).
///
/// **Importante:** la rama de ciclo ya cerrado (con snapshot) **no
/// consulta [ingresoExtraRepositorio]** — el snapshot es la fotografía
/// congelada, y leer el repo vivo de extras ahí haría que registrar un
/// ingreso después cambiara las cifras de un ciclo ya cerrado (regla no
/// negociable #6). Si esto se "simplifica" moviendo la carga de extras
/// arriba del `if` en [_cargarDatos], ese descuadre no lo atrapa ninguna
/// prueba de dominio — solo este comentario.
class PantallaCierreCiclo extends StatefulWidget {
  final Ciclo ciclo;
  final Perfil perfil;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final CicloRepositorio cicloRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;

  const PantallaCierreCiclo({
    super.key,
    required this.ciclo,
    required this.perfil,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.cicloRepositorio,
    required this.ingresoExtraRepositorio,
  });

  @override
  State<PantallaCierreCiclo> createState() => _PantallaCierreCicloState();
}

class _PantallaCierreCicloState extends State<PantallaCierreCiclo> {
  late Future<_DatosCierre> _datos;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() => _datos = _cargarDatos();

  Future<_DatosCierre> _cargarDatos() async {
    final guardado = await widget.cicloRepositorio.buscarPorId(widget.ciclo.id);

    // Cerrado y con snapshot: la vista es de solo lectura sobre la
    // fotografía congelada — nunca se recalcula (spec-app-finanzas-v2.md
    // §2.2).
    final snapshotGuardado = guardado?.snapshot;
    if (guardado != null &&
        guardado.ciclo.estado == EstadoCiclo.cerrado &&
        snapshotGuardado != null) {
      return _DatosCierre(
        ciclo: guardado.ciclo,
        cicloGuardado: guardado,
        snapshot: snapshotGuardado,
      );
    }

    var cicloVigente = guardado?.ciclo ?? widget.ciclo;
    if (cicloVigente.estado == EstadoCiclo.cerrado) {
      // Cerrado sin snapshot es un estado inconsistente (no debería
      // ocurrir con el flujo actual de cierre/reapertura, pero puede
      // quedar de datos viejos): no hay nada congelado que proteger, así
      // que se trata como abierto para poder calcular una vista en vivo
      // en vez de dejar la pantalla en un callejón sin salida ("el ciclo
      // ya está cerrado" sin datos ni botón de recuperación).
      final reabierto = cicloVigente.reabrir();
      if (reabierto is Exito<Ciclo>) cicloVigente = reabierto.valor;
    }
    final categorias = await widget.categoriaRepositorio.listarTodas();
    final movimientos = await widget.movimientoRepositorio.listarPorCiclo(cicloVigente.id);
    final extras = await widget.ingresoExtraRepositorio.listarPorCiclo(cicloVigente.id);

    final metaBase = calcularMetaBase(perfil: widget.perfil, categorias: categorias);
    final ingresos = calcularIngresosDelCiclo(
      ingresoBase: widget.perfil.ingresoBaseMensual,
      cicloId: cicloVigente.id,
      extras: extras,
    );

    final resultado = calcularSnapshotCierre(
      ciclo: cicloVigente,
      movimientos: movimientos,
      categorias: categorias,
      ingresos: ingresos,
      metaBase: metaBase,
      fechaCierre: DateTime.now(),
    );

    return switch (resultado) {
      Exito(:final valor) =>
        _DatosCierre(ciclo: cicloVigente, cicloGuardado: guardado, snapshot: valor),
      Falla(:final mensaje) =>
        _DatosCierre(ciclo: cicloVigente, cicloGuardado: guardado, error: mensaje),
    };
  }

  Future<void> _cerrar(SnapshotCiclo snapshot) async {
    setState(() => _procesando = true);
    final resultado = cerrarCiclo(ciclo: widget.ciclo, snapshot: snapshot);
    switch (resultado) {
      case Falla(:final mensaje):
        if (!mounted) return;
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      case Exito(:final valor):
        await widget.cicloRepositorio.guardar(valor);
        if (!mounted) return;
        setState(() {
          _procesando = false;
          _cargar();
        });
    }
  }

  Future<void> _confirmarYReabrir(CicloGuardado guardado) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Reabrir ${guardado.ciclo.etiqueta}?'),
        content: const Text(
          'Sus cifras dejan de ser definitivas hasta que lo vuelvas a '
          'cerrar. El cierre actual se conserva hasta entonces.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _procesando = true);
    final resultado = reabrirCiclo(guardado);
    switch (resultado) {
      case Falla(:final mensaje):
        if (!mounted) return;
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      case Exito(:final valor):
        await widget.cicloRepositorio.guardar(valor);
        if (!mounted) return;
        setState(() {
          _procesando = false;
          _cargar();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cierre · ${widget.ciclo.etiqueta}')),
      body: SafeArea(
        child: FutureBuilder<_DatosCierre>(
          future: _datos,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final datos = snapshot.data!;
            final error = datos.error;
            if (error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error, style: const TextStyle(color: ColoresApp.coralTexto)),
                ),
              );
            }
            final snapshotCiclo = datos.snapshot!;
            // `datos.ciclo` (no `datos.cicloGuardado?.ciclo`) es la fuente
            // de verdad: en la rama de solo lectura ambos coinciden, pero
            // en la rama recalculada `datos.ciclo` ya viene normalizado a
            // abierto cuando el registro persistido decía "cerrado" sin
            // snapshot que respaldarlo (ver el bloque de arriba en
            // `_cargarDatos`) — usar el crudo mostraría "Reabrir ciclo"
            // sobre datos que en realidad se acaban de recalcular en vivo.
            final cerrado = datos.ciclo.estado == EstadoCiclo.cerrado;
            final yaPuedeCerrarse = !cerrado && !DateTime.now().isBefore(datos.ciclo.fechaFin);
            final metricas = calcularMetricasApartado(
              ingresoTotal: snapshotCiclo.ingresoTotal,
              totalGastado: snapshotCiclo.totalGastado,
              meta: snapshotCiclo.metaApartado,
              extraAApartado: snapshotCiclo.extraAApartado,
              extraAGasto: snapshotCiclo.extraAGasto,
            );

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _AnilloAlcance(ciclo: datos.ciclo, snapshot: snapshotCiclo, metricas: metricas),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FilaCifra('Te propusiste apartar', snapshotCiclo.metaApartado.formateado()),
                        _FilaCifra(
                          'Apartaste',
                          snapshotCiclo.apartado.formateado(),
                          color: ColoresApp.verdeTexto,
                        ),
                        _FilaCifra(
                          'Alcance',
                          metricas.alcance == null
                              ? '—'
                              : '${(metricas.alcance! * 100).round()}%',
                          color: ColoresApp.verdeTexto,
                        ),
                        if (metricas.alcanceSinExtra != null)
                          _FilaCifra(
                            'Alcance sin el extra',
                            '${(metricas.alcanceSinExtra! * 100).round()}%',
                          ),
                        _FilaCifra(
                          'Tasa de ahorro',
                          metricas.tasaDeAhorro == null
                              ? '—'
                              : '${(metricas.tasaDeAhorro! * 100).round()}% de lo que entró',
                        ),
                        _FilaCifra('Gastaste', snapshotCiclo.totalGastado.formateado()),
                        const SizedBox(height: 12),
                        Text(
                          'La tasa de ahorro se compara entre meses aunque cambien tus '
                          'ingresos. El alcance mide contra la meta que tú pusiste.',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (metricas.alcanceSinExtra != null) ...[
                          const SizedBox(height: 10),
                          _AvisoExtra(metricas: metricas),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Presupuesto vs. real', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ...snapshotCiclo.renglones.map((r) => _TarjetaRenglon(renglon: r)),
                const SizedBox(height: 24),
                if (_procesando)
                  const Center(child: CircularProgressIndicator())
                else if (!cerrado)
                  ElevatedButton(
                    onPressed: yaPuedeCerrarse ? () => _cerrar(snapshotCiclo) : null,
                    child: Text(
                      yaPuedeCerrarse
                          ? 'Cerrar ciclo'
                          : 'El ciclo termina el ${fechaCorta(datos.ciclo.fechaFin)}',
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _confirmarYReabrir(datos.cicloGuardado!),
                    child: const Text('Reabrir ciclo'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnilloAlcance extends StatelessWidget {
  final Ciclo ciclo;
  final SnapshotCiclo snapshot;
  final MetricasApartado metricas;

  const _AnilloAlcance({required this.ciclo, required this.snapshot, required this.metricas});

  @override
  Widget build(BuildContext context) {
    final alcance = metricas.alcance;
    final (titular, color) = switch (calcularNivelAlcance(alcance)) {
      null => ('Cierre de ciclo', ColoresApp.violeta),
      NivelAlcance.logrado => ('Tu mejor ciclo', ColoresApp.verde),
      NivelAlcance.cerca => ('Casi lo logras', ColoresApp.ambar),
      NivelAlcance.corto => ('Este ciclo costó más', ColoresApp.coral),
    };

    return Column(
      children: [
        Text(ciclo.estado == EstadoCiclo.cerrado ? 'Ciclo ${ciclo.etiqueta} · cerrado' : 'Ciclo ${ciclo.etiqueta}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Container(
          width: 140,
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            alcance == null ? '—' : '${(alcance * 100).round()}%',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(titular, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          'Querías apartar ${snapshot.metaApartado.formateado()} y '
          'apartaste ${snapshot.apartado.formateado()}.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FilaCifra extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? color;

  const _FilaCifra(this.etiqueta, this.valor, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(color: ColoresApp.medio)),
          Text(valor,
              style: TextStyle(fontWeight: FontWeight.w700, color: color ?? ColoresApp.tinta)),
        ],
      ),
    );
  }
}

/// Explica la diferencia entre `alcance` y `alcanceSinExtra` en las tres
/// ramas posibles (app-finanzas-ingresos-ajustes-v11.html §3): con destino
/// `apartado` el extra entra al numerador **y** al denominador, así que
/// `alcance` puede terminar por *debajo* de `alcanceSinExtra` — la rama que
/// más fácil se olvida si solo se piensa en "el extra siempre ayuda".
class _AvisoExtra extends StatelessWidget {
  final MetricasApartado metricas;

  const _AvisoExtra({required this.metricas});

  @override
  Widget build(BuildContext context) {
    final alcance = metricas.alcance ?? 0;
    final sinExtra = metricas.alcanceSinExtra!;
    final texto = alcance > sinExtra
        ? 'Llegaste a ${(alcance * 100).round()}% gracias al ingreso extra. '
            'Sin él, tu alcance habría sido ${(sinExtra * 100).round()}%.'
        : alcance < sinExtra
            ? 'Tu alcance con extra (${(alcance * 100).round()}%) quedó por debajo '
                'del que habrías tenido sin él (${(sinExtra * 100).round()}%): '
                'el extra que apartaste también subió la meta.'
            : 'El ingreso extra no cambió tu alcance este ciclo.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.violetaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texto, style: const TextStyle(color: ColoresApp.tinta, fontSize: 12.5)),
    );
  }
}

class _TarjetaRenglon extends StatelessWidget {
  final RenglonSnapshot renglon;

  const _TarjetaRenglon({required this.renglon});

  @override
  Widget build(BuildContext context) {
    final porcentajeUsado = renglon.presupuestoCentavos.esCero
        ? null
        : renglon.realCentavos.centavos / renglon.presupuestoCentavos.centavos;
    final estado = calcularEstadoRitmo(porcentajeUsado: porcentajeUsado);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text(renglon.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(renglon.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                Text(
                  '${renglon.realCentavos.formateado()} de ${renglon.presupuestoCentavos.formateado()}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            if (porcentajeUsado != null) ...[
              const SizedBox(height: 8),
              BarraRitmo(
                porcentajeUsado: porcentajeUsado,
                avanceCiclo: 1.0,
                estado: estado,
                descripcion: renglon.nombre,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DatosCierre {
  final Ciclo ciclo;
  final CicloGuardado? cicloGuardado;
  final SnapshotCiclo? snapshot;
  final String? error;

  const _DatosCierre({
    required this.ciclo,
    required this.cicloGuardado,
    this.snapshot,
    this.error,
  });
}
