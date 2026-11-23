// Simulador del pronóstico de cierre (docs/modelo-pronostico-ciclo.md §9):
// genera ciclos de gasto parecidos a los de una persona real, y para cada
// ciclo y cada día compara lo que cada variante del pronóstico habría dicho
// ese día contra lo que de verdad se gastó al cierre.
//
//   dart run tool/simular_pronostico/simular.dart
//
// No toca datos de nadie: todo sale de un generador con semilla.
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_categoria.dart';
import 'package:app_finanzas/domain/pronostico/punto_monto.dart';

const diasCiclo = 30;
const ciclosPorSemilla = 9;
const semillas = 40;

/// Un tipo de categoría: cómo caen sus gastos dentro de un ciclo.
typedef Generador = List<(int dia, double pesos)> Function(Random r, DateTime inicio);

double _ruido(Random r, double centro, double pct) => centro * (1 + (r.nextDouble() * 2 - 1) * pct);

final Map<String, (double presupuesto, Generador g)> arquetipos = {
  // Un pago al inicio (colegiatura, pensión): Victoria.
  'pagoAlInicio': (3000, (r, _) => [
        (r.nextInt(4), _ruido(r, 2950, 0.03)),
        if (r.nextDouble() < 0.2) (5 + r.nextInt(20), _ruido(r, 200, 0.5)),
      ]),
  // Un pago chico en un día cualquiera: corte de cabello.
  'unaVezCualquierDia': (150, (r, _) => [(r.nextInt(26), 150.0)]),
  // Una transferencia a mitad del ciclo.
  'unaVezAMitad': (3000, (r, _) => [(10 + r.nextInt(10), 3000.0)]),
  // Súper: dos o tres compras por semana, más fuertes en fin de semana.
  'super': (8000, (r, inicio) => [
        for (var d = 0; d < diasCiclo; d++)
          if (r.nextDouble() < (inicio.add(Duration(days: d)).weekday >= 6 ? 0.55 : 0.2))
            (d, _ruido(r, inicio.add(Duration(days: d)).weekday >= 6 ? 1100 : 550, 0.4)),
      ]),
  // Salidas: fines de semana, a veces una cara.
  'salidas': (8000, (r, inicio) => [
        for (var d = 0; d < diasCiclo; d++)
          if (inicio.add(Duration(days: d)).weekday >= 5 && r.nextDouble() < 0.6)
            (d, r.nextDouble() < 0.1 ? _ruido(r, 2800, 0.2) : _ruido(r, 800, 0.5)),
      ]),
  // Auto: gasolina cada ~8 días y de vez en cuando un servicio.
  'auto': (3800, (r, _) => [
        for (var d = r.nextInt(6); d < diasCiclo; d += 6 + r.nextInt(5)) (d, _ruido(r, 900, 0.12)),
        if (r.nextDouble() < 0.15) (r.nextInt(diasCiclo), _ruido(r, 2500, 0.2)),
      ]),
  // Salud: a golpes, a veces nada, a veces mucho.
  'salud': (900, (r, _) => [
        for (var i = r.nextInt(4); i > 0; i--) (r.nextInt(diasCiclo), _ruido(r, 500, 0.6)),
        if (r.nextDouble() < 0.1) (r.nextInt(diasCiclo), _ruido(r, 3000, 0.3)),
      ]),
  // Hormiga: casi diario, montos chicos.
  'hormiga': (2500, (r, _) => [
        for (var d = 0; d < diasCiclo; d++)
          if (r.nextDouble() < 0.8) (d, _ruido(r, 100, 0.5)),
      ]),
  // Quincenal: fuerte al inicio y a la mitad.
  'quincenal': (4000, (r, _) => [
        (r.nextInt(3), _ruido(r, 2000, 0.1)),
        (14 + r.nextInt(3), _ruido(r, 2000, 0.1)),
      ]),
  // Muchas compras, casi todas en la primera semana (útiles, despensa del mes).
  'frecuenteAlInicio': (3000, (r, _) => [
        for (var i = 0; i < 9 + r.nextInt(4); i++)
          (r.nextDouble() < 0.8 ? r.nextInt(8) : 8 + r.nextInt(22), _ruido(r, 280, 0.5)),
      ]),
  // Extras: de cero a cuatro, cuando sea.
  'extras': (1500, (r, _) => [
        for (var i = r.nextInt(5); i > 0; i--) (r.nextInt(diasCiclo), _ruido(r, 450, 0.6)),
      ]),
};

/// Cada ciclo es distinto: en las categorías de gasto repartido, un ciclo
/// puede salir hasta 35 % más caro o más barato que lo habitual.
List<(int, double)> _conNivel(Random r, String arquetipo, List<(int, double)> gastos) {
  if (!const {'super', 'salidas', 'hormiga', 'auto', 'extras', 'frecuenteAlInicio'}.contains(arquetipo)) return gastos;
  final nivel = 0.65 + r.nextDouble() * 0.7;
  return [for (final (d, p) in gastos) (d, p * nivel)];
}

/// Lo que cada variante necesita para pronosticar un día.
class Entrada {
  final CategoriaVariable categoria;
  final DateTime inicio, fin, hoy;
  final List<PuntoMonto> actual; // del ciclo en curso, hasta hoy
  final List<List<PuntoMonto>> cerrados; // reciente → antiguo, completos
  final List<DateTime> iniciosCerrados;
  Entrada(this.categoria, this.inicio, this.fin, this.hoy, this.actual, this.cerrados, this.iniciosCerrados);

  double get observado => actual.fold(0.0, (a, p) => a + p.monto);
  int get dia => hoy.difference(inicio).inDays + 1;
  double get avanceCalendario => dia / diasCiclo;
}

typedef Variante = double Function(Entrada e);

/// El modelo real, con o sin la posición dentro del ciclo (§3.2).
double modelo(Entrada e, {required bool conPosicion}) => calcularPronosticoCategoria(
      categoria: e.categoria,
      cicloId: 'x',
      fechaInicioCiclo: e.inicio,
      fechaFinCiclo: e.fin,
      hoy: e.hoy,
      movimientosCicloActual: e.actual,
      ciclosCerradosRecienteAAntiguo: e.cerrados,
      iniciosCiclosCerradosRecienteAAntiguo: conPosicion ? e.iniciosCerrados : null,
    ).pronosticoP50.centavos.toDouble();

/// Descartada: solo "lo que suele faltar a esta altura", sin mirar el ritmo
/// de este ciclo. Buena en pagos de una vez, peor en gasto repartido.
double restoHistorico(Entrada e) {
  if (e.cerrados.isEmpty) return max(e.categoria.presupuestoMensualCentavos.centavos.toDouble(), e.observado);
  var suma = 0.0;
  for (var j = 0; j < e.cerrados.length; j++) {
    for (final p in e.cerrados[j]) {
      if (p.fecha.difference(e.iniciosCerrados[j]).inDays >= e.dia) suma += p.monto;
    }
  }
  return e.observado + suma / e.cerrados.length;
}

final Map<String, Variante> variantes = {
  'anterior (calendario)': (e) => modelo(e, conPosicion: false),
  'con posicion (vigente)': (e) => modelo(e, conPosicion: true),
  'regla de tres': (e) => e.observado / e.avanceCalendario,
  'solo resto historico': restoHistorico,
};

class Acumulado {
  double absoluto = 0, sesgo = 0, peor = 0;
  int n = 0;
  final errores = <double>[];
  void sumar(double pronostico, double real) {
    final err = (pronostico - real) / real;
    absoluto += err.abs();
    sesgo += err;
    errores.add(err.abs());
    n++;
  }

  String get texto {
    errores.sort();
    final p90 = errores[(errores.length * 0.9).floor().clamp(0, errores.length - 1)];
    return '${(absoluto / n * 100).toStringAsFixed(1).padLeft(5)}%  '
        '${(sesgo / n * 100 >= 0 ? '+' : '')}${(sesgo / n * 100).toStringAsFixed(1).padLeft(5)}%  '
        '${(p90 * 100).toStringAsFixed(0).padLeft(4)}%';
  }
}

final ejemplo = <String>[];

void main() {
  const tramosDia = [(1, 5), (6, 10), (11, 20), (21, 30)];
  const tramosHistoria = [(1, 1), (2, 3), (4, 8)];
  // total[variante][historia][dia]
  final total = {
    for (final v in variantes.keys)
      v: {for (final h in tramosHistoria) h: {for (final d in tramosDia) d: Acumulado()}},
  };
  final porCategoria = {
    for (final v in variantes.keys) v: {for (final a in arquetipos.keys) a: Acumulado()},
  };

  for (var semilla = 0; semilla < semillas; semilla++) {
    final r = Random(semilla);
    final inicios = [for (var k = 0; k < ciclosPorSemilla; k++) DateTime(2026, 1, 12).add(Duration(days: k * diasCiclo))];
    final datos = <String, List<List<PuntoMonto>>>{
      for (final a in arquetipos.entries)
        a.key: [
          for (final inicio in inicios)
            [
              for (final (dia, pesos) in _conNivel(r, a.key, a.value.$2(r, inicio))..sort((x, y) => x.$1.compareTo(y.$1)))
                PuntoMonto(inicio.add(Duration(days: dia, hours: 12)), pesos),
            ],
        ],
    };
    for (var k = 1; k < ciclosPorSemilla; k++) {
      final inicio = inicios[k];
      final fin = inicio.add(const Duration(days: diasCiclo - 1));
      final real = {
        for (final a in arquetipos.keys) a: datos[a]![k].fold(0.0, (s, p) => s + p.monto),
      };
      final realTotal = real.values.reduce((a, b) => a + b);
      for (var dia = 1; dia <= diasCiclo; dia++) {
        final hoy = inicio.add(Duration(days: dia - 1, hours: 23));
        final entradas = {
          for (final a in arquetipos.entries)
            a.key: Entrada(
              CategoriaVariable(
                id: a.key,
                nombre: a.key,
                emoji: 'x',
                activa: true,
                esNecesaria: false,
                presupuestoMensualCentavos: Dinero(a.value.$1.round()),
              ),
              inicio,
              fin,
              hoy,
              [for (final p in datos[a.key]![k]) if (!p.fecha.isAfter(hoy)) p],
              [for (var j = k - 1; j >= 0; j--) datos[a.key]![j]],
              [for (var j = k - 1; j >= 0; j--) inicios[j]],
            ),
        };
        if (semilla == 0 && k == 3 && dia == 10) {
          ejemplo.add('Un ejemplo: día 10 de 30, con 3 ciclos de historial (pesos)');
          ejemplo.add('${'categoría'.padRight(22)}${'llevas'.padLeft(9)}${'antes'.padLeft(9)}${'ahora'.padLeft(9)}${'real'.padLeft(9)}');
          var tl = 0.0, ta = 0.0, tn = 0.0;
          for (final a in arquetipos.keys) {
            final e = entradas[a]!;
            final antes = modelo(e, conPosicion: false), ahora = modelo(e, conPosicion: true);
            tl += e.observado;
            ta += antes;
            tn += ahora;
            ejemplo.add('${a.padRight(22)}${e.observado.round().toString().padLeft(9)}${antes.round().toString().padLeft(9)}'
                '${ahora.round().toString().padLeft(9)}${real[a]!.round().toString().padLeft(9)}');
          }
          ejemplo.add('${'TOTAL'.padRight(22)}${tl.round().toString().padLeft(9)}${ta.round().toString().padLeft(9)}'
              '${tn.round().toString().padLeft(9)}${realTotal.round().toString().padLeft(9)}');
        }
        final th = tramosHistoria.firstWhere((t) => k >= t.$1 && k <= t.$2);
        final td = tramosDia.firstWhere((t) => dia >= t.$1 && dia <= t.$2);
        for (final v in variantes.entries) {
          var suma = 0.0;
          for (final a in arquetipos.keys) {
            final p = v.value(entradas[a]!);
            suma += p;
            if (real[a]! > 0 && dia >= 6 && dia <= 20) porCategoria[v.key]![a]!.sumar(p, real[a]!);
          }
          total[v.key]![th]![td]!.sumar(suma, realTotal);
        }
      }
    }
  }

  ejemplo.forEach(print);
  print('');
  print('Error del estimado TOTAL al cierre (promedio absoluto, sesgo, peor 10 %)');
  for (final h in tramosHistoria) {
    print('\n== Con ${h.$1 == h.$2 ? '${h.$1}' : '${h.$1}-${h.$2}'} ciclo(s) de historial ==');
    print('${'variante'.padRight(26)}${[for (final d in tramosDia) 'días ${d.$1}-${d.$2}'.padRight(24)].join()}');
    for (final v in variantes.keys) {
      print('${v.padRight(26)}${[for (final d in tramosDia) total[v]![h]![d]!.texto.padRight(24)].join()}');
    }
  }
  print('\n== Por tipo de categoría, días 6 a 20 (promedio absoluto, sesgo, peor 10 %) ==');
  for (final a in arquetipos.keys) {
    print('\n$a');
    for (final v in variantes.keys) {
      print('  ${v.padRight(26)}${porCategoria[v]![a]!.texto}');
    }
  }
}
