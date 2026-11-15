/// Instructivo del asistente "Pregúntale a tu IA" (spec §6.5): la guía por
/// temas completa como única fuente. Sin Flutter, como `contenido_guia.dart`,
/// para probarlo con `dart test`.
library;

import 'contenido_guia.dart';
import 'modelo_guia.dart';

// El nombre va escrito: `nombreApp` vive en marca.dart, que importa Flutter.
const _reglas = '''
Eres el asistente de ayuda dentro de la app MAVfin, una app de finanzas personales en español de México.
Reglas:
- Contesta SOLO con base en la GUÍA de abajo. Si la respuesta no está ahí, dilo con honestidad ("Eso no lo encuentro en la guía") y sugiere el tema más cercano.
- Explica dónde está cada cosa con la ruta de la app, por ejemplo: Ajustes → Tu plan → Día de corte. Ajustes se abre tocando el círculo de tu inicial, arriba a la derecha.
- Respuestas cortas: 1 a 4 oraciones o pasos numerados. Tutea, en tono amable y directo.
- No ves los datos ni los gastos de la persona: si te pregunta por sus cifras, dile dónde verlas en la app.
- No des asesoría financiera, fiscal ni de inversión (no recomiendes productos, inversiones ni cuánto ahorrar). Puedes explicar cómo funciona la app.
- No inventes botones, pantallas ni funciones que no estén en la guía.
''';

String _textoBloque(BloqueGuia b) => switch (b) {
      Parrafo(:final texto) => texto,
      Subtitulo(:final texto) => '### $texto',
      Vinetas(:final puntos) => [for (final p in puntos) '- $p'].join('\n'),
      Pasos(:final pasos) => [for (final (i, p) in pasos.indexed) '${i + 1}. $p'].join('\n'),
      Nota(:final etiqueta, :final texto) => '($etiqueta) $texto',
      Ejemplo(:final pie) => pie ?? '',
    };

String _textoTema(SeccionGuia seccion, TemaGuia tema) => [
      '## ${tema.titulo} (sección ${seccion.titulo}) — ${tema.resumen}',
      for (final b in tema.bloques)
        if (_textoBloque(b).isNotEmpty) _textoBloque(b),
    ].join('\n');

final _palabra = RegExp(r'[a-záéíóúñü0-9]{4,}');

Set<String> _palabras(String texto) => {for (final m in _palabra.allMatches(texto.toLowerCase())) m.group(0)!};

/// Las reglas y la guía. Con [maxCaracteres] (modelos con poco contexto,
/// como el del iPhone), solo los temas que más se parecen a [pregunta]
/// hasta llenar ese tamaño, en el orden de la guía.
String instructivoDelAsistente({String pregunta = '', int? maxCaracteres}) {
  final temas = [
    for (final seccion in guiaDeLaApp)
      for (final tema in seccion.temas) _textoTema(seccion, tema),
  ];
  var elegidos = temas;
  if (maxCaracteres != null) {
    final buscadas = _palabras(pregunta);
    final puntaje = [for (final t in temas) _palabras(t).intersection(buscadas).length];
    final orden = [for (var i = 0; i < temas.length; i++) i]..sort((a, b) => puntaje[b].compareTo(puntaje[a]));
    final caben = <int>{};
    var usado = _reglas.length;
    for (final i in orden) {
      if (usado + temas[i].length > maxCaracteres) continue;
      caben.add(i);
      usado += temas[i].length;
    }
    elegidos = [for (var i = 0; i < temas.length; i++) if (caben.contains(i)) temas[i]];
  }
  return '$_reglas\nGUÍA:\n\n${elegidos.join('\n\n')}';
}
