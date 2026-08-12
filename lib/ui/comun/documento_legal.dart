import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import 'tema.dart';

/// Título y asset de cada documento legal que la app sabe mostrar — clave
/// para resolver los links relativos entre ellos (`./privacidad.md` dentro
/// de terminos.md) sin salir de la app.
const _documentosConocidos = {
  'privacidad.md': ('Política de privacidad', 'docs/legal/privacidad.md'),
  'terminos.md': ('Términos y condiciones', 'docs/legal/terminos.md'),
};

/// Muestra un documento legal (`docs/legal/*.md`, empaquetado como asset)
/// dentro de la app. No hay remoto de GitHub configurado todavía, así que
/// no existe una URL de GitHub Pages real que abrir (ver nota en
/// `pantalla_ajustes.dart`) — mostrarlo en la app es lo único que
/// funciona hoy, y de paso deja `docs/legal/` como única fuente de verdad:
/// no hay una copia duplicada del texto viviendo en Dart.
class PantallaDocumentoLegal extends StatefulWidget {
  final String titulo;
  final String rutaAsset;

  const PantallaDocumentoLegal({
    super.key,
    required this.titulo,
    required this.rutaAsset,
  });

  @override
  State<PantallaDocumentoLegal> createState() => _PantallaDocumentoLegalState();
}

class _PantallaDocumentoLegalState extends State<PantallaDocumentoLegal> {
  String? _texto;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final texto = await rootBundle.loadString(widget.rutaAsset);
    if (!mounted) return;
    setState(() => _texto = texto);
  }

  Future<void> _abrirLink(String url) async {
    if (url.endsWith('.md')) {
      final archivo = url.split('/').last;
      final documento = _documentosConocidos[archivo];
      if (documento != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PantallaDocumentoLegal(
              titulo: documento.$1,
              rutaAsset: documento.$2,
            ),
          ),
        );
        return;
      }
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: _texto == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: _bloques(_texto!, context, _abrirLink),
              ),
            ),
    );
  }
}

final _regexInline = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|\[(.+?)\]\((.+?)\)');
final _regexSeparadorTabla = RegExp(r'^\|[\s\-:|]+\|$');

/// Una línea que no continúa el párrafo/bullet anterior — arranca un
/// bloque nuevo o corta el actual. Sin esto, un párrafo o bullet que el
/// `.md` envuelve a los ~80 caracteres (línea suave, sin blanco de por
/// medio) se procesaba como dos líneas independientes: un `**negrita**` o
/// un `[link](url)` partido a la mitad por el salto de línea se quedaba
/// sin cerrar en una línea y con la sintaxis cruda colgando en la
/// siguiente.
bool _esInicioDeBloque(String linea) =>
    linea.startsWith('# ') ||
    linea.startsWith('## ') ||
    linea.startsWith('- ') ||
    linea.startsWith('|') ||
    linea.trim().isEmpty;

/// Suficiente markdown para `docs/legal/*.md` — no un parser genérico.
/// Cubre exactamente lo que esos dos documentos usan: `#`/`##`, listas con
/// `- `, tablas `| a | b |`, negritas, cursivas y links.
List<Widget> _bloques(String texto, BuildContext context, void Function(String) onLink) {
  final lineas = texto.split('\n');
  final theme = Theme.of(context).textTheme;
  final widgets = <Widget>[];
  var i = 0;

  String recogerParrafo() {
    final partes = [lineas[i]];
    i++;
    while (i < lineas.length && !_esInicioDeBloque(lineas[i])) {
      partes.add(lineas[i].trim());
      i++;
    }
    return partes.join(' ');
  }

  while (i < lineas.length) {
    final linea = lineas[i];

    if (linea.startsWith('# ')) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(linea.substring(2), style: theme.headlineMedium),
      ));
      i++;
    } else if (linea.startsWith('## ')) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(linea.substring(3), style: theme.titleMedium),
      ));
      i++;
    } else if (linea.startsWith('- ')) {
      final parrafo = recogerParrafo().substring(2);
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(
              child: Text.rich(TextSpan(children: _spans(parrafo, onLink))),
            ),
          ],
        ),
      ));
    } else if (linea.startsWith('|')) {
      final filas = <String>[];
      while (i < lineas.length && lineas[i].startsWith('|')) {
        filas.add(lineas[i]);
        i++;
      }
      widgets.add(_tabla(filas));
    } else if (linea.trim().isEmpty) {
      widgets.add(const SizedBox(height: 4));
      i++;
    } else {
      final parrafo = recogerParrafo();
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(TextSpan(children: _spans(parrafo, onLink))),
      ));
    }
  }
  return widgets;
}

List<String> _celdas(String filaTabla) =>
    filaTabla.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

Widget _tabla(List<String> filas) {
  if (filas.length < 2) return const SizedBox.shrink();
  final encabezados = _celdas(filas.first);
  final datos = filas
      .skip(1)
      .where((f) => !_regexSeparadorTabla.hasMatch(f))
      .map(_celdas);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: datos.map((celdas) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColoresApp.fondo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < celdas.length && i < encabezados.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${encabezados[i]}: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: celdas[i]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }).toList(),
  );
}

List<InlineSpan> _spans(String texto, void Function(String) onLink) {
  final spans = <InlineSpan>[];
  var ultimo = 0;
  for (final m in _regexInline.allMatches(texto)) {
    if (m.start > ultimo) spans.add(TextSpan(text: texto.substring(ultimo, m.start)));
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
    } else {
      final etiqueta = m.group(3)!;
      final url = m.group(4)!;
      spans.add(TextSpan(
        text: etiqueta,
        style: const TextStyle(color: ColoresApp.violeta, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => onLink(url),
      ));
    }
    ultimo = m.end;
  }
  if (ultimo < texto.length) spans.add(TextSpan(text: texto.substring(ultimo)));
  return spans;
}
