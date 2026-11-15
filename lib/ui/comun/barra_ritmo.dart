import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/rollups/estado_ritmo.dart';
import '../../domain/voz/monto_hablado.dart';
import 'tema.dart';

/// La marca de ritmo (addendum-v3 §3.2;
/// `docs/rediseno/design-system/componentes/BarraRitmo.md`): una barra con
/// una línea vertical que marca dónde deberías ir hoy. Es el único
/// elemento que hay que aprender y se ve idéntica en toda la app.
///
/// - Relleno en `exito` antes de la marca y `atencion` si la pasaste
///   ([tonoDeRitmo], la misma regla del chip de estado).
/// - Al rebasar el presupuesto la barra se re-escala: lo presupuestado
///   queda como un corte y el exceso va en `peligro`. Nunca se llena entera
///   de rojo.
/// - Siempre va con una frase cerca ("$3,290 de $7,700"): el color nunca es
///   la única señal.
class BarraRitmo extends StatelessWidget {
  /// Gastado ÷ presupuesto; puede pasar de 1.
  final double porcentajeUsado;

  /// Fracción del ciclo transcurrida: dónde va la marca.
  final double avanceCiclo;

  /// Qué mide ("Súper", "Variables"): obligatorio para el lector de
  /// pantalla (Fase 6, Bloque 4.3).
  final String descripcion;

  /// Con montos, el lector de pantalla dice "gastaste X de Y".
  final Dinero? gastado;
  final Dinero? presupuesto;

  /// Dentro de la tarjeta héroe: colores `heroe-*` y alto 10.
  final bool enHeroe;

  /// Alto 10 fuera del héroe (detalle de categoría).
  final bool grande;

  const BarraRitmo({
    super.key,
    required this.porcentajeUsado,
    required this.avanceCiclo,
    required this.descripcion,
    this.gastado,
    this.presupuesto,
    this.enHeroe = false,
    this.grande = false,
  });

  TonoRitmo get _tono => tonoDeRitmo(porcentajeUsado: porcentajeUsado, avanceCiclo: avanceCiclo);

  String get _etiqueta {
    final g = gastado;
    final p = presupuesto;
    final cifras = g != null && p != null ? 'gastaste ${montoEnPalabras(g)} de ${montoEnPalabras(p)}' : null;
    return '$descripcion: ${cifras ?? 'llevas ${(porcentajeUsado * 100).round()} por ciento'}. ${etiquetaTonoRitmo(_tono)}.';
  }

  @override
  Widget build(BuildContext context) {
    final p = ColoresApp.actual;
    final tono = _tono;
    final relleno = switch (tono) {
      TonoRitmo.vasBien => enHeroe ? p.heroeExito : p.exito,
      TonoRitmo.vasRapido || TonoRitmo.tePasaste => enHeroe ? p.heroeAtencion : p.atencion,
    };
    final exceso = enHeroe ? p.heroePeligro : p.peligro;
    final pista = enHeroe ? p.heroePista : p.grafPista;
    final marca = enHeroe ? p.heroeTexto : p.marcaRitmo;
    final corte = enHeroe ? p.heroeFondo : p.superficie;
    final alto = enHeroe || grande ? 10.0 : 8.0;
    final usado = porcentajeUsado.isNaN || porcentajeUsado < 0 ? 0.0 : porcentajeUsado;
    // Re-escala: con exceso, el ancho completo es lo gastado.
    final escala = usado > 1 ? 1 / usado : 1.0;

    return Semantics(
      label: _etiqueta,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth;
          final dentro = ancho * (usado > 1 ? escala : usado);
          final posMarca = ancho * avanceCiclo.clamp(0.0, 1.0) * escala;
          final radio = Radius.circular(alto / 2);
          return SizedBox(
            height: alto + 10,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 5,
                  height: alto,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(radio),
                    child: ColoredBox(
                      color: pista,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: dentro, child: ColoredBox(color: relleno)),
                          if (usado > 1) ...[
                            SizedBox(width: 2, child: ColoredBox(color: corte)),
                            Expanded(child: ColoredBox(color: exceso)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (posMarca - 1).clamp(0.0, ancho - 2),
                  top: 0,
                  width: 2,
                  height: alto + 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: marca, borderRadius: BorderRadius.circular(1)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// El texto del chip de estado y de la lectura de la barra.
String etiquetaTonoRitmo(TonoRitmo tono) => switch (tono) {
      TonoRitmo.vasBien => 'Vas bien',
      TonoRitmo.vasRapido => 'Vas un poco rápido',
      TonoRitmo.tePasaste => 'Te pasaste',
    };

/// Para pantallas que aún no migran al chip de estado: mismo texto que el
/// chip a partir del estado absoluto de antes.
String etiquetaEstadoRitmo(EstadoRitmo estado) => switch (estado) {
      EstadoRitmo.vaBien => 'Vas bien',
      EstadoRitmo.justo => 'Vas un poco rápido',
      EstadoRitmo.excedido => 'Te pasaste',
    };

/// Para fondos y gráficas — umbral WCAG 3:1. **Nunca** como color de
/// texto: para eso está [colorTextoEstadoRitmo] (Fase 6, Bloque 4.1).
Color colorEstadoRitmo(EstadoRitmo estado) => switch (estado) {
      EstadoRitmo.vaBien => ColoresApp.exito,
      EstadoRitmo.justo => ColoresApp.atencion,
      EstadoRitmo.excedido => ColoresApp.peligro,
    };

/// Variante para texto (4.5:1) de [colorEstadoRitmo].
Color colorTextoEstadoRitmo(EstadoRitmo estado) => switch (estado) {
      EstadoRitmo.vaBien => ColoresApp.exitoTexto,
      EstadoRitmo.justo => ColoresApp.atencionTexto,
      EstadoRitmo.excedido => ColoresApp.peligroTexto,
    };
