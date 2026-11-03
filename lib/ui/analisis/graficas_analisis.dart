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

  /// Cierre pronosticado de los días restantes; `null` si ya no quedan.
  final Dinero? proyeccion;

  const GraficaRitmo({
    super.key,
    required this.acumulado,
    required this.diasDelCiclo,
    required this.presupuesto,
    required this.descripcion,
    this.proyeccion,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: descripcion,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(painter: _PintorRitmo(acumulado, diasDelCiclo, presupuesto, proyeccion)),
        ),
      ),
    );
  }
}

/// Verde si el cierre pronosticado cabe en el presupuesto; coral si lo rebasa.
Color colorPronostico(Dinero cierre, Dinero presupuesto) =>
    cierre <= presupuesto ? ColoresApp.verde : ColoresApp.coral;

class _PintorRitmo extends CustomPainter {
  final List<Dinero> acumulado;
  final int dias;
  final Dinero presupuesto;
  final Dinero? proyeccion;

  final Paleta paleta = ColoresApp.actual;

  _PintorRitmo(this.acumulado, this.dias, this.presupuesto, this.proyeccion);

  /// Dibuja la recta de [inicio] a [fin] con trazos de [largo] y huecos de
  /// [hueco].
  void _recta(Canvas canvas, Offset inicio, Offset fin, Paint pintura, double largo, double hueco) {
    final total = (fin - inicio).distance;
    if (total == 0) return;
    final dir = (fin - inicio) / total;
    for (var d = 0.0; d < total; d += largo + hueco) {
      canvas.drawLine(inicio + dir * d, inicio + dir * math.min(d + largo, total), pintura);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ultimo = acumulado.isEmpty ? 0 : acumulado.last.centavos;
    final mayor = [presupuesto.centavos, ultimo, proyeccion?.centavos ?? 0, 1].reduce(math.max);
    final maximo = mayor.toDouble() * 1.08;
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
      _recta(canvas, Offset(0, size.height), Offset(x(dias - 1), y(presupuesto.centavos)), pareja, 6, 6);
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

    // Pronóstico de los días restantes: puntos, para que no se confunda con
    // lo ya gastado ni con el ritmo parejo (rayas).
    final cierre = proyeccion;
    if (cierre != null) {
      final color = colorPronostico(cierre, presupuesto);
      final fin = Offset(x(dias - 1), y(cierre.centavos));
      _recta(
        canvas,
        punta,
        fin,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
        0.1,
        6,
      );
      // Adentro del área, para que el punto final no se corte en la orilla.
      canvas.drawCircle(fin.translate(-4, 0), 4, Paint()..color = color);
    }

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
      old.acumulado != acumulado ||
      old.dias != dias ||
      old.presupuesto != presupuesto ||
      old.proyeccion != proyeccion ||
      old.paleta != paleta;
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

/// Cómo se lee cada barra del reparto: los tres usan los mismos colores
/// (fijos azul, variables oro, lo libre verde) y cambia solo el trazo, de lo
/// ideal a lo estimado (spec-app-finanzas-v2.md §5.7):
/// - [plan]: lo asignado, con contorno y relleno tenue, como una meta.
/// - [real]: lo que llevas hoy, sólido.
/// - [estimado]: al cierre si sigues así, con rayas de pronóstico.
enum EstiloReparto { plan, real, estimado }

/// Color de las fijas en el reparto.
Color get colorFijas => ColoresApp.azul;

/// Color de las variables en el reparto.
Color get colorVariables => ColoresApp.oro;

/// Color de lo libre: el apartado ideal en el plan, lo que sobra en lo real
/// y en lo estimado.
Color get colorLibre => ColoresApp.verde;

/// El color de una parte según el estilo de la barra.
Color colorEnEstilo(Color base, EstiloReparto estilo) => switch (estilo) {
      EstiloReparto.plan => base.withValues(alpha: 0.2),
      EstiloReparto.real => base,
      EstiloReparto.estimado => base.withValues(alpha: 0.8),
    };

/// Fijas, variables y lo libre sobre lo que entra (spec-app-finanzas-v2.md
/// §5.7). En el plan, lo libre es [apartado] y lo que queda sin asignar se
/// ve como el fondo; en lo real y lo estimado, lo libre es lo que sobra. Si
/// lo pintado pasa lo que entra, la barra mide eso y una marca muestra dónde
/// termina lo que entra.
class BarraReparto extends StatelessWidget {
  final Dinero ingreso;
  final Dinero fijas;
  final Dinero variables;
  final Dinero apartado;
  final EstiloReparto estilo;
  final String descripcion;

  const BarraReparto({
    super.key,
    required this.ingreso,
    required this.fijas,
    required this.variables,
    this.apartado = const Dinero.cero(),
    required this.estilo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: descripcion,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 22,
          width: double.infinity,
          child: CustomPaint(painter: _PintorReparto(ingreso, fijas, variables, apartado, estilo)),
        ),
      ),
    );
  }
}

/// Cuadrito de la leyenda, con el mismo trazo que su barra.
class MuestraReparto extends StatelessWidget {
  final Color color;
  final EstiloReparto estilo;

  const MuestraReparto({super.key, required this.color, required this.estilo});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 12,
        height: 12,
        child: CustomPaint(painter: _PintorMuestra(color, estilo)),
      );
}

/// Contorno del plan: cada parte con su color entero, dentro de su espacio.
void _contornear(Canvas canvas, Rect parte, Color color) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(parte.deflate(1.5), const Radius.circular(6)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color,
  );
}

/// Rayas diagonales del pronóstico (como la línea punteada del ritmo).
void _rayar(Canvas canvas, Rect area, double alto) {
  canvas.save();
  canvas.clipRect(area);
  final raya = Paint()
    ..color = ColoresApp.tarjeta.withValues(alpha: 0.55)
    ..strokeWidth = 2.5;
  for (var x = area.left - alto; x < area.right; x += 7) {
    canvas.drawLine(Offset(x, area.bottom), Offset(x + alto, area.top), raya);
  }
  canvas.restore();
}

class _PintorReparto extends CustomPainter {
  final Dinero ingreso;
  final Dinero fijas;
  final Dinero variables;
  final Dinero apartado;
  final EstiloReparto estilo;
  final Paleta paleta = ColoresApp.actual;

  _PintorReparto(this.ingreso, this.fijas, this.variables, this.apartado, this.estilo);

  @override
  void paint(Canvas canvas, Size size) {
    final esPlan = estilo == EstiloReparto.plan;
    final ocupado = fijas.centavos + variables.centavos + (esPlan ? apartado.centavos : 0);
    final libre = esPlan ? apartado.centavos : math.max(ingreso.centavos - ocupado, 0);
    final escala = math.max(math.max(ingreso.centavos, ocupado), 1).toDouble();
    double ancho(int centavos) => size.width * centavos / escala;
    final forma = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(forma);
    canvas.drawRect(Offset.zero & size, Paint()..color = ColoresApp.pista);

    var x = 0.0;
    for (final (centavos, color) in [
      (fijas.centavos, colorFijas),
      (variables.centavos, colorVariables),
      (libre, colorLibre),
    ]) {
      final w = ancho(centavos);
      final parte = Rect.fromLTWH(x, 0, w, size.height);
      canvas.drawRect(parte, Paint()..color = colorEnEstilo(color, estilo));
      if (esPlan && w > 0) _contornear(canvas, parte, color);
      x += w;
    }
    // En el plan cada parte ya tiene su contorno; en las otras, un hilo del
    // fondo las separa.
    if (!esPlan) _separar(canvas, size, ancho, x);
    if (estilo == EstiloReparto.estimado) _rayar(canvas, Rect.fromLTWH(0, 0, x, size.height), size.height);
    canvas.restore();
    _marcarIngreso(canvas, size, ancho, ocupado);
  }

  void _separar(Canvas canvas, Size size, double Function(int) ancho, double fin) {
    final separador = Paint()
      ..color = ColoresApp.tarjeta
      ..strokeWidth = 2;
    var corte = 0.0;
    for (final centavos in [fijas.centavos, variables.centavos]) {
      corte += ancho(centavos);
      if (corte > 0 && corte < fin) canvas.drawLine(Offset(corte, 0), Offset(corte, size.height), separador);
    }
  }

  void _marcarIngreso(Canvas canvas, Size size, double Function(int) ancho, int ocupado) {
    if (ocupado > ingreso.centavos && ingreso.esPositivo) {
      final marca = ancho(ingreso.centavos);
      canvas.drawLine(
        Offset(marca, -3),
        Offset(marca, size.height + 3),
        Paint()
          ..color = ColoresApp.coralTexto
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorReparto old) =>
      old.ingreso != ingreso ||
      old.fijas != fijas ||
      old.variables != variables ||
      old.apartado != apartado ||
      old.estilo != estilo ||
      old.paleta != paleta;
}

class _PintorMuestra extends CustomPainter {
  final Color color;
  final EstiloReparto estilo;
  final Paleta paleta = ColoresApp.actual;

  _PintorMuestra(this.color, this.estilo);

  @override
  void paint(Canvas canvas, Size size) {
    final forma = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.save();
    canvas.clipRRect(forma);
    canvas.drawRect(Offset.zero & size, Paint()..color = colorEnEstilo(color, estilo));
    if (estilo == EstiloReparto.estimado) _rayar(canvas, Offset.zero & size, size.height);
    canvas.restore();
    if (estilo == EstiloReparto.plan) _contornear(canvas, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(covariant _PintorMuestra old) =>
      old.color != color || old.estilo != estilo || old.paleta != paleta;
}
