import 'dart:convert';

import '../clasificacion/cascada_clasificacion.dart';
import '../clasificacion/normalizacion_texto.dart';
import '../modelos/categoria.dart';

// Nivel 3 de la cascada con la IA del usuario (spec §6.1 y §6.5). Solo se
// manda la nota del gasto y los nombres de las categorías.

const instruccionesClasificacion =
    'Clasificas gastos personales de una persona en México. Te doy la nota de un gasto y la lista '
    'de sus categorías. Responde solo con JSON, sin texto alrededor: '
    '{"categoria": "<nombre exacto de la lista, o null si ninguna aplica>", "confianza": <número de 0 a 1>}. '
    'Usa confianza alta solo si la nota claramente corresponde a esa categoría.';

/// El mensaje con la nota y las categorías activas.
String mensajeClasificacion(String nota, List<Categoria> categorias) => [
      'Nota del gasto: "${nota.trim()}"',
      'Categorías:',
      for (final c in categorias)
        if (c.activa) '- ${c.nombre}',
    ].join('\n');

/// La respuesta de la IA como [ResultadoIA]; `null` si no se entiende, si
/// no eligió ninguna o si nombró una que no está en la lista.
ResultadoIA? interpretarClasificacion(String respuesta, List<Categoria> categorias) {
  final inicio = respuesta.indexOf('{');
  final fin = respuesta.lastIndexOf('}');
  if (inicio < 0 || fin <= inicio) return null;
  final Object? datos;
  try {
    datos = jsonDecode(respuesta.substring(inicio, fin + 1));
  } on FormatException {
    return null;
  }
  if (datos is! Map<String, dynamic>) return null;
  final nombre = datos['categoria'];
  final confianza = datos['confianza'];
  if (nombre is! String || confianza is! num) return null;
  final buscado = normalizarTexto(nombre);
  for (final c in categorias) {
    if (c.activa && normalizarTexto(c.nombre) == buscado) {
      return ResultadoIA(categoriaId: c.id, confianza: confianza.toDouble().clamp(0.0, 1.0));
    }
  }
  return null;
}
