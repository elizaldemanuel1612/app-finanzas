import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../presupuesto/resumen_variables.dart';
import '../rollups/rollup.dart';
import 'interpretar_gasto.dart';

// Lo que Siri dice (spec-app-finanzas-v2.md §5.6.3). Frases cortas, para
// oírse: montos sin ".00" y fechas en palabras.

/// "$230", "$1,250.50": sin centavos si son cero.
String montoHablado(Dinero d) {
  final texto = d.formateado();
  return texto.endsWith('.00') ? texto.substring(0, texto.length - 3) : texto;
}

/// "Súper/Comida" se lee "Súper y Comida".
String nombreHablado(String nombre) => nombre.replaceAll(RegExp(r'\s*/\s*'), ' y ').trim();

const _diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "hoy", "ayer", "antier", "el lunes 9" (esta semana) o "el 3 de octubre".
String fechaHablada(DateTime fecha, DateTime hoy) {
  final f = DateTime(fecha.year, fecha.month, fecha.day);
  final h = DateTime(hoy.year, hoy.month, hoy.day);
  final atras = h.difference(f).inDays;
  if (atras == 0) return 'hoy';
  if (atras == 1) return 'ayer';
  if (atras == 2) return 'antier';
  if (atras > 0 && atras < 7) return 'el ${_diasSemana[f.weekday - 1]} ${f.day}';
  return 'el ${f.day} de ${_meses[f.month - 1]}';
}

/// "¿Registro $230 en Súper con BBVA, ayer?"
String confirmacionDeGasto(GastoEntendido g, ContextoDictado ctx) {
  final categoria = ctx.categorias.where((c) => c.id == g.categoriaId).firstOrNull;
  final cuenta = ctx.cuentas.where((c) => c.id == g.cuentaId).firstOrNull;
  final partes = [
    '¿Registro ${montoHablado(g.monto!)}',
    if (categoria != null) ' en ${nombreHablado(categoria.nombre)}',
    if (cuenta != null) ' con ${cuenta.nombre}',
    ', ${fechaHablada(g.fecha, ctx.hoy)}?',
  ];
  return partes.join();
}

/// Qué decir cuando falta algo, o `null` si está completo.
String? loQueFalta(GastoEntendido g, ContextoDictado ctx) {
  if (g.variosGastos) return 'Dime un gasto a la vez, por ejemplo: 230 en el súper.';
  if (g.monto == null) {
    if (g.montosDichos.length > 1) {
      final dichos = [for (final m in g.montosDichos) montoHablado(m)];
      final lista = '${dichos.sublist(0, dichos.length - 1).join(', ')} y ${dichos.last}';
      return 'Escuché $lista y no sé cuál es el total. Dímelo otra vez con el total.';
    }
    return 'No entendí cuánto fue. Dímelo así: 230 en el súper.';
  }
  if (g.categoriaId == null) return preguntaDeCategoria(ctx);
  return null;
}

/// "¿En qué categoría va? Por ejemplo: Súper, Salidas o Gasolina."
String preguntaDeCategoria(ContextoDictado ctx) {
  final ejemplos = [for (final c in ctx.categorias.where((c) => c.activa).take(3)) nombreHablado(c.nombre)];
  if (ejemplos.isEmpty) return '¿En qué categoría va?';
  final lista = ejemplos.length == 1 ? ejemplos.single : '${ejemplos.sublist(0, ejemplos.length - 1).join(', ')} o ${ejemplos.last}';
  return '¿En qué categoría va? Por ejemplo: $lista.';
}

/// Lo que Siri dice ya registrado, con cómo va esa categoría en su ciclo
/// (como el aviso de Inicio): "Listo. Te quedan $1,170 en Súper."
String registradoEn(Categoria categoria, Rollup? rollup) {
  final nombre = nombreHablado(categoria.nombre);
  final presupuesto = rollup?.presupuestoCentavos;
  if (categoria is! CategoriaVariable || rollup == null || presupuesto == null) return 'Listo, quedó en $nombre.';
  if (!presupuesto.esPositivo) return 'Listo. Llevas ${montoHablado(rollup.totalCentavos)} en $nombre.';
  final quedan = presupuesto - rollup.totalCentavos;
  return quedan.esNegativo
      ? 'Listo. Te pasaste por ${montoHablado(quedan.absoluto)} en $nombre.'
      : 'Listo. Te quedan ${montoHablado(quedan)} en $nombre.';
}

/// "Llevas $4,860 de $12,000 este ciclo. Te quedan $7,140 y faltan 26 días."
String resumenHablado(ResumenVariables r, int faltan) {
  final dias = switch (faltan) {
    0 => 'hoy cierra tu ciclo',
    1 => 'falta 1 día',
    _ => 'faltan $faltan días',
  };
  if (r.soloRegistro) return 'Llevas ${montoHablado(r.gastado)} este ciclo y $dias.';
  final quedan = r.quedan;
  final base = 'Llevas ${montoHablado(r.gastadoConPresupuesto)} de ${montoHablado(r.presupuesto)} este ciclo.';
  final extra = r.gastadoSinPresupuesto.esPositivo
      ? ' Además, ${montoHablado(r.gastadoSinPresupuesto)} en categorías sin presupuesto.'
      : '';
  return quedan.esNegativo
      ? '$base Te pasaste por ${montoHablado(quedan.absoluto)} y $dias.$extra'
      : '$base Te quedan ${montoHablado(quedan)} y $dias.$extra';
}
