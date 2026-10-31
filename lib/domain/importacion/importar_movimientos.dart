import 'dart:convert';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../clasificacion/cascada_clasificacion.dart';
import '../clasificacion/historial_comercios.dart';
import '../clasificacion/normalizacion_texto.dart';
import '../clasificacion/regla_aprendida.dart';
import '../exportacion/exportar_csv.dart';
import '../migracion/movimiento_migrado.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'csv.dart';
import 'emoji_sugerido.dart';
import 'mapeo_columnas.dart';

/// A dónde va un gasto sin categoría que tampoco se pudo adivinar por su
/// descripción. Antes era "Importado" (2026-10-29).
const categoriaSinCategoria = 'Sin categoría';

/// Un renglón del CSV que no se pudo convertir en movimiento — [numeroDeRenglon]
/// es 1-based contando el encabezado como renglón 1, tal como lo vería
/// alguien abriendo el archivo en una hoja de cálculo. También sirve para
/// los avisos: renglones que sí se importan, pero con un valor que no se
/// reconoció y se reemplazó por el de omisión.
final class RenglonConProblema {
  final int numeroDeRenglon;
  final String motivo;

  const RenglonConProblema({required this.numeroDeRenglon, required this.motivo});

  @override
  String toString() => 'Renglón $numeroDeRenglon: $motivo';
}

/// Lo que arma la vista previa de "Importar gastos" (Bloque B) antes de
/// que el usuario confirme: movimientos listos para guardar, categorías
/// que hay que crear primero (o a las que solo les llega su emoji),
/// renglones que no se pudieron leer, avisos, y el total por ciclo para
/// que el usuario vea a qué meses afecta.
final class ResultadoImportacion {
  final List<Movimiento> movimientos;
  final List<Categoria> categoriasPorCrear;

  /// Categorías que ya existían y cuyo plan o emoji cambia con el archivo.
  final List<Categoria> categoriasPorActualizar;

  /// Categorías de la cuenta que no vienen en el archivo: se eliminan.
  final List<Categoria> categoriasPorEliminar;

  /// Todas las categorías que quedan: las del archivo.
  final List<Categoria> categoriasFinales;

  /// Movimientos de la cuenta que no vienen en el archivo: se eliminan.
  final int movimientosPorEliminar;
  final List<RenglonConProblema> renglonesConProblema;
  final List<RenglonConProblema> avisos;
  final Map<String, Dinero> totalesPorCiclo;

  /// Renglones sin categoría a los que se les adivinó por su descripción.
  final int categoriasAdivinadas;

  /// Renglones sin categoría que no se pudieron adivinar: van a
  /// [categoriaSinCategoria] y el usuario los mueve después.
  final int sinCategoria;

  const ResultadoImportacion({
    required this.movimientos,
    required this.categoriasPorCrear,
    this.categoriasPorActualizar = const [],
    this.categoriasPorEliminar = const [],
    this.categoriasFinales = const [],
    this.movimientosPorEliminar = 0,
    required this.renglonesConProblema,
    this.avisos = const [],
    required this.totalesPorCiclo,
    this.categoriasAdivinadas = 0,
    this.sinCategoria = 0,
  });

  /// Hay datos de la cuenta que se perderían: pide confirmación.
  bool get eliminaDatos => movimientosPorEliminar > 0 || categoriasPorEliminar.isNotEmpty;

  /// Cuántos movimientos llegan anulados (exportados así): se guardan para
  /// no perderlos, pero no cuentan en ningún total.
  int get anulados => movimientos.where((m) => m.estado == EstadoMovimiento.anulado).length;
}

/// Lee [contenidoCsv] y arma la vista previa de importación. Nunca escribe
/// nada — quien llama decide, con esta vista previa en mano, si guarda los
/// movimientos y las categorías nuevas.
///
/// Columnas (ver `ayudaColumnasCsv` en `plantilla_csv.dart`): fecha y monto
/// obligatorias; categoría, emoji, descripción, medio, estado, cómo se
/// registró e ID opcionales. Los valores se aceptan en las palabras que
/// escribe la exportación ("Tarjeta", "Anulado") y en sinónimos comunes;
/// un estado o medio que no se reconoce no tumba el renglón: se importa con
/// el valor de omisión y queda en [ResultadoImportacion.avisos].
///
/// Un renglón sin categoría se clasifica por su descripción con la misma
/// cascada que la captura (spec-app-finanzas-v2.md §6.1, Niveles 1 y 2):
/// [reglasUsuario], luego [historialComercios] (comercio → id de categoría
/// de los movimientos que ya tiene el usuario) y, al final, lo que el
/// propio archivo enseña en sus renglones que sí traen categoría. Lo que
/// no se resuelve va a [categoriaSinCategoria] — nunca se inventa una
/// categoría en la que no se confía (spec §0.4).
///
/// **Reemplaza, no suma (spec-app-finanzas-v2.md §7.4):** quien llama guarda
/// [ResultadoImportacion.categoriasFinales] y
/// [ResultadoImportacion.movimientos]; todo lo demás se elimina. Un
/// movimiento con el mismo ID que uno de [movimientosExistentes] toma los
/// valores del archivo pero conserva su `cicloId` (regla #5) y lo que el
/// archivo no lleva (foto, ticket).
///
/// Un renglón con Fecha y Monto vacíos y con categoría solo declara esa
/// categoría. El plan (presupuesto, tipo…) vacío conserva el de la categoría
/// existente del mismo nombre, que además conserva su id.
///
/// Cada movimiento se construye con [crearMovimientoMigrado]. Su
/// `clientId` es la columna ID si viene (lo que escribe la exportación:
/// reimportar en la misma cuenta no duplica) o, si no, una huella estable
/// del contenido del archivo más el número de renglón
/// (`IMP-<huella>-<renglón>`): volver a importar el mismo archivo produce
/// los mismos `clientId`, y `MovimientoRepositorio.guardar` ya es
/// idempotente por `clientId` (regla no negociable #2). Dos archivos con
/// contenido distinto producen huellas distintas.
Resultado<ResultadoImportacion> previsualizarImportacion({
  required String contenidoCsv,
  required CalculadoraCiclo calculadoraCiclo,
  required List<Categoria> categoriasExistentes,
  List<ReglaAprendida> reglasUsuario = const [],
  Map<String, String> historialComercios = const {},
  List<Movimiento> movimientosExistentes = const [],
}) {
  final filas = leerCsv(contenidoCsv, separador: detectarSeparador(contenidoCsv));
  // Las instrucciones de la plantilla pueden seguir en el archivo. El número
  // de renglón se conserva: es el que se ve al abrirlo en una hoja de cálculo.
  final utiles = [
    for (final (indice, renglon) in filas.indexed)
      if (!esRenglonDeInstrucciones(renglon)) (numero: indice + 1, celdas: renglon),
  ];
  if (utiles.isEmpty) {
    return const Falla('El archivo está vacío.');
  }

  final mapeo = detectarColumnas(utiles.first.celdas);
  if (!mapeo.esImportable) {
    return const Falla(
      'No encontré columnas de fecha y monto. Revisa el formato con la plantilla de ejemplo.',
    );
  }

  final huella = huellaEstable(contenidoCsv);
  final existentesPorNombre = {
    for (final c in categoriasExistentes) normalizarTexto(c.nombre): c,
  };
  final existentesPorClientId = {for (final m in movimientosExistentes) m.clientId: m};
  final planes = <String, _PlanCategoria>{};
  final idsVistos = <String>{};
  final movimientos = <Movimiento>[];
  final problemas = <RenglonConProblema>[];
  final avisos = <RenglonConProblema>[];
  final totalesPorCiclo = <String, Dinero>{};
  var adivinadas = 0;
  var sinCategoria = 0;

  final existentesPorId = {for (final c in categoriasExistentes) c.id: c};
  // Lo que enseña el propio archivo: descripción → nombre de categoría,
  // de los renglones que traen las dos.
  final historialDelArchivo = construirHistorialComercios([
    for (final renglon in utiles.skip(1))
      if (_campo(renglon.celdas, mapeo[CampoImportado.categoria]).isNotEmpty)
        ObservacionComercio(
          _campo(renglon.celdas, mapeo[CampoImportado.descripcion]),
          separarEmojiDelNombre(_campo(renglon.celdas, mapeo[CampoImportado.categoria])).nombre,
        ),
  ]);

  String? adivinarPorDescripcion(String descripcion) {
    final porCuenta = clasificar(
      texto: descripcion,
      reglasUsuario: reglasUsuario,
      historialComercios: historialComercios,
    );
    final existente = existentesPorId[porCuenta.categoriaId];
    if (existente != null) return existente.nombre;
    return clasificar(
      texto: descripcion,
      reglasUsuario: const [],
      historialComercios: historialDelArchivo,
    ).categoriaId;
  }

  for (final (numero: numeroDeRenglon, celdas: renglon) in utiles.skip(1)) {
    if (renglon.every((celda) => celda.trim().isEmpty)) continue;
    String campo(CampoImportado c) => _campo(renglon, mapeo[c]);
    void avisar(String motivo) =>
        avisos.add(RenglonConProblema(numeroDeRenglon: numeroDeRenglon, motivo: motivo));

    void declararCategoria(String nombre, String? emojiPegado) {
      final plan = planes.putIfAbsent(
        normalizarTexto(nombre),
        () => _PlanCategoria(nombre: nombre, renglon: numeroDeRenglon),
      );
      plan.emojiDelArchivo ??= _noVacio(campo(CampoImportado.emoji)) ?? emojiPegado;
      _leerPlan(plan, campo, avisar);
    }

    final categoriaDelRenglon = separarEmojiDelNombre(campo(CampoImportado.categoria));
    if (campo(CampoImportado.fecha).isEmpty &&
        campo(CampoImportado.monto).isEmpty &&
        categoriaDelRenglon.nombre.isNotEmpty) {
      declararCategoria(categoriaDelRenglon.nombre, categoriaDelRenglon.emoji);
      continue;
    }

    final textoFecha = campo(CampoImportado.fecha);
    final fecha = _parsearFecha(textoFecha);
    if (fecha == null) {
      problemas.add(RenglonConProblema(
        numeroDeRenglon: numeroDeRenglon,
        motivo: 'No pude leer la fecha "$textoFecha". Usa 2026-08-05 o 05/08/2026.',
      ));
      continue;
    }

    final textoMonto = campo(CampoImportado.monto);
    final monto = _parsearMonto(textoMonto);
    if (monto == null) {
      problemas.add(RenglonConProblema(
        numeroDeRenglon: numeroDeRenglon,
        motivo: 'No pude leer el monto "$textoMonto". Usa solo números, como 450.00.',
      ));
      continue;
    }

    final separado = categoriaDelRenglon;
    final descripcion = campo(CampoImportado.descripcion);
    final adivinada = separado.nombre.isEmpty ? adivinarPorDescripcion(descripcion) : null;
    final nombreCategoria = separado.nombre.isNotEmpty
        ? separado.nombre
        : adivinada ?? categoriaSinCategoria;
    declararCategoria(nombreCategoria, separado.emoji);
    final existenteDelNombre = existentesPorNombre[normalizarTexto(nombreCategoria)];
    final categoriaId = existenteDelNombre?.id ?? _idNuevo(nombreCategoria);

    final textoMedio = campo(CampoImportado.medio);
    final medio = _leerMedio(textoMedio);
    if (medio == null) avisar('Medio de pago "$textoMedio" no reconocido; se usó Tarjeta.');

    final textoEstado = campo(CampoImportado.estado);
    final estado = _leerEstado(textoEstado);
    if (estado == null) avisar('Estado "$textoEstado" no reconocido; se importó como Activo.');

    var clientId = campo(CampoImportado.id);
    if (clientId.isNotEmpty && !idsVistos.add(clientId)) {
      avisar('El ID "$clientId" se repite en el archivo; este renglón se importó como otro gasto.');
      clientId = '';
    }
    if (clientId.isEmpty) clientId = 'IMP-$huella-$numeroDeRenglon';

    final resultado = crearMovimientoMigrado(
      idOrigen: clientId,
      fecha: fecha,
      calculadoraCiclo: calculadoraCiclo,
      monto: monto,
      categoriaId: categoriaId,
      medio: medio ?? MedioPago.tarjeta,
      descripcion: descripcion.isEmpty ? nombreCategoria : descripcion,
      estado: estado ?? EstadoMovimiento.activo,
      origenCaptura: _leerOrigen(campo(CampoImportado.origen)),
    );
    final textoOrigen = campo(CampoImportado.origen);

    switch (resultado) {
      case Falla(:final mensaje):
        problemas.add(RenglonConProblema(numeroDeRenglon: numeroDeRenglon, motivo: mensaje));
      case Exito(valor: final leido):
        final previo = existentesPorClientId[leido.clientId];
        final valor = previo == null
            ? leido
            : previo.copyWith(
                fecha: leido.fecha,
                periodoNatural: leido.periodoNatural,
                monto: leido.monto,
                categoriaId: leido.categoriaId,
                medio: leido.medio,
                descripcion: leido.descripcion,
                estado: leido.estado,
                origenCaptura: textoOrigen.isEmpty ? previo.origenCaptura : leido.origenCaptura,
              );
        movimientos.add(valor);
        if (separado.nombre.isEmpty) adivinada != null ? adivinadas++ : sinCategoria++;
        if (valor.estado == EstadoMovimiento.activo) {
          totalesPorCiclo[valor.cicloId] =
              (totalesPorCiclo[valor.cicloId] ?? const Dinero.cero()) + valor.monto;
        }
    }
  }

  final finales = <Categoria>[];
  final porCrear = <Categoria>[];
  final porActualizar = <Categoria>[];
  for (final e in planes.entries) {
    final existente = existentesPorNombre[e.key];
    final categoria = _construirCategoria(e.value, existente, avisos);
    finales.add(categoria);
    if (existente == null) {
      porCrear.add(categoria);
    } else if (jsonEncode(existente.toJson()) != jsonEncode(categoria.toJson())) {
      porActualizar.add(categoria);
    }
  }
  final clientIdsDelArchivo = {for (final m in movimientos) m.clientId};

  return Exito(ResultadoImportacion(
    movimientos: movimientos,
    categoriasPorCrear: porCrear,
    categoriasPorActualizar: porActualizar,
    categoriasPorEliminar: [
      for (final c in categoriasExistentes)
        if (!planes.containsKey(normalizarTexto(c.nombre))) c,
    ],
    categoriasFinales: finales,
    movimientosPorEliminar:
        movimientosExistentes.where((m) => !clientIdsDelArchivo.contains(m.clientId)).length,
    renglonesConProblema: problemas,
    avisos: avisos,
    totalesPorCiclo: totalesPorCiclo,
    categoriasAdivinadas: adivinadas,
    sinCategoria: sinCategoria,
  ));
}

/// Lo que el archivo dice de una categoría; `null` es "no lo dijo".
final class _PlanCategoria {
  final String nombre;
  final int renglon;
  String? emojiDelArchivo;
  Dinero? monto;
  bool? fija;
  int? dia;
  bool? necesaria;
  bool? activa;

  _PlanCategoria({required this.nombre, required this.renglon});
}

String? _noVacio(String texto) => texto.isEmpty ? null : texto;

String _idNuevo(String nombre) => 'imp-${_slug(normalizarTexto(nombre))}';

/// Lee el plan de un renglón. Si contradice lo ya leído de la categoría
/// gana lo primero; un valor inválido se ignora. Ambos dejan aviso.
void _leerPlan(
  _PlanCategoria plan,
  String Function(CampoImportado) campo,
  void Function(String) avisar,
) {
  T? combinar<T>(T? actual, T? nuevo, String etiqueta) {
    if (actual != null && nuevo != null && actual != nuevo) {
      avisar('$etiqueta de "${plan.nombre}" no coincide con otro renglón; se usó el primero.');
    }
    return actual ?? nuevo;
  }

  final textoMonto = campo(CampoImportado.presupuesto);
  final monto = textoMonto.isEmpty ? null : _parsearMonto(textoMonto);
  if (textoMonto.isNotEmpty && (monto == null || monto.centavos < 0)) {
    avisar('Presupuesto "$textoMonto" no reconocido; se ignoró.');
  } else {
    plan.monto = combinar(plan.monto, monto, 'El presupuesto');
  }

  final textoTipo = normalizarTexto(campo(CampoImportado.tipo));
  final fija = switch (textoTipo) { 'fija' || 'fijo' => true, 'variable' => false, _ => null };
  if (textoTipo.isNotEmpty && fija == null) avisar('Tipo "$textoTipo" no reconocido; se ignoró.');
  plan.fija = combinar(plan.fija, fija, 'El tipo');

  final textoDia = campo(CampoImportado.diaDeCobro);
  final dia = int.tryParse(textoDia);
  if (dia != null && dia >= 1 && dia <= 31) {
    plan.dia = combinar(plan.dia, dia, 'El día de cobro');
  } else if (textoDia.isNotEmpty) {
    avisar('Día de cobro "$textoDia" no reconocido; se ignoró.');
  }

  bool? siNo(CampoImportado c) {
    final t = normalizarTexto(campo(c));
    if (t.isEmpty) return null;
    if (t == 'si' || t == 'true') return true;
    if (t == 'no' || t == 'false') return false;
    avisar('"$t" no es Sí ni No; se ignoró.');
    return null;
  }

  plan.necesaria = combinar(plan.necesaria, siNo(CampoImportado.necesaria), 'Necesaria');
  plan.activa = combinar(plan.activa, siNo(CampoImportado.activa), 'Activa');
}

/// Combina el plan del archivo con la categoría [existente] del mismo
/// nombre. El tipo solo sale del archivo o de lo que ya era (regla #8).
Categoria _construirCategoria(
  _PlanCategoria plan,
  Categoria? existente,
  List<RenglonConProblema> avisos,
) {
  void avisar(String motivo) =>
      avisos.add(RenglonConProblema(numeroDeRenglon: plan.renglon, motivo: motivo));

  final monto = plan.monto ??
      switch (existente) {
        final CategoriaFija c => c.montoFijoCentavos,
        final CategoriaVariable c => c.presupuestoMensualCentavos,
        _ => const Dinero.cero(),
      };
  var fija = plan.fija ?? existente is CategoriaFija;
  if (fija && monto.centavos <= 0) {
    avisar('"${plan.nombre}" es fija pero no tiene monto; quedó como variable.');
    fija = false;
  }
  final id = existente?.id ?? _idNuevo(plan.nombre);
  final emoji = plan.emojiDelArchivo ??
      (existente == null || existente.emoji == emojiImportadoAntiguo
          ? sugerirEmoji(plan.nombre)
          : existente.emoji);
  final activa = plan.activa ?? existente?.activa ?? true;
  final necesaria = plan.necesaria ?? existente?.esNecesaria ?? false;
  if (!fija) {
    return CategoriaVariable(
      id: id,
      nombre: plan.nombre,
      emoji: emoji,
      activa: activa,
      esNecesaria: necesaria,
      presupuestoMensualCentavos: monto,
    );
  }
  final diaPrevio = existente is CategoriaFija ? existente.diaDelCiclo : null;
  if (plan.dia == null && diaPrevio == null) {
    avisar('"${plan.nombre}" es fija sin día de cobro; se usó el día 1.');
  }
  return CategoriaFija(
    id: id,
    nombre: plan.nombre,
    emoji: emoji,
    activa: activa,
    esNecesaria: necesaria,
    montoFijoCentavos: monto,
    diaDelCiclo: plan.dia ?? diaPrevio ?? 1,
  );
}

String _campo(List<String> renglon, int? indice) {
  if (indice == null || indice >= renglon.length) return '';
  return quitarNeutralizacion(renglon[indice].trim());
}

final _fechaDiaMesAnio = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2}|\d{4})(?:[ T](\d{1,2}):(\d{2})(?::\d{2})?)?$');

/// ISO 8601 (`aaaa-mm-dd`, con o sin hora) vía [DateTime.tryParse], más
/// `dd/mm/aaaa` o `dd-mm-aaaa` (también con año de dos dígitos y con hora,
/// como lo reescribe Excel) a mano. Se conservan hora y minuto si vienen —
/// el orden de los gastos del día — y siempre en hora local, nunca UTC
/// (ver docs/paridad-3-2-procedimiento.md).
DateTime? _parsearFecha(String texto) {
  if (texto.isEmpty) return null;

  final iso = DateTime.tryParse(texto);
  if (iso != null) {
    final local = iso.isUtc ? iso.toLocal() : iso;
    return DateTime(local.year, local.month, local.day, local.hour, local.minute);
  }

  final match = _fechaDiaMesAnio.firstMatch(texto);
  if (match == null) return null;
  final dia = int.parse(match.group(1)!);
  final mes = int.parse(match.group(2)!);
  final anioCrudo = int.parse(match.group(3)!);
  final anio = match.group(3)!.length == 2 ? 2000 + anioCrudo : anioCrudo;
  final hora = int.parse(match.group(4) ?? '0');
  final minuto = int.parse(match.group(5) ?? '0');
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31 || hora > 23 || minuto > 59) return null;
  return DateTime(anio, mes, dia, hora, minuto);
}

/// Tolera `$`, `MXN` y espacios antes de delegar en
/// [Dinero.intentarDesdeTexto], que ya tolera comas de separador de miles.
Dinero? _parsearMonto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\$\s]|mxn', caseSensitive: false), '');
  return Dinero.intentarDesdeTexto(limpio);
}

/// `null` si el texto no está vacío y no se reconoce (quien llama avisa y
/// usa tarjeta). Vacío es tarjeta, igual que la captura.
MedioPago? _leerMedio(String texto) {
  final t = normalizarTexto(texto);
  if (t.isEmpty) return MedioPago.tarjeta;
  if (t.contains('efectivo') || t.contains('cash')) return MedioPago.efectivo;
  const deTarjeta = ['tarjeta', 'credito', 'debito', 'tdc', 'tdd', 'card'];
  if (deTarjeta.any(t.contains)) return MedioPago.tarjeta;
  return null;
}

/// `null` si el texto no está vacío y no se reconoce (quien llama avisa y
/// usa activo). Acepta las etiquetas de la exportación, los nombres
/// internos de exportaciones anteriores y sinónimos comunes.
EstadoMovimiento? _leerEstado(String texto) {
  final t = normalizarTexto(texto);
  if (t.isEmpty) return EstadoMovimiento.activo;
  const anulado = ['anulado', 'cancelado', 'borrado', 'eliminado'];
  const pendiente = ['pendiente', 'propuesto'];
  const activo = ['activo', 'registrado', 'pagado', 'ok', 'si'];
  if (anulado.any(t.startsWith)) return EstadoMovimiento.anulado;
  if (pendiente.any(t.startsWith)) return EstadoMovimiento.propuesto;
  if (activo.any(t.startsWith)) return EstadoMovimiento.activo;
  return null;
}

/// Cómo se registró: si viene de una exportación se conserva; cualquier
/// otra cosa (o vacío) es "Importado". Nunca avisa: es solo informativo.
OrigenCaptura _leerOrigen(String texto) {
  final t = normalizarTexto(texto);
  for (final origen in OrigenCaptura.values) {
    if (t == origen.name || t == normalizarTexto(etiquetaOrigen[origen]!)) return origen;
  }
  return OrigenCaptura.migracion;
}

String _slug(String nombreNormalizado) =>
    nombreNormalizado.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

/// Hash FNV-1a de 32 bits sobre los bytes UTF-8 del contenido. A propósito
/// no se usa `String.hashCode`: Dart no garantiza que sea estable entre
/// ejecuciones ni plataformas, y esta huella tiene que ser siempre la misma
/// para el mismo archivo — es la base del `clientId` que hace que
/// reimportar no duplique.
int huellaEstable(String contenido) {
  const primoFnv = 0x01000193;
  var huella = 0x811c9dc5;
  for (final byte in utf8.encode(contenido)) {
    huella = ((huella ^ byte) * primoFnv) & 0xFFFFFFFF;
  }
  return huella;
}
