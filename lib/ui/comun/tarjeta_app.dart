import 'package:flutter/material.dart';

import 'tema.dart';

enum VarianteTarjeta { heroe, informativa, lista }

/// El único componente de tarjeta (`docs/rediseno/design-system/componentes/Tarjeta.md`),
/// en tres variantes; sustituye los estilos de tarjeta anteriores.
///
/// - **Héroe**: `heroe-fondo`, una por pantalla como máximo, para la cifra
///   que responde la pregunta de la pantalla. El texto de adentro toma
///   `heroe-texto` por omisión.
/// - **Informativa**: superficie, borde, `sombra-1`, radio `radio-l`,
///   padding 16.
/// - **De lista**: la misma superficie con renglones separados por `borde`
///   (las listas nunca son tarjetas sueltas).
///
/// Las alertas no tiñen tarjetas: usan `Aviso`.
class TarjetaApp extends StatelessWidget {
  final VarianteTarjeta variante;
  final Widget? child;

  /// Solo para la variante de lista.
  final List<Widget> renglones;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? etiquetaSemantica;

  const TarjetaApp.heroe({super.key, required Widget this.child, this.padding, this.onTap, this.etiquetaSemantica})
      : variante = VarianteTarjeta.heroe,
        renglones = const [];

  const TarjetaApp({super.key, required Widget this.child, this.padding, this.onTap, this.etiquetaSemantica})
      : variante = VarianteTarjeta.informativa,
        renglones = const [];

  const TarjetaApp.lista({super.key, required this.renglones, this.etiquetaSemantica})
      : variante = VarianteTarjeta.lista,
        child = null,
        padding = EdgeInsets.zero,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final esHeroe = variante == VarianteTarjeta.heroe;
    final radio = BorderRadius.circular(Radios.l);
    Widget contenido = switch (variante) {
      VarianteTarjeta.lista => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, r) in renglones.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: p.borde),
              r,
            ],
          ],
        ),
      _ => Padding(padding: padding ?? EdgeInsets.all(esHeroe ? 20 : 16), child: child),
    };
    if (esHeroe) {
      contenido = DefaultTextStyle.merge(
        style: TextStyle(color: p.heroeTexto),
        child: IconTheme.merge(data: IconThemeData(color: p.heroeTexto), child: contenido),
      );
    }
    final caja = DecoratedBox(
      decoration: BoxDecoration(
        color: esHeroe ? p.heroeFondo : p.superficie,
        borderRadius: radio,
        border: esHeroe ? null : Border.all(color: p.borde),
        boxShadow: esHeroe ? null : sombra1(p),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? ClipRRect(borderRadius: radio, child: contenido)
            : InkWell(borderRadius: radio, onTap: onTap, child: contenido),
      ),
    );
    final etiqueta = etiquetaSemantica;
    return etiqueta == null ? caja : Semantics(container: true, label: etiqueta, child: caja);
  }
}
