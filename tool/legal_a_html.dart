// Publica la política de privacidad y los términos como páginas propias del
// dominio de la app (https://app-finanzas-27e41.web.app/legal/...), que es
// lo que Google pide para verificar la marca. La fuente sigue siendo
// docs/legal/*.md: correr después de cambiarlos y antes de publicar.
//   dart run tool/legal_a_html.dart
import 'dart:io';

void main() {
  final salida = Directory('web/legal')..createSync(recursive: true);
  for (final (origen, destino) in [('privacidad', 'privacidad'), ('terminos', 'terminos')]) {
    final md = File('docs/legal/$origen.md').readAsStringSync();
    File('${salida.path}/$destino.html').writeAsStringSync(_pagina(md));
    stdout.writeln('web/legal/$destino.html');
  }
}

String _escapar(String t) => t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Negritas, cursivas, código y links; los .md entre ambos documentos pasan a .html.
String _enLinea(String t) {
  var s = _escapar(t);
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) {
    final destino = m[2]!.replaceAll(RegExp(r'\.md$'), '.html');
    return '<a href="$destino">${m[1]}</a>';
  });
  s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => '<strong>${m[1]}</strong>');
  s = s.replaceAllMapped(RegExp(r'(^|[\s(])_([^_]+)_'), (m) => '${m[1]}<em>${m[2]}</em>');
  s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code>${m[1]}</code>');
  return s;
}

String _pagina(String md) {
  final cuerpo = StringBuffer();
  var titulo = 'MAVfin';
  final lineas = md.split('\n');
  final parrafo = <String>[];
  String? lista; // texto acumulado del renglón actual de lista
  final items = <String>[];
  var enLista = false;

  void cerrarParrafo() {
    if (parrafo.isNotEmpty) cuerpo.writeln('<p>${_enLinea(parrafo.join(' '))}</p>');
    parrafo.clear();
  }

  void cerrarLista() {
    if (lista != null) items.add(lista!);
    lista = null;
    if (enLista) {
      cuerpo.writeln('<ul>${items.map((i) => '<li>${_enLinea(i)}</li>').join()}</ul>');
    }
    items.clear();
    enLista = false;
  }

  for (var i = 0; i < lineas.length; i++) {
    final linea = lineas[i];
    final t = linea.trim();
    if (t.startsWith('|')) {
      cerrarParrafo();
      cerrarLista();
      final filas = <List<String>>[];
      while (i < lineas.length && lineas[i].trim().startsWith('|')) {
        final celdas = lineas[i].trim().split('|').map((c) => c.trim()).toList();
        celdas.removeAt(0);
        celdas.removeLast();
        if (!celdas.every((c) => RegExp(r'^-+$').hasMatch(c))) filas.add(celdas);
        i++;
      }
      i--;
      cuerpo.writeln('<table><thead><tr>${filas.first.map((c) => '<th>${_enLinea(c)}</th>').join()}</tr></thead><tbody>');
      for (final f in filas.skip(1)) {
        cuerpo.writeln('<tr>${f.map((c) => '<td>${_enLinea(c)}</td>').join()}</tr>');
      }
      cuerpo.writeln('</tbody></table>');
    } else if (t.startsWith('# ')) {
      cerrarParrafo();
      cerrarLista();
      titulo = t.substring(2);
      cuerpo.writeln('<h1>${_enLinea(titulo)}</h1>');
    } else if (t.startsWith('## ')) {
      cerrarParrafo();
      cerrarLista();
      cuerpo.writeln('<h2>${_enLinea(t.substring(3))}</h2>');
    } else if (t.startsWith('- ')) {
      cerrarParrafo();
      if (lista != null) items.add(lista!);
      lista = t.substring(2);
      enLista = true;
    } else if (t.isEmpty) {
      cerrarParrafo();
      cerrarLista();
    } else if (enLista && linea.startsWith('  ')) {
      lista = '${lista!} $t';
    } else {
      cerrarLista();
      parrafo.add(t);
    }
  }
  cerrarParrafo();
  cerrarLista();

  return '''<!doctype html>
<html lang="es-MX">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escapar(titulo)}</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; color: #0B1F3B; background: #FAF8F3; line-height: 1.55; }
  h1 { font-size: 1.6rem; } h2 { font-size: 1.2rem; margin-top: 2rem; }
  a { color: #0B1F3B; }
  table { border-collapse: collapse; width: 100%; font-size: .92rem; display: block; overflow-x: auto; }
  th, td { border: 1px solid #D9DEE7; padding: 8px; text-align: left; vertical-align: top; }
  nav { margin-bottom: 24px; font-size: .9rem; }
  @media (prefers-color-scheme: dark) { body { background: #0A1424; color: #EEF1F7; } a { color: #8DB4F2; } th, td { border-color: #26354F; } }
</style>
</head>
<body>
<nav><a href="/acerca.html">MAVfin</a> · <a href="/legal/privacidad.html">Privacidad</a> · <a href="/legal/terminos.html">Términos</a></nav>
$cuerpo</body>
</html>
''';
}
