import '../../core/ciclo.dart';
import '../../core/money.dart';

// Lo que el asistente puede saber de los números del usuario (spec-app-
// finanzas-v2.md §6.5, uso 4): un resumen que calcula la app. La IA solo lo
// lee; no ve cada gasto ni sus descripciones, y no calcula nada.

/// Una categoría en el ciclo: lo gastado y, si tiene, su presupuesto.
typedef CategoriaParaIA = ({String nombre, Dinero gastado, Dinero? presupuesto, bool fija});

/// Una cuenta con su saldo: positivo es dinero que hay; en una de crédito,
/// [debe] es lo que se debe.
typedef CuentaParaIA = ({String nombre, Dinero saldo, bool debe});

/// Un objetivo de ahorro y lo que lleva.
typedef ObjetivoParaIA = ({String nombre, Dinero meta, Dinero llevas});

final class DatosParaIA {
  final DateTime hoy;
  final Ciclo ciclo;
  final Dinero ingreso;
  final Dinero meta;

  /// Variables y fijas activas del ciclo, en cualquier orden.
  final List<CategoriaParaIA> categorias;

  /// Lo gastado en todo el ciclo pasado; `null` si no hubo.
  final Dinero? gastadoCicloPasado;
  final List<CuentaParaIA> cuentas;

  /// `null` si ninguna cuenta lleva saldo.
  final Dinero? patrimonio;
  final List<ObjetivoParaIA> objetivos;

  const DatosParaIA({
    required this.hoy,
    required this.ciclo,
    required this.ingreso,
    required this.meta,
    required this.categorias,
    this.gastadoCicloPasado,
    this.cuentas = const [],
    this.patrimonio,
    this.objetivos = const [],
  });
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String _dia(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

/// "$1,250" o "$1,250.50": sin centavos si son cero.
String _monto(Dinero d) {
  final texto = d.formateado();
  return texto.endsWith('.00') ? texto.substring(0, texto.length - 3) : texto;
}

/// Cuántas categorías se listan como mucho (las de más gasto): el modelo
/// del iPhone tiene poco espacio.
const maxCategoriasParaIA = 14;

/// El resumen en texto, corto y sin ambigüedad: cada cifra con su nombre.
String textoParaIA(DatosParaIA d) {
  final faltan = d.ciclo.diasParaTerminar(d.hoy);
  final diaDelCiclo = d.ciclo.diasDelCiclo - faltan;
  final variables = [for (final c in d.categorias) if (!c.fija) c]
    ..sort((a, b) => b.gastado.compareTo(a.gastado));
  final fijas = [for (final c in d.categorias) if (c.fija) c];
  final conPresupuesto = [for (final c in variables) if (c.presupuesto?.esPositivo ?? false) c];
  final gastadoCon = Dinero.suma(conPresupuesto.map((c) => c.gastado));
  final presupuesto = Dinero.suma(conPresupuesto.map((c) => c.presupuesto!));
  final gastadoTotal = Dinero.suma(d.categorias.map((c) => c.gastado));

  String renglon(CategoriaParaIA c) {
    final p = c.presupuesto;
    if (p == null || !p.esPositivo) return '- ${c.nombre}: gastado ${_monto(c.gastado)}, sin presupuesto';
    final quedan = p - c.gastado;
    return '- ${c.nombre}: gastado ${_monto(c.gastado)} de ${_monto(p)}, '
        '${quedan.esNegativo ? 'se pasó por ${_monto(quedan.absoluto)}' : 'le quedan ${_monto(quedan)}'}';
  }

  final lineas = <String>[
    'Hoy es ${_dia(d.hoy)}.',
    'Ciclo actual: del ${_dia(d.ciclo.fechaInicio)} al ${_dia(d.ciclo.fechaFin)}; '
        'va en el día $diaDelCiclo de ${d.ciclo.diasDelCiclo} y ${faltan == 1 ? 'falta 1 día' : 'faltan $faltan días'}.',
    'Ingreso del ciclo: ${_monto(d.ingreso)}. Meta de apartado (ahorro) del ciclo: ${_monto(d.meta)}.',
    'Total gastado en el ciclo (todo): ${_monto(gastadoTotal)}.',
    if (presupuesto.esPositivo)
      'Gastos variables con presupuesto: ${_monto(gastadoCon)} de ${_monto(presupuesto)}; '
          '${(presupuesto - gastadoCon).esNegativo ? 'se pasó por ${_monto((presupuesto - gastadoCon).absoluto)}' : 'quedan ${_monto(presupuesto - gastadoCon)}'}.',
    if (variables.isNotEmpty) 'Categorías variables (de mayor a menor gasto):',
    for (final c in variables.take(maxCategoriasParaIA)) renglon(c),
    if (variables.length > maxCategoriasParaIA) '- (y ${variables.length - maxCategoriasParaIA} más con menos gasto)',
    if (fijas.isNotEmpty) 'Gastos fijos (pagado de su monto):',
    for (final c in fijas)
      '- ${c.nombre}: ${_monto(c.gastado)} de ${_monto(c.presupuesto ?? const Dinero.cero())}'
          '${c.gastado.esPositivo ? '' : ' (aún sin pagar)'}',
    if (d.gastadoCicloPasado case final pasado?) 'Ciclo pasado completo, total gastado: ${_monto(pasado)}.',
    if (d.cuentas.isNotEmpty) 'Cuentas:',
    for (final c in d.cuentas)
      c.debe ? '- ${c.nombre}: debe ${_monto(c.saldo.absoluto)}' : '- ${c.nombre}: tiene ${_monto(c.saldo)}',
    if (d.patrimonio case final p?) 'Patrimonio (lo que tiene menos lo que debe): ${_monto(p)}.',
    if (d.objetivos.isNotEmpty) 'Objetivos de ahorro:',
    for (final o in d.objetivos) '- ${o.nombre}: lleva ${_monto(o.llevas)} de ${_monto(o.meta)}',
  ];
  return lineas.join('\n');
}

/// Las reglas que cambian cuando el asistente sí ve los números.
const reglasConDatos = '''
- Abajo vienen los DATOS de la persona, calculados por la app. Son los únicos números que conoces: úsalos tal cual para contestar sobre sus gastos, presupuestos, cuentas y objetivos.
- No hagas cuentas nuevas más allá de leer, comparar o sumar dos cifras que ya vienen. Si te piden algo que no está en los DATOS (un gasto en particular, otro ciclo, una fecha), di que eso se ve en la app y en dónde.
- Di las cifras con signo de pesos y sin inventar ninguna.''';
