import 'package:web/web.dart' as web;

String? _ultimo;

void pintarFondoDePagina(int argb) {
  final hex = '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  if (hex == _ultimo) return;
  _ultimo = hex;
  web.document.documentElement?.setAttribute('style', 'background-color: $hex');
  web.document.body?.style.backgroundColor = hex;
  final meta = web.document.querySelector('meta[name=theme-color]');
  meta?.setAttribute('content', hex);
}
