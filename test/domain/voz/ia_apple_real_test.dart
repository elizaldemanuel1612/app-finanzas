import 'dart:convert';
import 'dart:io';

import 'package:app_finanzas/domain/voz/interpretar_gasto.dart';
import 'package:test/test.dart';

import '../../../tool/ia_gasto/frases.dart';

// Respuestas REALES de Apple Intelligence (Foundation Models en la Mac, con
// el mismo esquema e instrucciones que la app) a las frases de
// `tool/ia_gasto/frases.dart`, pasadas por el mismo `completarConIA` que
// usan Siri y la captura (spec §5.6.3). Para volver a medir, ver ese archivo.
void main() {
  final respuestas = {
    for (final r in jsonDecode(File('test/domain/voz/respuestas_apple.json').readAsStringSync()) as List)
      (r as Map)['frase'] as String: r,
  };
  final ctx = contextoDePrueba;

  test('hay una respuesta real por frase', () {
    expect(respuestas.keys.toSet(), {for (final (f, _) in frasesDePrueba) f});
  });

  test('Apple siempre eligió entre las opciones: nunca un nombre inventado', () {
    final opciones = opcionesIAGasto(ctx).toSet();
    for (final r in respuestas.values) {
      expect(opciones, contains(r['categoria']), reason: r['frase'] as String);
    }
  });

  test('reglas + Apple aciertan casi todas las categorías', () {
    var aciertos = 0;
    final fallos = <String>[];
    for (final (frase, esperada) in frasesDePrueba) {
      final g = completarConIA(interpretarFraseGasto(frase, ctx), respuestas[frase]!['categoria'] as String, ctx);
      expect(g.categoriaId == null || ctx.categorias.any((c) => c.id == g.categoriaId), isTrue);
      if (g.categoriaId == esperada) {
        aciertos++;
      } else {
        fallos.add('$frase → ${g.categoriaId}');
      }
    }
    // Medido el 2026-11-15: 20 de 24. Apple: tacos y pizza → Súper, la
    // vacuna del gato → Salud; reglas: "detergente para la ropa" → Ropa (el
    // nombre de la categoría en la frase gana, a propósito). Si baja, algo
    // cambió en las instrucciones, el modelo o las reglas.
    expect(aciertos, greaterThanOrEqualTo(20), reason: fallos.join('\n'));
  });

  test('los montos los dan siempre las reglas, aun con la categoría de Apple', () {
    for (final (frase, _) in frasesDePrueba) {
      final base = interpretarFraseGasto(frase, ctx);
      final g = completarConIA(base, respuestas[frase]!['categoria'] as String, ctx);
      expect(g.monto, base.monto);
      expect(g.fecha, base.fecha);
      expect(g.cuentaId, base.cuentaId);
    }
  });

  test('responde rápido: menos de un segundo por frase ya en marcha', () {
    final tiempos = [for (final r in respuestas.values.skip(1)) r['ms'] as int]..sort();
    expect(tiempos[tiempos.length ~/ 2], lessThan(1000));
  });
}
