import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/voz/parser_dictado.dart';
import 'package:test/test.dart';

CategoriaVariable _cat(String id, String nombre) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🏷️',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: const Dinero.pesos(1000),
    );

void main() {
  final categorias = [
    _cat('super', 'Súper/Comida'),
    _cat('auto', 'Auto operación'),
    _cat('terapia', 'Terapia'),
    _cat('salud', 'Salud'),
    _cat('apoyo-victoria', 'Apoyo Victoria'),
  ];

  List<GastoDictado> parsear(String texto) => parsearDictado(texto, categorias: categorias);

  test('"Gasté 480 de súper con tarjeta" — verbo de apertura, categoría literal, tarjeta', () {
    final r = parsear('Gasté 480 de súper con tarjeta');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(480));
    expect(r.single.medio, MedioPago.tarjeta);
    expect(r.single.categoriaId, 'super');
    expect(r.single.descripcion.toLowerCase(), contains('súper'));
  });

  test('"200 de estacionamiento en efectivo" — sin categoría conocida, efectivo', () {
    final r = parsear('200 de estacionamiento en efectivo');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(200));
    expect(r.single.medio, MedioPago.efectivo);
    expect(r.single.categoriaId, isNull);
    expect(r.single.descripcion, 'Estacionamiento');
  });

  test('"mil doscientos de cena ayer" — número en palabras', () {
    final r = parsear('mil doscientos de cena ayer');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(1200));
    expect(r.single.descripcion.toLowerCase(), contains('cena'));
  });

  test('"100 de gasolina, 250 de terapia y 30 de café" — tres gastos en un dictado', () {
    final r = parsear('100 de gasolina, 250 de terapia y 30 de café');
    expect(r, hasLength(3));
    expect(r[0].monto, const Dinero.pesos(100));
    expect(r[1].monto, const Dinero.pesos(250));
    expect(r[1].categoriaId, 'terapia');
    expect(r[2].monto, const Dinero.pesos(30));
    expect(r[2].descripcion.toLowerCase(), contains('café'));
  });

  test('"3 mil 132 del servicio del coche" — dígito mezclado con "mil"', () {
    final r = parsear('3 mil 132 del servicio del coche');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(3132));
    expect(r.single.descripcion.toLowerCase(), contains('servicio'));
  });

  test('"pagué 700 al pediatra en efectivo" — otro verbo de apertura', () {
    final r = parsear('pagué 700 al pediatra en efectivo');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(700));
    expect(r.single.medio, MedioPago.efectivo);
    expect(r.single.descripcion.toLowerCase(), contains('pediatra'));
  });

  test('"200 en pañales para Victoria" — categoría inferida por nombre propio', () {
    final r = parsear('200 en pañales para Victoria');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(200));
    expect(r.single.categoriaId, 'apoyo-victoria');
    expect(r.single.descripcion, contains('Victoria'));
  });

  test('"50 de café con tarjeta y 20 de propina en efectivo" — medio distinto por gasto', () {
    final r = parsear('50 de café con tarjeta y 20 de propina en efectivo');
    expect(r, hasLength(2));
    expect(r[0].medio, MedioPago.tarjeta);
    expect(r[1].medio, MedioPago.efectivo);
  });

  test('sin monto especificado usa tarjeta por defecto', () {
    final r = parsear('35 de café');
    expect(r.single.medio, MedioPago.tarjeta);
  });

  test('descripción capitalizada', () {
    final r = parsear('35 de café');
    expect(r.single.descripcion, startsWith('C'));
  });

  group('límite documentado: "doce tacos de treinta pesos" no adivina', () {
    test('detecta dos montos candidatos en vez de multiplicar', () {
      final r = parsear('doce tacos de treinta pesos');
      expect(r, hasLength(1));
      expect(r.single.esAmbiguo, isTrue);
      expect(r.single.monto, isNull);
      expect(r.single.montosAmbiguos, containsAll([const Dinero.pesos(12), const Dinero.pesos(30)]));
    });
  });

  group('límite documentado: centavos hablados no se interpretan como decimales', () {
    test('"cuarenta y ocho cincuenta" se lee como pesos completos (98), no como \$48.50', () {
      final r = parsear('cuarenta y ocho cincuenta');
      expect(r.single.monto, const Dinero.pesos(98));
    });
  });

  test('frase sin ningún número no produce gastos', () {
    expect(parsear('y eso fue todo'), isEmpty);
  });

  test('frase vacía no produce gastos', () {
    expect(parsear('   '), isEmpty);
  });

  test('"treinta y dos" dentro de un monto no se corta en dos gastos', () {
    final r = parsear('treinta y dos de café');
    expect(r, hasLength(1));
    expect(r.single.monto, const Dinero.pesos(32));
  });
}
