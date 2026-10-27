import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../comun/tema.dart';

/// Gráficas de la pestaña Análisis (spec-app-finanzas-v2.md §5.7),
/// dibujadas sin librerías: así se ven igual en iOS y Android y no suman
/// dependencias. Cada una lleva un `Semantics` con su lectura en texto.

/// Colores por categoría, en orden: los de la marca primero.
List<Color> get coloresCategoria => [
  ColoresApp.azul,
  ColoresApp.oro,
  Color(0xFF3E7CB1),
  ColoresApp.verde,
  ColoresApp.ambar,
  ColoresApp.coral,
  Color(0xFF7C5CBF),
  Color(0xFF14B8A6),
];

/// Para la categoría #i (el resto comparte un gris).
Color colorDeCategoria(int i) => i < coloresCategoria.length ? coloresCategoria[i] : const Color(0xFF94A3B8);

/// Dona de "¿En qué se va?" con el total al centro.
class GraficaDona extends StatelessWidget {
  final List<Dinero> valores;
  final String centroTitulo;
  final String centroValor;
  final String descripcion;

  const GraficaDona({
    super.key,
    required this.valores,
    required this.centroTitulo,
    required this.centroValor,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Semantics(
      label: descripcion,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(
            painter: _PintorDona(valores),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centroTitulo, style: textos.labelSmall),
                  const SizedBox(height: 2),
                  FittedBox(child: Text(centroValor, style: textos.titleMedium)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorDona extends CustomPainter {
  final List<Dinero> valores;

  /// La apariencia con la que se pintó: al cambiarla hay que repintar.
  final Paleta paleta = ColoresApp.actual;

  _PintorDona(this.valores);

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 22.0;
    final rect = Rect.fromLTWH(grosor / 2, grosor / 2, size.width - grosor, size.height - grosor);
    final total = valores.fold<int>(0, (a, d) => a + d.centavos);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = ColoresApp.linea;
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, base);
      return;
    }
    var inicio = -math.pi / 2;
    const separacion = 0.025;
    for (var i = 0; i < valores.length; i++) {
      final barrido = 2 * math.pi * valores[i].centavos / total;
      if (barrido <= 0) continue;
      final dibujo = barrido > separacion * 2 ? barrido - separacion : barrido;
      canvas.drawArc(
        rect,
        inicio,
        dibujo,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor
          ..color = colorDeCategoria(i),
      );
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorDona old) => old.valores != valores || old.paleta != paleta;
}

/// "Ritmo del ciclo": lo acumulado día a día contra la línea pareja del
/// presupuesto de variables.
class GraficaRitmo extends StatelessWidget {
  final List<Dinero> acumulado;
  final int diasDelCiclo;
  final Dinero presupuesto;
  final String descripcion;

  const GraficaRitmo({
    super.key,
    required this.acumulado,
    required this.diasDelCiclo,
    required this.presupuesto,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: descripcion,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(painter: _PintorRitmo(acumulado, diasDelCiclo, presupuesto)),
        ),
      ),
    );
  }
}

class _PintorRitmo extends CustomPainter {
  final List<Dinero> acumulado;
  final int dias;
  final Dinero presupuesto;

  final Paleta paleta = ColoresApp.actual;

  _PintorRitmo(this.acumulado, this.dias, this.presupuesto);

  @override
  void paint(Canvas canvas, Size size) {
    final ultimo = acumulado.isEmpty ? 0 : acumulado.last.centavos;
    final maximo = math.max(math.max(presupuesto.centavos, ultimo), 1).toDouble() * 1.08;
    double x(int dia) => dias <= 1 ? size.width : size.width * dia / (dias - 1);
    double y(int centavos) => size.height - size.height * centavos / maximo;

    // Guías horizontales.
    final guia = Paint()
      ..color = ColoresApp.linea
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final yy = size.height * i / 3;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), guia);
    }

    // Ritmo parejo: de 0 al presupuesto completo.
    if (presupuesto.esPositivo) {
      final pareja = Paint()
        ..color = ColoresApp.oro
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      const largo = 6.0;
      final fin = Offset(x(dias - 1), y(presupuesto.centavos));
      final inicio = Offset(0, size.height);
      final total = (fin - inicio).distance;
      final dir = (fin - inicio) / total;
      for (var d = 0.0; d < total; d += largo * 2) {
        canvas.drawLine(inicio + dir * d, inicio + dir * math.min(d + largo, total), pareja);
      }
    }

    if (acumulado.isEmpty) return;
    final camino = Path()..moveTo(0, y(0));
    for (var i = 0; i < acumulado.length; i++) {
      camino.lineTo(x(i), y(acumulado[i].centavos));
    }
    final relleno = Path.from(camino)
      ..lineTo(x(acumulado.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      relleno,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColoresApp.azul.withValues(alpha: 0.18), ColoresApp.azul.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      camino,
      Paint()
        ..color = ColoresApp.azul
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final punta = Offset(x(acumulado.length - 1), y(ultimo));
    canvas.drawCircle(punta, 5, Paint()..color = ColoresApp.tarjeta);
    canvas.drawCircle(
      punta,
      5,
      Paint()
        ..color = ColoresApp.azul
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorRitmo old) =>
      old.acumulado != acumulado || old.dias != dias || old.presupuesto != presupuesto || old.paleta != paleta;
}

/// Barras verticales con etiqueta abajo; [destacada] va en oro.
class GraficaBarras extends StatelessWidget {
  final List<Dinero> valores;
  final List<String> etiquetas;
  final int? destacada;

  /// Barras que se pintan atenuadas (p. ej. el ciclo en curso).
  final Set<int> atenuadas;
  final String descripcion;

  /// Monto corto encima de cada barra ("$19.8k").
  final bool conMontos;

  const GraficaBarras({
    super.key,
    required this.valores,
    required this.etiquetas,
    required this.descripcion,
    this.destacada,
    this.atenuadas = const {},
    this.conMontos = false,
  });

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<int>(0, (a, d) => math.max(a, d.centavos));
    final textos = Theme.of(context).textTheme;
    return Semantics(
      label: descripcion,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < valores.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (conMontos) ...[
                          FittedBox(child: Text(montoCorto(valores[i]), style: textos.labelSmall)),
                          const SizedBox(height: 4),
                        ],
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: maximo == 0 ? 0.02 : math.max(valores[i].centavos / maximo, 0.02),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == destacada
                                      ? ColoresApp.oro
                                      : atenuadas.contains(i)
                                          ? ColoresApp.azul.withValues(alpha: 0.35)
                                          : ColoresApp.azul,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(etiquetas[i], style: textos.labelSmall, maxLines: 1),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra horizontal de proporción (0–1) con fondo gris niebla.
class BarraProporcion extends StatelessWidget {
  final double valor;
  final Color color;
  final double alto;

  const BarraProporcion({super.key, required this.valor, required this.color, this.alto = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(height: alto, color: ColoresApp.linea),
          FractionallySizedBox(
            widthFactor: valor.clamp(0.0, 1.0),
            child: Container(height: alto, color: color),
          ),
        ],
      ),
    );
  }
}

/// "$19.8k" para miles, "$850" debajo de mil: cabe arriba de una barra.
String montoCorto(Dinero d) {
  final pesos = d.centavos ~/ 100;
  if (pesos < 1000) return '\$$pesos';
  final decimas = (pesos + 50) ~/ 100;
  return '\$${decimas ~/ 10}.${decimas % 10}k';
}
