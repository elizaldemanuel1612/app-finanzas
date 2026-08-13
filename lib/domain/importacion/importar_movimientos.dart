import 'dart:convert';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../clasificacion/normalizacion_texto.dart';
import '../migracion/movimiento_migrado.dart';
import '../modelos/categoria.dart';
import '../modelos/movimiento.dart';
import '../presupuesto/categorias.dart';
import 'csv.dart';
import 'mapeo_columnas.dart';

const _categoriaSinNombre = 'Importado';

/// Un renglón del CSV que no se pudo convertir en movimiento — [numeroDeRenglon]
/// es 1-based contando el encabezado como renglón 1, tal como lo vería
/// alguien abriendo el archivo en una hoja de cálculo.
final class RenglonConProblema {
  final int numeroDeRenglon;
  final String motivo;

  const RenglonConProblema({required this.numeroDeRenglon, required this.motivo});

  @override
  String toString() => 'Renglón $numeroDeRenglon: $motivo';
}

/// Lo que arma la vista previa de "Importar gastos" (Bloque B) antes de
/// que el usuario confirme: movimientos listos para guardar, categorías
/// que hay que crear primero, renglones que no se pudieron leer, y el
/// total por ciclo para que el usuario vea a qué meses afecta.
final class ResultadoImportacion {
  final List<Movimiento> movimientos;
  final List<CategoriaVariable> categoriasPorCrear;
  final List<RenglonConProblema> renglonesConProblema;
  final Map<String, Dinero> totalesPorCiclo;

  const ResultadoImportacion({
    required this.movimientos,
    required this.categoriasPorCrear,
    required this.renglonesConProblema,
    required this.totalesPorCiclo,
  });
}

/// Lee [contenidoCsv] y arma la vista previa de importación. Nunca escribe
/// nada — quien llama decide, con esta vista previa en mano, si guarda los
/// movimientos y las categorías nuevas.
///
/// Cada movimiento se construye con [crearMovimientoMigrado]
/// (`domain/migracion/movimiento_migrado.dart`, sin consumidor hasta este
/// bloque) y un `idOrigen` derivado de una huella estable del contenido del
/// archivo más el número de renglón (`IMP-<huella>-<renglón>`). Como
/// [crearMovimientoMigrado] reusa ese `idOrigen` como `clientId`, volver a
/// importar el mismo archivo produce los mismos `clientId` — y
/// `MovimientoRepositorio.guardar` ya es idempotente por `clientId` (regla
/// no negociable #2), así que reimportar no duplica. Dos archivos con
/// contenido distinto producen huellas distintas, así que no colisionan
/// entre sí.
Resultado<ResultadoImportacion> previsualizarImportacion({
  required String contenidoCsv,
  required CalculadoraCiclo calculadoraCiclo,
  required List<Categoria> categoriasExistentes,
}) {
  final filas = leerCsv(contenidoCsv);
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
  final idPorNombreNormalizado = {
    for (final c in categoriasExistentes) normalizarTexto(c.nombre): c.id,
  };
  final categoriasNuevasPorNombre = <String, CategoriaVariable>{};
  final movimientos = <Movimiento>[];
  final problemas = <RenglonConProblema>[];
  final totalesPorCiclo = <String, Dinero>{};

  for (var i = 1; i < filas.length; i++) {
    final renglon = filas[i];
    final numeroDeRenglon = i + 1;
    if (renglon.every((celda) => celda.trim().isEmpty)) continue;

    final textoFecha = _campo(renglon, mapeo[CampoImportado.fecha]);
    final fecha = _parsearFecha(textoFecha);
    if (fecha == null) {
      problemas.add(RenglonConProblema(
        numeroDeRenglon: numeroDeRenglon,
        motivo: 'No pude leer la fecha "$textoFecha".',
      ));
      continue;
    }

    final textoMonto = _campo(renglon, mapeo[CampoImportado.monto]);
    final monto = _parsearMonto(textoMonto);
    if (monto == null) {
      problemas.add(RenglonConProblema(
        numeroDeRenglon: numeroDeRenglon,
        motivo: 'No pude leer el monto "$textoMonto".',
      ));
      continue;
    }

    final nombreCategoriaCrudo = _campo(renglon, mapeo[CampoImportado.categoria]);
    final nombreCategoria = nombreCategoriaCrudo.isEmpty ? _categoriaSinNombre : nombreCategoriaCrudo;
    final nombreNormalizado = normalizarTexto(nombreCategoria);
    final categoriaId = idPorNombreNormalizado[nombreNormalizado] ??
        categoriasNuevasPorNombre[nombreNormalizado]?.id ??
        'imp-${_slug(nombreNormalizado)}';
    if (!idPorNombreNormalizado.containsKey(nombreNormalizado) &&
        !categoriasNuevasPorNombre.containsKey(nombreNormalizado)) {
      categoriasNuevasPorNombre[nombreNormalizado] =
          crearCategoriaImportada(id: categoriaId, nombre: nombreCategoria);
    }

    final descripcion = _campo(renglon, mapeo[CampoImportado.descripcion]);
    final medio = _parsearMedio(_campo(renglon, mapeo[CampoImportado.medio]));
    final idOrigen = 'IMP-$huella-$numeroDeRenglon';

    final resultado = crearMovimientoMigrado(
      idOrigen: idOrigen,
      fecha: fecha,
      calculadoraCiclo: calculadoraCiclo,
      monto: monto,
      categoriaId: categoriaId,
      medio: medio,
      descripcion: descripcion.isEmpty ? nombreCategoria : descripcion,
    );

    switch (resultado) {
      case Falla(:final mensaje):
        problemas.add(RenglonConProblema(numeroDeRenglon: numeroDeRenglon, motivo: mensaje));
      case Exito(:final valor):
        movimientos.add(valor);
        totalesPorCiclo[valor.cicloId] =
            (totalesPorCiclo[valor.cicloId] ?? const Dinero.cero()) + valor.monto;
    }
  }

  return Exito(ResultadoImportacion(
    movimientos: movimientos,
    categoriasPorCrear: categoriasNuevasPorNombre.values.toList(),
    renglonesConProblema: problemas,
    totalesPorCiclo: totalesPorCiclo,
  ));
}

String _campo(List<String> renglon, int? indice) {
  if (indice == null || indice >= renglon.length) return '';
  return renglon[indice].trim();
}

/// ISO 8601 (incluye `aaaa-mm-dd`) vía [DateTime.tryParse], más `dd/mm/aaaa`
/// a mano. Se trunca a medianoche local — igual que el resto del dominio,
/// nunca UTC (ver docs/paridad-3-2-procedimiento.md).
DateTime? _parsearFecha(String texto) {
  if (texto.isEmpty) return null;

  final iso = DateTime.tryParse(texto);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto);
  if (match == null) return null;
  final dia = int.parse(match.group(1)!);
  final mes = int.parse(match.group(2)!);
  final anio = int.parse(match.group(3)!);
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  return DateTime(anio, mes, dia);
}

/// Tolera `$` y espacios antes de delegar en [Dinero.intentarDesdeTexto],
/// que ya tolera comas de separador de miles.
Dinero? _parsearMonto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\$\s]'), '');
  return Dinero.intentarDesdeTexto(limpio);
}

MedioPago _parsearMedio(String texto) {
  final normalizado = normalizarTexto(texto);
  if (normalizado.contains('efectivo') || normalizado.contains('cash')) {
    return MedioPago.efectivo;
  }
  return MedioPago.tarjeta;
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
