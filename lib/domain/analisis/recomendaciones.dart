import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../presupuesto/apartado_estimado.dart';
import '../presupuesto/cobertura_excesos.dart';
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

/// Cuántas categorías excedidas van con tarjeta propia; las demás se juntan
/// en una sola para dejar lugar a otras recomendaciones.
const _excedidasDetalladas = 2;

/// "a, b y c".
String _enLista(List<String> partes) =>
    partes.length == 1 ? partes.single : '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';

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
  // Pronóstico y cobertura: el MPC y el único motor de cobertura, los
  // mismos que Inicio y el detalle de categoría
  // (`docs/rediseno/plan-rediseno.md`, Etapa 0).
  final variables = r.variables;
  final coberturas = calcularCoberturas(variables);

  // Las dos más grandes, cada una con su salida concreta (2026-11-08: antes
  // todas decían "Nada grave" y llenaban las 5 recomendaciones).
  final estadoPorId = {for (final e in variables) e.categoria.id: e};
  for (final c in coberturas.take(_excedidasDetalladas)) {
    final e = estadoPorId[c.categoria.id]!;
    lista.add(Recomendacion(
      tono: TonoRecomendacion.alerta,
      titulo: 'Te pasaste en ${c.categoria.nombre} por ${c.exceso.formateado()}',
      detalle: [
        if (r.diasRestantes > 0 && dias >= 3 && e.proyeccion > e.gastado)
          'Estimado al cierre: ${(e.proyeccion - e.presupuesto).formateado()} arriba.',
        c.frase,
      ].join(' '),
      accion: AccionRecomendacion.verCategoria,
      categoriaId: c.categoria.id,
    ));
  }
  final resto = coberturas.skip(_excedidasDetalladas).toList();
  if (resto.isNotEmpty) {
    final total = Dinero.suma(resto.map((c) => c.exceso));
    final cuales = [for (final c in resto.take(3)) '${c.categoria.nombre} (${c.exceso.formateado()})'];
    if (resto.length > 3) cuales.add('${resto.length - 3} más');
    lista.add(Recomendacion(
      tono: TonoRecomendacion.alerta,
      titulo: 'También te pasaste en ${resto.length} ${resto.length == 1 ? 'categoría' : 'categorías'} más',
      detalle: '${_enLista(cuales)}: ${total.formateado()} en total. Si se repite cada ciclo, '
          'su presupuesto se quedó corto: ajústalo para que tu plan sea realista.',
      accion: AccionRecomendacion.verCategoria,
      categoriaId: resto.first.categoria.id,
    ));
  }

  for (final e in variables) {
    final presupuesto = e.presupuesto;
    if (e.gastado > presupuesto || !presupuesto.esPositivo) {
      continue;
    } else if (r.diasRestantes > 0 &&
        (e.gastado == presupuesto || (presupuesto - e.gastado).centavos < r.diasRestantes)) {
      // Llegó justo (o le quedan centavos): "máximo $0.00 al día" no
      // ayuda; se dice como en addendum-v3 §3.3.
      lista.add(Recomendacion(
        tono: TonoRecomendacion.atencion,
        titulo: 'Ya usaste todo lo de ${e.categoria.nombre}',
        detalle: 'Faltan ${r.diasRestantes} ${_dias(r.diasRestantes)}: si puedes, no sumes más aquí '
            'o muévele presupuesto desde otra categoría.',
        accion: AccionRecomendacion.verCategoria,
        categoriaId: e.categoria.id,
      ));
    } else if (dias >= 3 && r.diasRestantes > 0) {
      if (e.proyeccion > presupuesto) {
        final porDia = Dinero((presupuesto - e.gastado).centavos ~/ r.diasRestantes);
        lista.add(Recomendacion(
          tono: TonoRecomendacion.atencion,
          titulo: '${e.categoria.nombre} va rápido',
          detalle: 'Estimado al cierre: ${e.proyeccion.formateado()}, '
              '${(e.proyeccion - presupuesto).formateado()} arriba. Para llegar justo: '
              'máximo ${porDia.formateado()} al día los ${r.diasRestantes} ${_dias(r.diasRestantes)} que faltan.',
          accion: AccionRecomendacion.verCategoria,
          categoriaId: e.categoria.id,
        ));
      } else if (avance >= 0.5 &&
          presupuesto >= const Dinero.pesos(500) &&
          e.gastado.centavos * 2 < (presupuesto.centavos * avance).round()) {
        lista.add(Recomendacion(
          tono: TonoRecomendacion.positivo,
          titulo: 'Te está sobrando en ${e.categoria.nombre}',
          detalle: 'Llevas ${e.gastado.formateado()} de ${presupuesto.formateado()} y van '
              '$dias de ${r.diasDelCiclo} días. Si así sigue, eso puede ir a tu meta.',
          accion: AccionRecomendacion.verCategoria,
          categoriaId: e.categoria.id,
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
      detalle: r.terminado
          ? 'Gastaste ${c.actual.formateado()}; el ciclo pasado, ${c.anterior.formateado()}.'
          : 'A los $dias ${_dias(dias)} llevas ${c.actual.formateado()}; el ciclo pasado '
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
          '${r.totalGastosPequenos.formateado()} ${r.terminado ? 'en ese ciclo' : 'este ciclo'}. Uno por uno no se notan.',
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
      proyeccionVariables: r.proyeccionVariables,
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
      titulo: r.terminado
          ? 'Gastaste ${(anterior - r.gastadoVariables).formateado()} menos que el ciclo pasado'
          : 'Vas ${(anterior - r.gastadoVariables).formateado()} abajo del ciclo pasado',
      detalle: r.terminado
          ? 'Fueron ${r.gastadoVariables.formateado()} en variables; el ciclo pasado, ${anterior.formateado()}.'
          : 'A los $dias ${_dias(dias)} llevas ${r.gastadoVariables.formateado()} en variables; '
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

String _dias(int n) => n == 1 ? 'día' : 'días';
