import '../../core/money.dart';
import '../clasificacion/cascada_clasificacion.dart';
import '../clasificacion/normalizacion_texto.dart';
import '../clasificacion/regla_aprendida.dart';
import '../modelos/categoria.dart';
import '../modelos/cuenta.dart';
import '../modelos/movimiento.dart';
import 'parser_dictado.dart';

// Entender una frase dicha como un gasto (spec-app-finanzas-v2.md §5.6.3):
// el mismo intérprete para Siri y para el dictado de la captura. Primero
// las reglas (sin IA, en todos lados); luego, si hay, la IA solo completa
// lo que faltó, y cada dato que da se valida aquí antes de usarse.

/// Lo que se necesita saber de la cuenta del usuario para entender la frase.
final class ContextoDictado {
  /// Las categorías activas, en el orden en que se ofrecen.
  final List<Categoria> categorias;

  /// Las cuentas con que se registra (activas, sin ahorro), la más usada
  /// primero (`cuentasParaRegistrar(ordenarCuentasPorUso(...))`).
  final List<Cuenta> cuentas;

  /// La que se usa si la frase no dice otra (la del último gasto).
  final String? cuentaPorOmision;

  final DateTime hoy;
  final List<ReglaAprendida> reglas;
  final Map<String, String> historialComercios;

  const ContextoDictado({
    required this.categorias,
    required this.cuentas,
    required this.hoy,
    this.cuentaPorOmision,
    this.reglas = const [],
    this.historialComercios = const {},
  });

  /// El día de hoy, sin hora.
  DateTime get dia => DateTime(hoy.year, hoy.month, hoy.day);

  /// Lo más antiguo que se acepta: 62 días antes de hoy.
  DateTime get fechaMinima => dia.subtract(const Duration(days: diasAtras));

  static const diasAtras = 62;
}

/// Un dato del gasto que puso la IA (para decirlo y para las pruebas).
enum DatoGasto { monto, categoria, cuenta, fecha, descripcion }

/// Lo que se entendió de la frase. Lo que falta ([monto] o [categoriaId] en
/// `null`) se pregunta; nunca se inventa.
final class GastoEntendido {
  final String frase;
  final Dinero? monto;

  /// Los números que se dijeron (montos posibles). Si son varios y no se
  /// sabe cuál es, [monto] es `null`.
  final List<Dinero> montosDichos;
  final String descripcion;
  final String? categoriaId;
  final String? cuentaId;
  final DateTime fecha;

  /// Si la frase decía la fecha o la cuenta (si no, van las de omisión).
  final bool fechaDicha;
  final bool cuentaDicha;

  /// La frase traía más de un gasto ("50 de café y 200 de súper").
  final bool variosGastos;

  /// Lo que completó la IA.
  final Set<DatoGasto> deIA;

  const GastoEntendido({
    required this.frase,
    required this.monto,
    required this.montosDichos,
    required this.descripcion,
    required this.categoriaId,
    required this.cuentaId,
    required this.fecha,
    this.fechaDicha = false,
    this.cuentaDicha = false,
    this.variosGastos = false,
    this.deIA = const {},
  });

  bool get completo => monto != null && categoriaId != null && !variosGastos;

  GastoEntendido copyWith({
    Dinero? monto,
    String? descripcion,
    String? categoriaId,
    String? cuentaId,
    DateTime? fecha,
    bool? fechaDicha,
    bool? cuentaDicha,
    Set<DatoGasto>? deIA,
  }) =>
      GastoEntendido(
        frase: frase,
        monto: monto ?? this.monto,
        montosDichos: montosDichos,
        descripcion: descripcion ?? this.descripcion,
        categoriaId: categoriaId ?? this.categoriaId,
        cuentaId: cuentaId ?? this.cuentaId,
        fecha: fecha ?? this.fecha,
        fechaDicha: fechaDicha ?? this.fechaDicha,
        cuentaDicha: cuentaDicha ?? this.cuentaDicha,
        variosGastos: variosGastos,
        deIA: deIA ?? this.deIA,
      );

  Map<String, Object?> toJson() => {
        'frase': frase,
        'monto': monto?.centavos,
        'montosDichos': [for (final m in montosDichos) m.centavos],
        'descripcion': descripcion,
        'categoriaId': categoriaId,
        'cuentaId': cuentaId,
        'fecha': _iso(fecha),
        'fechaDicha': fechaDicha,
        'cuentaDicha': cuentaDicha,
        'variosGastos': variosGastos,
        'deIA': [for (final d in deIA) d.name],
      };

  factory GastoEntendido.fromJson(Map<String, Object?> json) => GastoEntendido(
        frase: json['frase'] as String,
        monto: json['monto'] == null ? null : Dinero(json['monto'] as int),
        montosDichos: [for (final m in json['montosDichos'] as List) Dinero(m as int)],
        descripcion: json['descripcion'] as String,
        categoriaId: json['categoriaId'] as String?,
        cuentaId: json['cuentaId'] as String?,
        fecha: DateTime.parse(json['fecha'] as String),
        fechaDicha: json['fechaDicha'] as bool? ?? false,
        cuentaDicha: json['cuentaDicha'] as bool? ?? false,
        variosGastos: json['variosGastos'] as bool? ?? false,
        deIA: {
          for (final d in json['deIA'] as List? ?? const [])
            ...DatoGasto.values.where((v) => v.name == d),
        },
      );
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

/// Lo que puede seguir a "el 12" para que sea una fecha y no parte de un
/// nombre ("el 7 eleven"): fin, coma o una palabra de enlace.
const _despuesDeFecha = r'(?=\s*(?:$|[,.;]|\s(?:en|con|y|de|del|que|pague|gaste|por|a|al|para|pasado)\b))';

final _reFechas = <(RegExp, DateTime? Function(RegExpMatch, DateTime))>[
  (RegExp(r'\b(?:antier|anteayer|antes de ayer)\b'), (_, hoy) => hoy.subtract(const Duration(days: 2))),
  (RegExp(r'\b(?:ayer|anoche)\b'), (_, hoy) => hoy.subtract(const Duration(days: 1))),
  (RegExp(r'\b(?:hoy|esta manana|esta tarde|esta noche)\b'), (_, hoy) => hoy),
  (
    RegExp('\\b(?:el\\s+)?(?:pasado\\s+)?(${_dias.join('|')})(?:\\s+pasado)?\\b'),
    (m, hoy) {
      // El más reciente antes de hoy: "el lunes" dicho un lunes es el de
      // la semana pasada.
      final objetivo = _dias.indexOf(m.group(1)!) + 1;
      var atras = (hoy.weekday - objetivo) % 7;
      if (atras == 0) atras = 7;
      return hoy.subtract(Duration(days: atras));
    },
  ),
  (
    RegExp('\\bel\\s+(?:dia\\s+)?(\\d{1,2}|primero)(?:\\s+de\\s+(${_meses.join('|')})\\b|$_despuesDeFecha)'),
    (m, hoy) {
      final dia = m.group(1) == 'primero' ? 1 : int.parse(m.group(1)!);
      if (dia < 1 || dia > 31) return null;
      final mesDicho = m.group(2);
      var anio = hoy.year;
      var mes = mesDicho == null ? hoy.month : _meses.indexOf(mesDicho) + 1;
      if (mesDicho == null && dia > hoy.day) mes -= 1;
      if (mes < 1) {
        mes += 12;
        anio -= 1;
      }
      var fecha = DateTime(anio, mes, dia);
      if (fecha.month != (mes - 1) % 12 + 1) return null; // 31 de un mes de 30
      if (fecha.isAfter(hoy)) fecha = DateTime(anio - 1, mes, dia);
      return fecha;
    },
  ),
];

/// Quita el tramo [inicio, fin) de [texto] y deja un solo espacio.
String _quitar(String texto, int inicio, int fin) =>
    '${texto.substring(0, inicio)} ${texto.substring(fin)}'.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Palabras del nombre de una cuenta que no la distinguen de otras.
const _genericas = {
  'tarjeta', 'cuenta', 'debito', 'credito', 'efectivo', 'platino', 'oro', 'clasica', //
  'nomina', 'mi', 'la', 'el', 'de', 'del',
};

/// Lo que se dice antes de una cuenta: "con la", "en mi", "pagué con la"…
const _antesDeCuenta = r'(?:(?:pague|pago)\s+)?(?:con|en|de|desde)\s+(?:(?:la|el|mi|mis)\s+)?(?:tarjeta\s+(?:de\s+)?)?';

/// La cuenta que nombra la frase (normalizada): su nombre completo o una
/// palabra que solo ella tiene. Devuelve la cuenta y el tramo a quitar.
(Cuenta, int, int)? _cuentaNombrada(String norm, List<Cuenta> cuentas) {
  (Cuenta, int, int)? mejor;
  var mejorLargo = 0;
  final palabrasDe = {
    for (final c in cuentas)
      c.id: [
        for (final p in normalizarTexto(c.nombre).split(RegExp(r'[^a-z0-9ñ]+')))
          if (p.length >= 3 && !_genericas.contains(p)) p,
      ],
  };
  for (final c in cuentas) {
    final nombre = normalizarTexto(c.nombre).trim();
    final candidatos = <String>[
      if (nombre.isNotEmpty) nombre,
      for (final p in palabrasDe[c.id]!)
        if (cuentas.where((o) => o.id != c.id).every((o) => !palabrasDe[o.id]!.contains(p))) p,
    ];
    for (final cand in candidatos) {
      final re = RegExp('(?:$_antesDeCuenta)?\\b${RegExp.escape(cand)}\\b');
      final m = re.firstMatch(norm);
      if (m != null && cand.length > mejorLargo) {
        mejor = (c, m.start, m.end);
        mejorLargo = cand.length;
      }
    }
  }
  return mejor;
}

/// "en efectivo" / "con tarjeta" / "con la de crédito": la primera cuenta
/// de ese tipo, la más usada.
(Cuenta, int, int)? _cuentaPorTipo(String norm, List<Cuenta> cuentas, String? porOmision) {
  final efectivo = RegExp(r'(?:(?:pague|pago)\s+)?(?:en|con)\s+efectivo\b|\befectivo\b').firstMatch(norm);
  if (efectivo != null) {
    final c = cuentas.where((c) => c.tipo == TipoCuenta.efectivo).firstOrNull;
    if (c != null) return (c, efectivo.start, efectivo.end);
  }
  final credito = RegExp('(?:$_antesDeCuenta)?\\b(?:de\\s+)?credito\\b').firstMatch(norm);
  if (credito != null) {
    final c = cuentas.where((c) => c.tipo == TipoCuenta.credito).firstOrNull;
    if (c != null) return (c, credito.start, credito.end);
  }
  final debito = RegExp('(?:$_antesDeCuenta)?\\b(?:de\\s+)?debito\\b').firstMatch(norm);
  if (debito != null) {
    final c = cuentas.where((c) => c.tipo == TipoCuenta.debito).firstOrNull;
    if (c != null) return (c, debito.start, debito.end);
  }
  final tarjeta = RegExp(r'(?:(?:pague|pago)\s+)?(?:con|en)\s+(?:la\s+|mi\s+)?tarjeta\b').firstMatch(norm);
  if (tarjeta != null) {
    // La de omisión si ya es tarjeta; si no, la primera que lo sea.
    final omision = cuentas.where((c) => c.id == porOmision && c.tipo.medio == MedioPago.tarjeta).firstOrNull;
    final c = omision ?? cuentas.where((c) => c.tipo.medio == MedioPago.tarjeta).firstOrNull;
    if (c != null) return (c, tarjeta.start, tarjeta.end);
  }
  return null;
}

const _articulos = {'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'mi', 'mis'};

/// Sin artículos sueltos al inicio ni al final, con mayúscula inicial.
String _limpiarDescripcion(String texto) {
  final palabras = texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  while (palabras.isNotEmpty && _articulos.contains(normalizarTexto(palabras.first))) {
    palabras.removeAt(0);
  }
  while (palabras.isNotEmpty && _articulos.contains(normalizarTexto(palabras.last))) {
    palabras.removeLast();
  }
  final limpio = palabras.join(' ').trim();
  return limpio.isEmpty ? '' : limpio[0].toUpperCase() + limpio.substring(1);
}

/// Entiende [frase] con reglas, sin IA (spec §5.6.3).
GastoEntendido interpretarFraseGasto(String frase, ContextoDictado ctx) {
  var texto = frase.trim().replaceAll(RegExp(r'\s+'), ' ');
  // Misma longitud: lo que se encuentra en la normalizada se quita de la
  // original en las mismas posiciones.
  var norm = normalizarTexto(texto);

  // 1. La fecha.
  var fecha = ctx.dia;
  var fechaDicha = false;
  for (final (re, calcular) in _reFechas) {
    final m = re.firstMatch(norm);
    if (m == null) continue;
    final f = calcular(m, ctx.dia);
    if (f == null) continue;
    texto = _quitar(texto, m.start, m.end);
    norm = normalizarTexto(texto);
    if (!f.isBefore(ctx.fechaMinima) && !f.isAfter(ctx.dia)) {
      fecha = f;
      fechaDicha = true;
    }
    break;
  }

  // 2. La cuenta: por su nombre o por su tipo.
  var cuentaId = ctx.cuentas.where((c) => c.id == ctx.cuentaPorOmision).firstOrNull?.id ?? ctx.cuentas.firstOrNull?.id;
  var cuentaDicha = false;
  final cuenta = _cuentaNombrada(norm, ctx.cuentas) ?? _cuentaPorTipo(norm, ctx.cuentas, cuentaId);
  if (cuenta != null) {
    cuentaId = cuenta.$1.id;
    cuentaDicha = true;
    texto = _quitar(texto, cuenta.$2, cuenta.$3);
  }

  // 3. Monto, descripción y categoría por nombre: el parser de siempre.
  final gastos = parsearDictado(texto, categorias: ctx.categorias);
  final varios = gastos.length > 1;
  final gasto = gastos.firstOrNull;
  final montosDichos = gasto == null ? const <Dinero>[] : (gasto.monto == null ? gasto.montosAmbiguos : [gasto.monto!]);
  var descripcion = _limpiarDescripcion(gasto?.descripcion ?? texto.replaceFirst(
        RegExp(r'^\s*(gast[eé]|pagu[eé]|compr[eé])\s+', caseSensitive: false),
        '',
      ));

  // 4. Categoría: por su nombre en la frase; si no, la cascada (reglas e
  // historial de comercios, §6.1).
  var categoriaId = gasto?.categoriaId;
  if (categoriaId == null && descripcion.isNotEmpty) {
    final cascada = clasificar(texto: descripcion, reglasUsuario: ctx.reglas, historialComercios: ctx.historialComercios);
    if (cascada.resuelto && ctx.categorias.any((c) => c.id == cascada.categoriaId && c.activa)) {
      categoriaId = cascada.categoriaId;
    }
  }
  // Si la descripción quedó igual al nombre de la categoría, se usa ese.
  if (categoriaId != null) {
    final cat = ctx.categorias.where((c) => c.id == categoriaId).firstOrNull;
    if (cat != null && (descripcion.isEmpty || normalizarTexto(descripcion) == normalizarTexto(cat.nombre))) {
      descripcion = cat.nombre;
    }
  }

  return GastoEntendido(
    frase: frase,
    monto: gasto?.monto,
    montosDichos: montosDichos,
    descripcion: descripcion,
    categoriaId: categoriaId,
    cuentaId: cuentaId,
    fecha: fecha,
    fechaDicha: fechaDicha,
    cuentaDicha: cuentaDicha,
    variosGastos: varios,
  );
}

/// La categoría activa cuyo nombre es [dicho] (sin acentos ni mayúsculas,
/// y sin el emoji); si no hay exacta, la única que lo contiene o está
/// contenida en él. `null` si no hay o hay varias.
Categoria? categoriaPorNombre(String dicho, List<Categoria> categorias) {
  final d = _soloLetras(dicho);
  if (d.isEmpty) return null;
  final activas = categorias.where((c) => c.activa).toList();
  final exacta = activas.where((c) => _soloLetras(c.nombre) == d).toList();
  if (exacta.length == 1) return exacta.single;
  final parecidas = activas.where((c) {
    final n = _soloLetras(c.nombre);
    return n.isNotEmpty && (n.contains(d) && d.length >= 3 || d.contains(n) && n.length >= 3);
  }).toList();
  if (parecidas.length == 1) return parecidas.single;
  // "Súper/Comida": cualquiera de sus partes.
  final porParte = activas.where((c) => normalizarTexto(c.nombre)
      .split(RegExp(r'[/,]| y '))
      .map(_soloLetras)
      .any((p) => p.length >= 3 && (p == d || d.contains(p)))).toList();
  return porParte.length == 1 ? porParte.single : null;
}

String _soloLetras(String texto) =>
    normalizarTexto(texto).replaceAll(RegExp(r'[^a-z0-9ñ ]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// La categoría que propuso la IA para [base] (spec §5.6.3), si las reglas
/// no la resolvieron y es una categoría activa. La IA solo ayuda con la
/// categoría: en las pruebas con Apple Intelligence inventaba cuenta y
/// fecha cuando no se dijeron, elegía mal entre dos montos ("doce tacos de
/// treinta" → \$30) y adornaba la descripción. Monto, fecha, cuenta y
/// descripción son siempre de las reglas; lo que falte se pregunta.
GastoEntendido completarConIA(GastoEntendido base, String? categoriaIA, ContextoDictado ctx) {
  if (base.categoriaId != null || categoriaIA == null) return base;
  final cat = categoriaPorNombre(categoriaIA, ctx.categorias);
  if (cat == null) return base;
  final nombreAntes = base.descripcion;
  return base.copyWith(
    categoriaId: cat.id,
    descripcion: nombreAntes.isEmpty ? cat.nombre : nombreAntes,
    deIA: {...base.deIA, DatoGasto.categoria},
  );
}

/// Lo que se elige cuando ninguna categoría corresponde.
const ningunaCategoria = 'Ninguna';

/// Instrucciones para la IA (iguales para Apple y para las de clave).
const instruccionesIAGasto = """
Clasificas UN gasto de una persona en México en una de sus categorías de presupuesto.
Piensa en qué se compró y para quién (un perro o gato es Mascotas; comer fuera, cafés, bares y cine son salidas; Uber, Didi, taxi y estacionamiento son transporte), pero elige solo entre las categorías de la lista.
Si ninguna categoría corresponde de verdad, elige "$ningunaCategoria".
Responde solo con el nombre exacto de la categoría.""";

/// Los nombres entre los que la IA elige: las categorías activas y
/// [ningunaCategoria].
List<String> opcionesIAGasto(ContextoDictado ctx) => [
      for (final c in ctx.categorias.where((c) => c.activa)) c.nombre,
      ningunaCategoria,
    ];

/// El mensaje con la frase y las categorías.
String mensajeIAGasto(String frase, ContextoDictado ctx) =>
    'Categorías: ${[for (final c in ctx.categorias.where((c) => c.activa)) c.nombre].join(', ')}.\n'
    'Gasto: "$frase"';
