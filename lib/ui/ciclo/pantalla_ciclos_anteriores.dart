import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/ingreso_extra_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../domain/ciclo_de_vida/evolucion_ciclos.dart';
import '../../domain/ciclo_de_vida/historial_ciclos.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/perfil.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../comun/formato_fecha.dart';
import '../comun/grafica_evolucion.dart';
import '../comun/tema.dart';
import 'pantalla_cierre_ciclo.dart';

/// Lista de ciclos que ya quedaron atrás — cerrados formalmente o no — más
/// la gráfica de trazabilidad que responde "¿voy mejorando o no?"
/// (addendum-v3-ajuste-y-ux.md §3.1, §4.3). `PantallaInicio` solo detecta
/// el ciclo actual; esta pantalla es el punto de entrada para todo lo
/// anterior, reconciliando lo persistido en [CicloRepositorio] con lo que
/// solo dejó rastro en movimientos (ver `calcularHistorialCiclos`).
class PantallaCiclosAnteriores extends StatefulWidget {
  final Perfil perfil;
  final Ciclo cicloActual;
  final CategoriaRepositorio categoriaRepositorio;
  final MovimientoRepositorio movimientoRepositorio;
  final CicloRepositorio cicloRepositorio;
  final IngresoExtraRepositorio ingresoExtraRepositorio;

  const PantallaCiclosAnteriores({
    super.key,
    required this.perfil,
    required this.cicloActual,
    required this.categoriaRepositorio,
    required this.movimientoRepositorio,
    required this.cicloRepositorio,
    required this.ingresoExtraRepositorio,
  });

  @override
  State<PantallaCiclosAnteriores> createState() => _PantallaCiclosAnterioresState();
}

class _PantallaCiclosAnterioresState extends State<PantallaCiclosAnteriores> {
  late Future<_Datos> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<_Datos> _cargar() async {
    final ciclosGuardados = await widget.cicloRepositorio.listarTodos();
    final movimientos = await widget.movimientoRepositorio.listarTodos();
    final ingresosExtra = await widget.ingresoExtraRepositorio.listarTodos();
    final categorias = await widget.categoriaRepositorio.listarTodas();

    final historial = calcularHistorialCiclos(
      ciclosGuardados: ciclosGuardados,
      todosLosMovimientos: movimientos,
      todosLosIngresosExtra: ingresosExtra,
      calculadoraCiclo: CalculadoraCiclo(widget.perfil.diaCorte),
      cicloActualId: widget.cicloActual.id,
    );

    // Mismos insumos que arma `PantallaCierreCiclo` para el ciclo vigente
    // (pantalla_cierre_ciclo.dart) — el ciclo en curso no tiene snapshot
    // todavía, así que se recalculan en vivo.
    final metaBase = calcularMetaBase(perfil: widget.perfil, categorias: categorias);
    final ingresos = calcularIngresosDelCiclo(
      ingresoBase: widget.perfil.ingresoBaseMensual,
      cicloId: widget.cicloActual.id,
      extras: ingresosExtra,
    );
    final totalGastadoActual = Dinero.suma(
      movimientos
          .where((m) => m.cicloId == widget.cicloActual.id && m.estado == EstadoMovimiento.activo)
          .map((m) => m.monto),
    );

    final evolucion = calcularEvolucionCiclos(
      historial: historial,
      enCurso: InsumosCicloEnCurso(
        ciclo: widget.cicloActual,
        ingresoTotal: ingresos.total,
        totalGastado: totalGastadoActual,
        meta: calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresos),
        extraAApartado: ingresos.extraAApartado,
        extraAGasto: ingresos.extraAGasto,
      ),
    );

    return _Datos(historial: historial, evolucion: evolucion);
  }

  void _irAlCierre(Ciclo ciclo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCierreCiclo(
          ciclo: ciclo,
          perfil: widget.perfil,
          categoriaRepositorio: widget.categoriaRepositorio,
          movimientoRepositorio: widget.movimientoRepositorio,
          cicloRepositorio: widget.cicloRepositorio,
          ingresoExtraRepositorio: widget.ingresoExtraRepositorio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ciclos anteriores')),
      body: SafeArea(
        child: FutureBuilder<_Datos>(
          future: _datos,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final datos = snapshot.data!;
            final resumenes = datos.historial;
            if (resumenes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🗓️', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 12),
                      Text(
                        'Todavía no hay ciclos anteriores. Aquí verás el '
                        'historial en cuanto termine el primero.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.medio),
                      ),
                    ],
                  ),
                ),
              );
            }

            final evolucion = datos.evolucion;
            final frase = fraseEvolucion(evolucion);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _EncabezadoEvolucion(evolucion: evolucion, cicloActual: widget.cicloActual),
                if (frase != null) ...[
                  const SizedBox(height: 8),
                  _TarjetaFrase(frase: frase),
                ],
                const SizedBox(height: 16),
                for (final r in resumenes) _TarjetaCiclo(resumen: r, onTap: () => _irAlCierre(r.ciclo)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EncabezadoEvolucion extends StatelessWidget {
  final EvolucionCiclos evolucion;
  final Ciclo cicloActual;

  const _EncabezadoEvolucion({required this.evolucion, required this.cicloActual});

  @override
  Widget build(BuildContext context) {
    if (!evolucion.hayDatos) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Necesito un ciclo cerrado para dibujar tu evolución.',
            style: TextStyle(color: ColoresApp.medio),
          ),
        ),
      );
    }

    final tieneEnCurso = evolucion.puntos.any((p) => p.estado == EstadoPunto.enCurso);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuánto has apartado por ciclo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ColoresApp.tinta),
            ),
            const SizedBox(height: 16),
            GraficaEvolucion(evolucion: evolucion),
            const SizedBox(height: 20),
            _FilaKv(
              'Acumulado en ${evolucion.ciclosAcumulados} '
              '${evolucion.ciclosAcumulados == 1 ? 'ciclo' : 'ciclos'}',
              evolucion.acumulado.formateado(),
              color: ColoresApp.verdeTexto,
            ),
            if (evolucion.promedioAhorroPorMes != null)
              _FilaKv('Promedio de ahorro por mes', evolucion.promedioAhorroPorMes!.formateado()),
            if (tieneEnCurso) ...[
              const SizedBox(height: 10),
              Text(
                '*${cicloActual.etiqueta} es proyección; se congela al cerrar '
                'el ciclo el ${fechaCorta(cicloActual.fechaFin)}.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaFrase extends StatelessWidget {
  final String frase;

  const _TarjetaFrase({required this.frase});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ColoresApp.violetaSuave,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lo que te dice la gráfica',
              style: TextStyle(fontWeight: FontWeight.w800, color: ColoresApp.violeta, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(frase, style: const TextStyle(color: ColoresApp.tinta, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _FilaKv extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? color;

  const _FilaKv(this.etiqueta, this.valor, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
          Text(valor, style: TextStyle(fontWeight: FontWeight.w800, color: color ?? ColoresApp.tinta)),
        ],
      ),
    );
  }
}

class _TarjetaCiclo extends StatelessWidget {
  final CicloResumen resumen;
  final VoidCallback onTap;

  const _TarjetaCiclo({required this.resumen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cerrado = resumen.ciclo.estado == EstadoCiclo.cerrado;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text('Ciclo ${resumen.ciclo.etiqueta}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${fechaCorta(resumen.ciclo.fechaInicio)} – ${fechaCorta(resumen.ciclo.fechaFin)}'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(resumen.totalGastado.formateado(), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cerrado ? ColoresApp.verdeSuave : ColoresApp.ambarSuave,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                resumen.tuvoIngresoExtra
                    ? '🎁 ${cerrado ? 'Cerrado' : 'Sin cerrar'}'
                    : (cerrado ? 'Cerrado' : 'Sin cerrar'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cerrado ? ColoresApp.verdeTexto : ColoresApp.ambarTexto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Datos {
  final List<CicloResumen> historial;
  final EvolucionCiclos evolucion;

  const _Datos({required this.historial, required this.evolucion});
}
