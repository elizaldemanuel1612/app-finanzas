import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../clasificacion/normalizacion_texto.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';

/// Datos de la pestaña Análisis (spec-app-finanzas-v2.md §5.7). Todo se
/// calcula aquí sobre movimientos activos; la UI solo dibuja.

/// Una categoría en "¿En qué se va?".
final class GastoCategoria {
  final Categoria categoria;
  final Dinero total;

  /// Porcentaje entero (0–100) del gasto total del ciclo.
  final int porcentaje;
  final int conteo;

  const GastoCategoria({
    required this.categoria,
    required this.total,
    required this.porcentaje,
    required this.conteo,
  });

  /// El presupuesto del ciclo: monto fijo o presupuesto variable.
  Dinero get presupuesto => presupuestoDe(categoria);
}

/// Una categoría en "Contra el ciclo pasado", a los mismos días
/// transcurridos (addendum-v3-ajuste-y-ux.md §2.4).
final class ComparacionCategoria {
  final Categoria categoria;
  final Dinero actual;
  final Dinero anterior;

  const ComparacionCategoria({
    required this.categoria,
    required this.actual,
    required this.anterior,
  });

  Dinero get diferencia => actual - anterior;
}

/// Un ciclo en "Últimos ciclos".
final class TotalCiclo {
  final String cicloId;
  final String etiqueta;
  final Dinero total;
  final bool enCurso;

  const TotalCiclo({
    required this.cicloId,
    required this.etiqueta,
    required this.total,
    required this.enCurso,
  });
}

/// Una descripción en "Dónde más gastas".
final class GastoDescripcion {
  final String descripcion;
  final Dinero total;
  final int conteo;

  const GastoDescripcion({required this.descripcion, required this.total, required this.conteo});
}

final class ReporteAnalisis {
  final Ciclo ciclo;

  /// Día del ciclo que es hoy, contando el primero como 1 (nunca más que
  /// [diasDelCiclo]).
  final int diaDelCiclo;
  final int diasDelCiclo;

  final Dinero gastado;
  final Dinero gastadoVariables;
  final Dinero gastadoFijas;
  final Dinero presupuestoVariables;
  final Dinero presupuestoFijas;

  /// Promedio por día de las variables en lo que va del ciclo.
  final Dinero promedioDiarioVariables;

  /// Variables al cierre si sigue el mismo ritmo (lineal; las fijas no se
  /// pronostican, regla #9).
  final Dinero proyeccionVariables;

  /// Ordenadas de mayor a menor gasto; solo categorías con gasto.
  final List<GastoCategoria> porCategoria;

  /// Gasto acumulado de variables al final de cada día transcurrido
  /// (índice 0 = primer día del ciclo).
  final List<Dinero> acumuladoVariablesPorDia;

  /// `null` si no hay ciclo anterior con movimientos.
  final Dinero? variablesAnteriorMismoDia;

  /// Por categoría (solo las que tuvieron gasto en alguno de los dos),
  /// de mayor a menor gasto actual.
  final List<ComparacionCategoria> contraAnterior;

  /// Hasta 6 ciclos, del más antiguo al actual.
  final List<TotalCiclo> ultimosCiclos;

  /// Promedio por día de la semana de las variables en los últimos 90
  /// días (índice 0 = lunes … 6 = domingo).
  final List<Dinero> promedioPorDiaSemana;

  /// Días distintos (calendario) que cubre [promedioPorDiaSemana].
  final int diasConDatos;

  /// Las 5 descripciones con más gasto en variables del ciclo.
  final List<GastoDescripcion> dondeMasGastas;

  final Dinero conTarjeta;
  final Dinero enEfectivo;

  /// Gastos de [montoGastoPequeno] o menos en el ciclo.
  final int gastosPequenos;
  final Dinero totalGastosPequenos;

  const ReporteAnalisis({
    required this.ciclo,
    required this.diaDelCiclo,
    required this.diasDelCiclo,
    required this.gastado,
    required this.gastadoVariables,
    required this.gastadoFijas,
    required this.presupuestoVariables,
    required this.presupuestoFijas,
    required this.promedioDiarioVariables,
    required this.proyeccionVariables,
    required this.porCategoria,
    required this.acumuladoVariablesPorDia,
    required this.variablesAnteriorMismoDia,
    required this.contraAnterior,
    required this.ultimosCiclos,
    required this.promedioPorDiaSemana,
    required this.diasConDatos,
    required this.dondeMasGastas,
    required this.conTarjeta,
    required this.enEfectivo,
    required this.gastosPequenos,
    required this.totalGastosPequenos,
  });

  int get diasRestantes => diasDelCiclo - diaDelCiclo;
  bool get sinMovimientos => !gastado.esPositivo;
}

/// "Gasto pequeño" para la recomendación de gastos hormiga (§5.7).
const montoGastoPequeno = Dinero.pesos(150);

const _etiquetasMes = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic', //
];

Dinero presupuestoDe(Categoria c) => switch (c) {
      CategoriaFija f => f.montoFijoCentavos,
      CategoriaVariable v => v.presupuestoMensualCentavos,
    };

/// Arma el reporte del [ciclo] en curso.
///
/// - [categorias]: todas (también archivadas, para nombrar gastos viejos),
///   con los presupuestos **efectivos** del ciclo (ajustes aplicados).
/// - [cicloAnterior]: el ciclo previo según el historial de cortes, o
///   `null` si no hay.
ReporteAnalisis calcularReporteAnalisis({
  required Ciclo ciclo,
  required Ciclo? cicloAnterior,
  required List<Movimiento> movimientos,
  required List<Categoria> categorias,
  required DateTime hoy,
}) {
  final porId = {for (final c in categorias) c.id: c};
  final activos = [
    for (final m in movimientos)
      if (m.estado == EstadoMovimiento.activo && porId.containsKey(m.categoriaId)) m,
  ];
  bool esVariable(Movimiento m) => porId[m.categoriaId] is CategoriaVariable;

  final hoyDia = _dia(hoy);
  final diasDelCiclo = _diasEntre(ciclo.fechaInicio, ciclo.fechaFin) + 1;
  final transcurridos = _diasEntre(ciclo.fechaInicio, hoyDia) + 1;
  final diaDelCiclo = transcurridos < 1 ? 1 : (transcurridos > diasDelCiclo ? diasDelCiclo : transcurridos);

  final delCiclo = [for (final m in activos) if (m.cicloId == ciclo.id) m];
  final variables = [for (final m in delCiclo) if (esVariable(m)) m];

  final gastado = _suma(delCiclo);
  final gastadoVariables = _suma(variables);
  final presupuestoVariables = Dinero.suma([
    for (final c in categorias)
      if (c.activa && c is CategoriaVariable) c.presupuestoMensualCentavos,
  ]);
  final presupuestoFijas = Dinero.suma([
    for (final c in categorias)
      if (c.activa && c is CategoriaFija) c.montoFijoCentavos,
  ]);
  final promedio = Dinero(gastadoVariables.centavos ~/ diaDelCiclo);
  final proyeccion = Dinero(
    gastadoVariables.centavos + gastadoVariables.centavos * (diasDelCiclo - diaDelCiclo) ~/ diaDelCiclo,
  );

  // ¿En qué se va?
  final totales = <String, (int, int)>{};
  for (final m in delCiclo) {
    final (centavos, conteo) = totales[m.categoriaId] ?? (0, 0);
    totales[m.categoriaId] = (centavos + m.monto.centavos, conteo + 1);
  }
  final porCategoria = [
    for (final e in totales.entries)
      GastoCategoria(
        categoria: porId[e.key]!,
        total: Dinero(e.value.$1),
        porcentaje: gastado.esPositivo ? (e.value.$1 * 100 + gastado.centavos ~/ 2) ~/ gastado.centavos : 0,
        conteo: e.value.$2,
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));

  // Ritmo del ciclo.
  final porDia = List<int>.filled(diaDelCiclo, 0);
  for (final m in variables) {
    final i = _diasEntre(ciclo.fechaInicio, _dia(m.fecha));
    if (i >= 0 && i < diaDelCiclo) porDia[i] += m.monto.centavos;
  }
  var acumulado = 0;
  final acumuladoPorDia = [
    for (final d in porDia) Dinero(acumulado += d),
  ];

  // Contra el ciclo pasado, a los mismos días transcurridos.
  Dinero? anteriorMismoDia;
  final contraAnterior = <ComparacionCategoria>[];
  if (cicloAnterior != null) {
    final limite = cicloAnterior.fechaInicio.add(Duration(days: diaDelCiclo - 1));
    final delAnterior = [
      for (final m in activos)
        if (m.cicloId == cicloAnterior.id && !_dia(m.fecha).isAfter(_dia(limite))) m,
    ];
    if (delAnterior.isNotEmpty) {
      anteriorMismoDia = _suma([for (final m in delAnterior) if (esVariable(m)) m]);
      final ids = {...delCiclo.map((m) => m.categoriaId), ...delAnterior.map((m) => m.categoriaId)};
      for (final id in ids) {
        contraAnterior.add(ComparacionCategoria(
          categoria: porId[id]!,
          actual: _suma([for (final m in delCiclo) if (m.categoriaId == id) m]),
          anterior: _suma([for (final m in delAnterior) if (m.categoriaId == id) m]),
        ));
      }
      contraAnterior.sort((a, b) {
        final c = b.actual.compareTo(a.actual);
        return c != 0 ? c : b.anterior.compareTo(a.anterior);
      });
    }
  }

  // Últimos ciclos (cicloId = AAAA-MM: ordena cronológicamente como texto).
  final porCiclo = <String, int>{};
  for (final m in activos) {
    if (m.cicloId.compareTo(ciclo.id) > 0) continue;
    porCiclo[m.cicloId] = (porCiclo[m.cicloId] ?? 0) + m.monto.centavos;
  }
  porCiclo.putIfAbsent(ciclo.id, () => 0);
  final ids = porCiclo.keys.toList()..sort();
  final ultimos = ids.length > 6 ? ids.sublist(ids.length - 6) : ids;
  final ultimosCiclos = [
    for (final id in ultimos)
      TotalCiclo(
        cicloId: id,
        etiqueta: _etiquetaDeId(id),
        total: Dinero(porCiclo[id]!),
        enCurso: id == ciclo.id,
      ),
  ];

  // ¿Qué día gastas más? Últimos 90 días, solo variables.
  final desde = DateTime(hoyDia.year, hoyDia.month, hoyDia.day - 89);
  final ventana = [
    for (final m in activos)
      if (esVariable(m) && !_dia(m.fecha).isBefore(desde) && !_dia(m.fecha).isAfter(hoyDia)) m,
  ];
  var primerDia = hoyDia;
  for (final m in ventana) {
    if (_dia(m.fecha).isBefore(primerDia)) primerDia = _dia(m.fecha);
  }
  final diasConDatos = ventana.isEmpty ? 0 : _diasEntre(primerDia, hoyDia) + 1;
  final sumaSemana = List<int>.filled(7, 0);
  final cuantosSemana = List<int>.filled(7, 0);
  for (var i = 0; i < diasConDatos; i++) {
    cuantosSemana[DateTime(primerDia.year, primerDia.month, primerDia.day + i).weekday - 1]++;
  }
  for (final m in ventana) {
    sumaSemana[m.fecha.weekday - 1] += m.monto.centavos;
  }
  final promedioSemana = [
    for (var i = 0; i < 7; i++) Dinero(cuantosSemana[i] == 0 ? 0 : sumaSemana[i] ~/ cuantosSemana[i]),
  ];

  // Dónde más gastas: solo variables (las fijas ya se conocen).
  final porTexto = <String, (String, int, int)>{};
  for (final m in variables) {
    final texto = m.descripcion.trim();
    if (texto.isEmpty) continue;
    final clave = normalizarTexto(texto);
    final (original, centavos, conteo) = porTexto[clave] ?? (texto, 0, 0);
    porTexto[clave] = (original, centavos + m.monto.centavos, conteo + 1);
  }
  final dondeMas = [
    for (final v in porTexto.values) GastoDescripcion(descripcion: v.$1, total: Dinero(v.$2), conteo: v.$3),
  ]..sort((a, b) => b.total.compareTo(a.total));

  final pequenos = [for (final m in variables) if (m.monto <= montoGastoPequeno) m];

  return ReporteAnalisis(
    ciclo: ciclo,
    diaDelCiclo: diaDelCiclo,
    diasDelCiclo: diasDelCiclo,
    gastado: gastado,
    gastadoVariables: gastadoVariables,
    gastadoFijas: gastado - gastadoVariables,
    presupuestoVariables: presupuestoVariables,
    presupuestoFijas: presupuestoFijas,
    promedioDiarioVariables: promedio,
    proyeccionVariables: proyeccion,
    porCategoria: porCategoria,
    acumuladoVariablesPorDia: acumuladoPorDia,
    variablesAnteriorMismoDia: anteriorMismoDia,
    contraAnterior: contraAnterior,
    ultimosCiclos: ultimosCiclos,
    promedioPorDiaSemana: promedioSemana,
    diasConDatos: diasConDatos,
    dondeMasGastas: dondeMas.length > 5 ? dondeMas.sublist(0, 5) : dondeMas,
    conTarjeta: _suma([for (final m in delCiclo) if (m.medio == MedioPago.tarjeta) m]),
    enEfectivo: _suma([for (final m in delCiclo) if (m.medio == MedioPago.efectivo) m]),
    gastosPequenos: pequenos.length,
    totalGastosPequenos: _suma(pequenos),
  );
}

Dinero _suma(Iterable<Movimiento> ms) => Dinero.suma(ms.map((m) => m.monto));

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

/// Días calendario de [a] a [b] (UTC para que el horario de verano no
/// reste un día).
int _diasEntre(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String _etiquetaDeId(String cicloId) {
  final partes = cicloId.split('-');
  final mes = partes.length == 2 ? int.tryParse(partes[1]) : null;
  return mes != null && mes >= 1 && mes <= 12 ? _etiquetasMes[mes - 1] : cicloId;
}
