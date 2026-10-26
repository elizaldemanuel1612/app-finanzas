import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../presupuesto/apartado_estimado.dart';
import 'reporte_analisis.dart';

/// Qué tan urgente es una recomendación; ordena la lista (lo urgente
/// primero) y le da color en la UI.
enum TonoRecomendacion { alerta, atencion, positivo, informativo }

/// La salida concreta de cada recomendación (regla #22).
enum AccionRecomendacion { verCategoria, verGastos, verMeta }

final class Recomendacion {
  final TonoRecomendacion tono;
  final String titulo;
  final String detalle;
  final AccionRecomendacion accion;

  /// La categoría a abrir cuando [accion] es [AccionRecomendacion.verCategoria].
  final String? categoriaId;

  const Recomendacion({
    required this.tono,
    required this.titulo,
    required this.detalle,
    required this.accion,
    this.categoriaId,
  });
}

const _maximo = 5;

/// Recomendaciones de la pestaña Análisis (spec-app-finanzas-v2.md §5.7),
/// en el tono de addendum-v3 §4.4 (nunca reprender) y con el vocabulario
/// de §3.3 ("Te pasaste por $X", "Van N de M días"). Máximo 5, las más
/// urgentes primero.
///
/// [ingresoCiclo] y [metaCiclo] alimentan la recomendación de la meta;
/// sin meta (`null` o cero) esa no se calcula.
List<Recomendacion> calcularRecomendaciones({
  required ReporteAnalisis reporte,
  required Dinero ingresoCiclo,
  required Dinero? metaCiclo,
}) {
  final r = reporte;
  final lista = <Recomendacion>[];
  final dias = r.diaDelCiclo;
  final avance = r.diaDelCiclo / r.diasDelCiclo;
  final variables = [
    for (final g in r.porCategoria)
      if (g.categoria is CategoriaVariable) g,
  ];

  // Variables con holgura proyectada (para sugerir de dónde mover).
  final holgadas = [
    for (final g in variables)
      if (_proyeccion(g.total, r) < g.presupuesto) g,
  ];

  var excedidas = 0;
  for (final g in variables) {
    final presupuesto = g.presupuesto;
    if (g.total > presupuesto) {
      // Cada categoría excedida sugiere una holgada distinta; si ya no
      // quedan, la salida es no sumar más.
      final opciones = holgadas.where((h) => h.categoria.id != g.categoria.id).toList();
      final otra = excedidas < opciones.length ? opciones[excedidas] : null;
      excedidas++;
      lista.add(Recomendacion(
        tono: TonoRecomendacion.alerta,
        titulo: 'Te pasaste en ${g.categoria.nombre} por ${(g.total - presupuesto).formateado()}',
        detalle: otra != null
            ? 'Nada grave: ${otra.categoria.nombre} va holgada y puedes moverle presupuesto desde el detalle.'
            : 'Nada grave: lo que queda del ciclo, trata de no sumar más aquí.',
        accion: AccionRecomendacion.verCategoria,
        categoriaId: g.categoria.id,
      ));
    } else if (r.diasRestantes > 0 &&
        (g.total == presupuesto || (presupuesto - g.total).centavos < r.diasRestantes)) {
      // Llegó justo (o le quedan centavos): "máximo $0.00 al día" no
      // ayuda; se dice como en addendum-v3 §3.3.
      lista.add(Recomendacion(
        tono: TonoRecomendacion.atencion,
        titulo: 'Ya usaste todo lo de ${g.categoria.nombre}',
        detalle: 'Faltan ${r.diasRestantes} ${_dias(r.diasRestantes)}: si puedes, no sumes más aquí '
            'o muévele presupuesto desde otra categoría.',
        accion: AccionRecomendacion.verCategoria,
        categoriaId: g.categoria.id,
      ));
    } else if (dias >= 3 && r.diasRestantes > 0) {
      final proyectado = _proyeccion(g.total, r);
      if (proyectado > presupuesto) {
        final porDia = Dinero((presupuesto - g.total).centavos ~/ r.diasRestantes);
        lista.add(Recomendacion(
          tono: TonoRecomendacion.atencion,
          titulo: '${g.categoria.nombre} va rápido',
          detalle: 'A este ritmo cerraría en ${proyectado.formateado()}, '
              '${(proyectado - presupuesto).formateado()} arriba. Para llegar justo: '
              'máximo ${porDia.formateado()} al día los ${r.diasRestantes} ${_dias(r.diasRestantes)} que faltan.',
          accion: AccionRecomendacion.verCategoria,
          categoriaId: g.categoria.id,
        ));
      } else if (avance >= 0.5 &&
          presupuesto >= const Dinero.pesos(500) &&
          g.total.centavos * 2 < (presupuesto.centavos * avance).round()) {
        lista.add(Recomendacion(
          tono: TonoRecomendacion.positivo,
          titulo: 'Te está sobrando en ${g.categoria.nombre}',
          detalle: 'Llevas ${g.total.formateado()} de ${presupuesto.formateado()} y van '
              '$dias de ${r.diasDelCiclo} días. Si así sigue, eso puede ir a tu meta.',
          accion: AccionRecomendacion.verCategoria,
          categoriaId: g.categoria.id,
        ));
      }
    }
  }

  // Más que el ciclo pasado, a los mismos días.
  for (final c in r.contraAnterior) {
    if (c.categoria is! CategoriaVariable) continue;
    if (c.anterior < const Dinero.pesos(200)) continue;
    if (c.diferencia < const Dinero.pesos(300)) continue;
    if (c.actual.centavos * 100 < c.anterior.centavos * 125) continue;
    lista.add(Recomendacion(
      tono: TonoRecomendacion.atencion,
      titulo: 'Más en ${c.categoria.nombre} que el ciclo pasado',
      detalle: 'A los $dias ${_dias(dias)} llevas ${c.actual.formateado()}; el ciclo pasado '
          'llevabas ${c.anterior.formateado()}.',
      accion: AccionRecomendacion.verCategoria,
      categoriaId: c.categoria.id,
    ));
  }

  // Gastos pequeños.
  if (r.gastosPequenos >= 6 && r.totalGastosPequenos.centavos * 10 >= r.gastadoVariables.centavos) {
    lista.add(Recomendacion(
      tono: TonoRecomendacion.atencion,
      titulo: 'Los gastos pequeños suman',
      detalle: '${r.gastosPequenos} gastos de ${montoGastoPequeno.formateado()} o menos suman '
          '${r.totalGastosPequenos.formateado()} este ciclo. Uno por uno no se notan.',
      accion: AccionRecomendacion.verGastos,
    ));
  }

  // Tu meta.
  final meta = metaCiclo;
  if (meta != null && meta.esPositivo && r.diasRestantes > 0 && dias >= 3) {
    final apartado = calcularApartadoEstimado(
      ingreso: ingresoCiclo,
      presupuestoFijas: r.presupuestoFijas,
      gastadoFijas: r.gastadoFijas,
      presupuestoVariables: r.presupuestoVariables,
      gastadoVariables: r.gastadoVariables,
      diaDelCiclo: r.diaDelCiclo,
      diasDelCiclo: r.diasDelCiclo,
    );
    final Recomendacion rec;
    if (apartado >= meta) {
      rec = Recomendacion(
        tono: TonoRecomendacion.positivo,
        titulo: 'Vas para cumplir tu meta',
        detalle: 'A este ritmo apartarías ${apartado.formateado()} de ${meta.formateado()}.',
        accion: AccionRecomendacion.verMeta,
      );
    } else if (apartado.esNegativo) {
      rec = Recomendacion(
        tono: TonoRecomendacion.alerta,
        titulo: 'A este ritmo no alcanza para apartar',
        detalle: 'Tus gastos pasarían lo que entra por ${apartado.absoluto.formateado()}. '
            'Empieza por las categorías que van rápido.',
        accion: AccionRecomendacion.verMeta,
      );
    } else {
      final porDia = Dinero((meta - apartado).centavos ~/ r.diasRestantes);
      rec = Recomendacion(
        tono: TonoRecomendacion.atencion,
        titulo: 'Tu meta está en juego',
        detalle: 'A este ritmo apartarías ${apartado.formateado()} de ${meta.formateado()}. '
            'Gastando ${porDia.formateado()} menos al día en variables, llegas.',
        accion: AccionRecomendacion.verMeta,
      );
    }
    lista.add(rec);
  }

  // Vas abajo del ciclo pasado.
  final anterior = r.variablesAnteriorMismoDia;
  if (anterior != null &&
      anterior >= const Dinero.pesos(500) &&
      r.gastadoVariables.centavos * 100 <= anterior.centavos * 85) {
    lista.add(Recomendacion(
      tono: TonoRecomendacion.positivo,
      titulo: 'Vas ${(anterior - r.gastadoVariables).formateado()} abajo del ciclo pasado',
      detalle: 'A los $dias ${_dias(dias)} llevas ${r.gastadoVariables.formateado()} en variables; '
          'el ciclo pasado llevabas ${anterior.formateado()}.',
      accion: AccionRecomendacion.verGastos,
    ));
  }

  // Tu día de más gasto.
  if (r.diasConDatos >= 14) {
    var mayor = 0;
    for (var i = 1; i < 7; i++) {
      if (r.promedioPorDiaSemana[i] > r.promedioPorDiaSemana[mayor]) mayor = i;
    }
    final resto = [
      for (var i = 0; i < 7; i++)
        if (i != mayor) r.promedioPorDiaSemana[i].centavos,
    ];
    final promedioResto = resto.reduce((a, b) => a + b) ~/ resto.length;
    final pico = r.promedioPorDiaSemana[mayor].centavos;
    if (promedioResto > 0 && pico * 10 >= promedioResto * 18) {
      lista.add(Recomendacion(
        tono: TonoRecomendacion.informativo,
        titulo: 'Los ${nombresDiaSemana[mayor]} gastas más',
        detalle: 'En promedio ${Dinero(pico).formateado()} ese día, contra '
            '${Dinero(promedioResto).formateado()} los demás. Planearlo ayuda.',
        accion: AccionRecomendacion.verGastos,
      ));
    }
  }

  lista.sort((a, b) => a.tono.index.compareTo(b.tono.index));
  return lista.length > _maximo ? lista.sublist(0, _maximo) : lista;
}

/// Plural, en minúscula, empezando en lunes.
const nombresDiaSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábados', 'domingos'];

Dinero _proyeccion(Dinero total, ReporteAnalisis r) =>
    Dinero(total.centavos + total.centavos * r.diasRestantes ~/ r.diaDelCiclo);

String _dias(int n) => n == 1 ? 'día' : 'días';
