import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/ciclo_de_vida/alcance.dart';
import '../../domain/ciclo_de_vida/evolucion_ciclos.dart';
import 'tema.dart';

const _bordeSuave = Color(0xFFC9CDE4);
const _relleno = Color(0xFFEDEFF6);

const _bordeBarra = BorderRadius.only(
  topLeft: Radius.circular(9),
  topRight: Radius.circular(9),
  bottomLeft: Radius.circular(4),
  bottomRight: Radius.circular(4),
);

Color _colorPorNivel(NivelAlcance? nivel) => switch (nivel) {
  NivelAlcance.logrado => ColoresApp.verde,
  NivelAlcance.cerca => ColoresApp.ambar,
  NivelAlcance.corto => ColoresApp.coral,
  null => ColoresApp.medio,
};

/// Gráfica «Cuánto has apartado por ciclo» (app-finanzas-fijos-cierre-v6.html
/// §6): una barra por [PuntoEvolucion], con la altura ya resuelta por
/// `calcularEvolucionCiclos` — este widget no calcula nada, solo pinta.
///
/// Sin dependencias nuevas: el repo no trae ninguna librería de gráficas ni
/// un solo `CustomPainter`; sigue el mismo patrón que `barra_ritmo.dart`
/// (`LayoutBuilder` + `Stack` + `Container`s).
class GraficaEvolucion extends StatelessWidget {
  static const double _alturaCarril = 150;
  static const double _alturaEtiquetas = 24;

  final EvolucionCiclos evolucion;

  const GraficaEvolucion({super.key, required this.evolucion});

  String get _resumenSemantico {
    final cerrados = evolucion.puntos
        .where((p) => p.estado == EstadoPunto.cerrado)
        .toList();
    if (cerrados.isEmpty) {
      return 'Gráfica de cuánto has apartado por ciclo, todavía sin ciclos cerrados.';
    }

    var mayor = cerrados.first;
    var menor = cerrados.first;
    for (final p in cerrados) {
      if (p.metricas!.apartado > mayor.metricas!.apartado) mayor = p;
      if (p.metricas!.apartado < menor.metricas!.apartado) menor = p;
    }

    final n = cerrados.length;
    final ciclosTexto = n == 1 ? '1 ciclo cerrado' : '$n ciclos cerrados';
    final promedioTexto = evolucion.promedioAhorroPorMes == null
        ? ''
        : '; promedio de ahorro por mes ${evolucion.promedioAhorroPorMes!.formateado()}';

    if (mayor.cicloId == menor.cicloId) {
      return 'Gráfica de cuánto has apartado por ciclo: $ciclosTexto, '
          '${mayor.etiqueta} con ${mayor.metricas!.apartado.formateado()}$promedioTexto.';
    }

    return 'Gráfica de cuánto has apartado por ciclo: $ciclosTexto; apartaste más en '
        '${mayor.etiqueta} con ${mayor.metricas!.apartado.formateado()}, menos en '
        '${menor.etiqueta} con ${menor.metricas!.apartado.formateado()}$promedioTexto.';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _resumenSemantico,
      excludeSemantics: true,
      child: SizedBox(
        height: _alturaCarril + _alturaEtiquetas,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (evolucion.metaReferencia != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: _alturaEtiquetas + _alturaCarril * evolucion.alturaMeta,
                child: _LineaMeta(meta: evolucion.metaReferencia!),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _alturaEtiquetas,
              height: _alturaCarril,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < evolucion.puntos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _Columna(punto: evolucion.puntos[i])),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _alturaEtiquetas,
              child: Row(
                children: [
                  for (var i = 0; i < evolucion.puntos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        evolucion.puntos[i].etiqueta,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.medio,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineaMeta extends StatelessWidget {
  final Dinero meta;

  const _LineaMeta({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(height: 2, color: _bordeSuave),
        Positioned(
          right: 0,
          top: -14,
          child: ColoredBox(
            color: ColoresApp.tarjeta,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'meta ${meta.formateado()}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.medio,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Columna extends StatelessWidget {
  final PuntoEvolucion punto;

  const _Columna({required this.punto});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final alturaBarra = constraints.maxHeight * punto.alturaRelativa;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: alturaBarra,
              child: _Barra(punto: punto),
            ),
            if (punto.estado != EstadoPunto.sinCierre)
              Positioned(
                left: 0,
                right: 0,
                bottom: alturaBarra + 4,
                child: _MontoAhorrado(punto: punto),
              ),
          ],
        );
      },
    );
  }
}

class _Barra extends StatelessWidget {
  final PuntoEvolucion punto;

  const _Barra({required this.punto});

  @override
  Widget build(BuildContext context) {
    final decoracion = switch (punto.estado) {
      EstadoPunto.sinCierre => BoxDecoration(
        color: _relleno,
        border: Border.all(color: _bordeSuave, width: 2),
        borderRadius: _bordeBarra,
      ),
      EstadoPunto.enCurso => BoxDecoration(
        color: ColoresApp.azul.withValues(alpha: 0.15),
        border: Border.all(color: ColoresApp.azul, width: 2),
        borderRadius: _bordeBarra,
      ),
      EstadoPunto.cerrado => BoxDecoration(
        color: _colorPorNivel(calcularNivelAlcance(punto.metricas!.alcance)),
        borderRadius: _bordeBarra,
      ),
    };
    return Container(decoration: decoracion);
  }
}

/// Etiqueta sobre cada barra: el monto ahorrado (`apartado`), no el % de
/// alcance — la barra ya se escala por monto (ver el docstring de
/// [calcularEvolucionCiclos]), así que la cifra encima debe hablar el
/// mismo idioma que la altura, o el texto y el dibujo se contradicen.
/// El color sigue viniendo del nivel de alcance: cuánto ahorraste y si
/// llegaste a tu meta son dos preguntas distintas, y esta etiqueta solo
/// contesta la primera.
class _MontoAhorrado extends StatelessWidget {
  final PuntoEvolucion punto;

  const _MontoAhorrado({required this.punto});

  @override
  Widget build(BuildContext context) {
    final apartado = punto.metricas?.apartado;
    if (apartado == null) return const SizedBox.shrink();

    final color = punto.estado == EstadoPunto.enCurso
        ? ColoresApp.azul
        : _colorPorNivel(calcularNivelAlcance(punto.metricas!.alcance));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (punto.tuvoIngresoExtra)
          const Text('🎁', style: TextStyle(fontSize: 11)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            apartado.formateado(),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
