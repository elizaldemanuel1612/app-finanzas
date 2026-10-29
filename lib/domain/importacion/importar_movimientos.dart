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
import '../presupuesto/categorias.dart';
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
  final List<CategoriaVariable> categoriasPorCrear;

  /// Categorías que ya existían con el emoji genérico de importaciones
  /// anteriores (📥) y que ahora reciben el del archivo o uno sugerido.
  final List<Categoria> categoriasPorActualizar;
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
    required this.renglonesConProblema,
    this.avisos = const [],
    required this.totalesPorCiclo,
    this.categoriasAdivinadas = 0,
    this.sinCategoria = 0,
  });

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
}) {
  final filas = leerCsv(contenidoCsv, separador: detectarSeparador(contenidoCsv));
  if (filas.isEmpty) {
    return const Falla('El archivo está vacío.');
  }

  final mapeo = detectarColumnas(filas.first);
  if (!mapeo.esImportable) {
    return const Falla(
      'No encontré columnas de fecha y monto. Revisa el formato con la plantilla de ejemplo.',
    );
  }

  final huella = huellaEstable(contenidoCsv);
  final existentesPorNombre = {
    for (final c in categoriasExistentes) normalizarTexto(c.nombre): c,
  };
  final categoriasNuevasPorNombre = <String, CategoriaVariable>{};
  final categoriasActualizadas = <String, Categoria>{};
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
    for (final renglon in filas.skip(1))
      if (_campo(renglon, mapeo[CampoImportado.categoria]).isNotEmpty)
        ObservacionComercio(
          _campo(renglon, mapeo[CampoImportado.descripcion]),
          separarEmojiDelNombre(_campo(renglon, mapeo[CampoImportado.categoria])).nombre,
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

  for (var i = 1; i < filas.length; i++) {
    final renglon = filas[i];
    final numeroDeRenglon = i + 1;
    if (renglon.every((celda) => celda.trim().isEmpty)) continue;
    String campo(CampoImportado c) => _campo(renglon, mapeo[c]);
    void avisar(String motivo) =>
        avisos.add(RenglonConProblema(numeroDeRenglon: numeroDeRenglon, motivo: motivo));

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

    final separado = separarEmojiDelNombre(campo(CampoImportado.categoria));
    final descripcion = campo(CampoImportado.descripcion);
    final adivinada = separado.nombre.isEmpty ? adivinarPorDescripcion(descripcion) : null;
    final nombreCategoria = separado.nombre.isNotEmpty
        ? separado.nombre
        : adivinada ?? categoriaSinCategoria;
    final emojiDelArchivo = campo(CampoImportado.emoji);
    final emoji = emojiDelArchivo.isNotEmpty
        ? emojiDelArchivo
        : separado.emoji ?? sugerirEmoji(nombreCategoria);
    final categoriaId = _categoriaPara(
      nombreCategoria,
      emoji,
      existentesPorNombre,
      categoriasNuevasPorNombre,
      categoriasActualizadas,
    );

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

    switch (resultado) {
      case Falla(:final mensaje):
        problemas.add(RenglonConProblema(numeroDeRenglon: numeroDeRenglon, motivo: mensaje));
      case Exito(:final valor):
        movimientos.add(valor);
        if (separado.nombre.isEmpty) adivinada != null ? adivinadas++ : sinCategoria++;
        if (valor.estado == EstadoMovimiento.activo) {
          totalesPorCiclo[valor.cicloId] =
              (totalesPorCiclo[valor.cicloId] ?? const Dinero.cero()) + valor.monto;
        }
    }
  }

  return Exito(ResultadoImportacion(
    movimientos: movimientos,
    categoriasPorCrear: categoriasNuevasPorNombre.values.toList(),
    categoriasPorActualizar: categoriasActualizadas.values.toList(),
    renglonesConProblema: problemas,
    avisos: avisos,
    totalesPorCiclo: totalesPorCiclo,
    categoriasAdivinadas: adivinadas,
    sinCategoria: sinCategoria,
  ));
}

/// Id de la categoría [nombre]: la existente con ese nombre (sin importar
/// acentos ni mayúsculas), la nueva que ya se armó en este archivo, o una
/// nueva con [emoji]. A una existente que conserva el 📥 genérico de
/// importaciones anteriores se le pone [emoji].
String _categoriaPara(
  String nombre,
  String emoji,
  Map<String, Categoria> existentes,
  Map<String, CategoriaVariable> nuevas,
  Map<String, Categoria> actualizadas,
) {
  final clave = normalizarTexto(nombre);
  final existente = existentes[clave];
  if (existente != null) {
    if (existente.emoji == emojiImportadoAntiguo &&
        emoji != emojiImportadoAntiguo &&
        !actualizadas.containsKey(clave)) {
      actualizadas[clave] = conEmoji(existente, emoji);
    }
    return existente.id;
  }
  return nuevas
      .putIfAbsent(
        clave,
        () => crearCategoriaImportada(id: 'imp-${_slug(clave)}', nombre: nombre, emoji: emoji),
      )
      .id;
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
