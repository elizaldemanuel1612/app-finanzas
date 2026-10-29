/// Lector de CSV en RFC 4180 (Bloque B): comillas, comas y saltos de línea
/// embebidos dentro de un campo entre comillas, comillas duplicadas (`""`)
/// como comilla literal. Inverso de `exportacion/exportar_csv.dart`.
///
/// Quita el BOM UTF-8 inicial si lo hay (el mismo que escribe la
/// exportación) y tolera tanto `\n` como `\r\n` como fin de línea.
/// [separador] es `,` salvo que [detectarSeparador] diga otra cosa.
List<List<String>> leerCsv(String contenido, {String separador = ','}) {
  final texto = _sinBom(contenido);
  final filas = <List<String>>[];
  var campoActual = StringBuffer();
  var filaActual = <String>[];
  var dentroDeComillas = false;
  var huboContenidoSinCerrar = false;

  void cerrarCampo() {
    filaActual.add(campoActual.toString());
    campoActual = StringBuffer();
  }

  void cerrarFila() {
    cerrarCampo();
    filas.add(filaActual);
    filaActual = <String>[];
    huboContenidoSinCerrar = false;
  }

  var i = 0;
  final n = texto.length;
  while (i < n) {
    final c = texto[i];

    if (dentroDeComillas) {
      if (c == '"') {
        if (i + 1 < n && texto[i + 1] == '"') {
          campoActual.write('"');
          i += 2;
        } else {
          dentroDeComillas = false;
          i++;
        }
      } else {
        campoActual.write(c);
        i++;
      }
      huboContenidoSinCerrar = true;
      continue;
    }

    switch (c) {
      case '"':
        dentroDeComillas = true;
        i++;
      case _ when c == separador:
        cerrarCampo();
        i++;
      case '\r':
        cerrarFila();
        i++;
        if (i < n && texto[i] == '\n') i++;
        continue;
      case '\n':
        cerrarFila();
        i++;
        continue;
      default:
        campoActual.write(c);
        i++;
    }
    huboContenidoSinCerrar = true;
  }

  if (huboContenidoSinCerrar) cerrarFila();

  return filas;
}

/// Excel en algunos idiomas guarda el CSV con `;` en vez de `,`: si el
/// encabezado tiene más `;` que `,`, ese es el separador.
String detectarSeparador(String contenido) {
  final texto = _sinBom(contenido);
  final finDeLinea = texto.indexOf('\n');
  final encabezado = finDeLinea < 0 ? texto : texto.substring(0, finDeLinea);
  final comas = ','.allMatches(encabezado).length;
  final puntosYComa = ';'.allMatches(encabezado).length;
  return puntosYComa > comas ? ';' : ',';
}

String _sinBom(String texto) => texto.startsWith('﻿') ? texto.substring(1) : texto;
