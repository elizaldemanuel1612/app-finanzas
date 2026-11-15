import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/gastos_recurrentes.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §5.7, "Lo que se repite" (2026-11-15).

var _n = 0;
Movimiento _g(String descripcion, DateTime fecha, int pesos,
        {String categoria = 'subs', EstadoMovimiento estado = EstadoMovimiento.activo}) =>
    Movimiento(
      clientId: 'g${_n++}',
      fecha: fecha,
      cicloId: 'c',
      periodoNatural: '${fecha.year}-${fecha.month}',
      monto: Dinero.pesos(pesos),
      categoriaId: categoria,
      medio: MedioPago.tarjeta,
      descripcion: descripcion,
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

void main() {
  final hoy = DateTime(2026, 11, 15);

  test('mensual con aumento de precio: toma el último monto y estima el próximo', () {
    final movs = [
      _g('Netflix', DateTime(2026, 7, 3), 199),
      _g('netflix ', DateTime(2026, 8, 3), 199),
      _g('NETFLIX', DateTime(2026, 9, 2), 219),
      _g('Netflix', DateTime(2026, 10, 3), 219),
      _g('Netflix', DateTime(2026, 11, 3, 22), 219),
      _g('Netflix', DateTime(2026, 11, 3, 23), 1, estado: EstadoMovimiento.anulado),
    ];
    final r = detectarRecurrentes(movs, hoy: hoy);
    expect(r, hasLength(1));
    final n = r.single;
    expect(n.nombre, 'Netflix');
    expect(n.categoriaId, 'subs');
    expect(n.frecuencia, FrecuenciaRecurrente.mensual);
    expect(n.frecuencia.etiqueta, 'Cada mes');
    expect(n.monto, Dinero.pesos(219));
    expect(n.veces, 5);
    expect(n.ultimo, DateTime(2026, 11, 3));
    expect(n.proximo, DateTime(2026, 12, 3)); // mensual: el mismo día del mes siguiente
    expect(n.alAnio, Dinero.pesos(219 * 12));
    expect(totalAlAnio(r), Dinero.pesos(219 * 12));
  });

  test('semanal, quincenal y anual; ordenados por lo que cuestan al año', () {
    final movs = [
      for (var i = 0; i < 4; i++) _g('Lavandería', DateTime(2026, 10, 25).add(Duration(days: 7 * i)), 80),
      for (var i = 0; i < 3; i++) _g('Clase de inglés', DateTime(2026, 10, 1).add(Duration(days: 15 * i)), 500),
      _g('Amazon Prime', DateTime(2025, 11, 20), 899),
      _g('Amazon Prime', DateTime(2026, 11, 20), 999),
    ];
    // El de Prime aún no llega: hoy es antes de su segundo pago.
    final r = detectarRecurrentes(movs, hoy: DateTime(2026, 11, 22));
    expect([for (final x in r) (x.nombre, x.frecuencia)], [
      ('Clase de inglés', FrecuenciaRecurrente.quincenal),
      ('Lavandería', FrecuenciaRecurrente.semanal),
      ('Amazon Prime', FrecuenciaRecurrente.anual),
    ]);
  });

  test('no son recurrentes: pocos pagos, irregulares, montos dispares, sin descripción o ya no vigentes', () {
    final movs = [
      _g('Gym', DateTime(2026, 9, 1), 500),
      _g('Gym', DateTime(2026, 10, 1), 500), // solo 2: falta uno
      _g('Café', DateTime(2026, 8, 1), 60),
      _g('Café', DateTime(2026, 8, 31), 60),
      _g('Café', DateTime(2026, 9, 5), 60), // intervalos 30 y 5: irregular
      _g('Café', DateTime(2026, 10, 5), 60),
      _g('Súper', DateTime(2026, 8, 10), 300),
      _g('Súper', DateTime(2026, 9, 10), 1500),
      _g('Súper', DateTime(2026, 10, 10), 2900),
      _g('Súper', DateTime(2026, 11, 10), 600), // montos muy distintos
      _g('', DateTime(2026, 9, 1), 100),
      _g('  ', DateTime(2026, 10, 1), 100),
      _g('', DateTime(2026, 11, 1), 100),
      _g('Spotify', DateTime(2026, 3, 1), 129),
      _g('Spotify', DateTime(2026, 4, 1), 129),
      _g('Spotify', DateTime(2026, 5, 1), 129), // lo dejó de pagar
      _g('Dentista', DateTime(2026, 1, 1), 800),
      _g('Dentista', DateTime(2026, 3, 1), 800),
      _g('Dentista', DateTime(2026, 5, 1), 800), // cada 2 meses: no es una frecuencia
      _g('Uber', DateTime(2026, 11, 1), 90),
      _g('Uber', DateTime(2026, 11, 1, 20), 95), // mismo día: un solo pago
    ];
    expect(detectarRecurrentes(movs, hoy: hoy), isEmpty);
    expect(totalAlAnio(const []), const Dinero.cero());
  });

  test('quincenal con número par de pagos: mediana de los dos de en medio', () {
    final movs = [
      _g('Agua', DateTime(2026, 9, 1), 100),
      _g('Agua', DateTime(2026, 9, 15), 100), // 14
      _g('Agua', DateTime(2026, 10, 1), 100), // 16
      _g('Agua', DateTime(2026, 10, 16), 100), // 15
      _g('Agua', DateTime(2026, 10, 31), 100), // 15
    ];
    final r = detectarRecurrentes(movs, hoy: DateTime(2026, 11, 2)).single;
    expect(r.frecuencia, FrecuenciaRecurrente.quincenal);
    expect(r.proximo, DateTime(2026, 11, 15)); // mediana de 14, 16, 15, 15 = 15
  });

  test('mensual el 31 cae en el último del mes siguiente; anual, en la misma fecha', () {
    final movs = [
      _g('Seguro', DateTime(2026, 7, 31), 400),
      _g('Seguro', DateTime(2026, 8, 31), 400),
      _g('Seguro', DateTime(2026, 9, 30), 400),
      _g('Seguro', DateTime(2026, 10, 31), 400),
      _g('Dominio', DateTime(2025, 2, 10), 300),
      _g('Dominio', DateTime(2026, 2, 10), 300),
    ];
    final r = detectarRecurrentes(movs, hoy: DateTime(2026, 11, 5));
    final seguro = r.firstWhere((x) => x.nombre == 'Seguro');
    expect(seguro.proximo, DateTime(2026, 11, 30));
    final dominio = r.firstWhere((x) => x.nombre == 'Dominio');
    expect(dominio.proximo, DateTime(2027, 2, 10));
  });
}
