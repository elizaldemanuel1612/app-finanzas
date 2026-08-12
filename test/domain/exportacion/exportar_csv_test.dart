import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/exportacion/exportar_csv.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

final _super = const CategoriaVariable(
  id: 'super',
  nombre: 'Súper/Comida',
  emoji: '🛒',
  activa: true,
  esNecesaria: true,
  presupuestoMensualCentavos: Dinero.pesos(6000),
);

Movimiento _mov({
  required String clientId,
  required Dinero monto,
  String descripcion = 'Compra',
  String categoriaId = 'super',
  EstadoMovimiento estado = EstadoMovimiento.activo,
  OrigenCaptura origen = OrigenCaptura.manual,
}) =>
    Movimiento(
      clientId: clientId,
      fecha: DateTime(2026, 7, 16),
      cicloId: '2026-07',
      periodoNatural: '2026-07',
      monto: monto,
      categoriaId: categoriaId,
      medio: MedioPago.tarjeta,
      descripcion: descripcion,
      estado: estado,
      origenCaptura: origen,
    );

void main() {
  test('incluye BOM UTF-8 al inicio', () {
    final csv = exportarMovimientosCsv(movimientos: const [], categorias: const []);
    expect(csv.startsWith('﻿'), isTrue);
  });

  test('encabezados en español, en orden fijo', () {
    final csv = exportarMovimientosCsv(movimientos: const [], categorias: const []);
    final primeraLinea = csv.replaceFirst('﻿', '').split('\n').first;
    expect(
      primeraLinea,
      'Fecha,Categoría,Descripción,Monto,Medio de pago,Estado,Origen de captura',
    );
  });

  test('monto como texto plano, sin símbolo ni separador de miles', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(1234))],
      categorias: [_super],
    );
    expect(csv, contains(',1234.00,'));
  });

  test('monto negativo se exporta con signo', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero(-99))],
      categorias: [_super],
    );
    expect(csv, contains(',-0.99,'));
  });

  test('usa el nombre de la categoría, no su id', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(10))],
      categorias: [_super],
    );
    expect(csv, contains('Súper/Comida'));
  });

  test('categoría desconocida: cae al id sin romper', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(10), categoriaId: 'fantasma')],
      categorias: const [],
    );
    expect(csv, contains('fantasma'));
  });

  test('campo con coma se encierra entre comillas (RFC 4180)', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(10), descripcion: 'Café, pan')],
      categorias: [_super],
    );
    expect(csv, contains('"Café, pan"'));
  });

  test('comilla interna se duplica (RFC 4180)', () {
    final csv = exportarMovimientosCsv(
      movimientos: [
        _mov(clientId: 'a', monto: const Dinero.pesos(10), descripcion: 'Le dijo "hola"'),
      ],
      categorias: [_super],
    );
    expect(csv, contains('"Le dijo ""hola"""'));
  });

  test('fecha en ISO 8601, estado y origen en su renglón propio', () {
    final csv = exportarMovimientosCsv(
      movimientos: [
        _mov(
          clientId: 'a',
          monto: const Dinero.pesos(10),
          estado: EstadoMovimiento.propuesto,
          origen: OrigenCaptura.ticket,
        ),
      ],
      categorias: [_super],
    );
    expect(csv, contains(DateTime(2026, 7, 16).toIso8601String()));
    expect(csv, contains(',tarjeta,propuesto,ticket'));
  });

  test('descripción que empieza con = se antepone con comilla (CSV injection)', () {
    final csv = exportarMovimientosCsv(
      movimientos: [
        _mov(clientId: 'a', monto: const Dinero.pesos(10), descripcion: '=cmd|somecommand'),
      ],
      categorias: [_super],
    );
    expect(csv, contains("'=cmd|somecommand"));
  });

  test('CSV injection con comillas: la neutralización y el escapado RFC 4180 se combinan', () {
    final csv = exportarMovimientosCsv(
      movimientos: [
        _mov(clientId: 'a', monto: const Dinero.pesos(10), descripcion: '=HYPERLINK("http://evil")'),
      ],
      categorias: [_super],
    );
    // La comilla que neutraliza la fórmula va primero; las comillas internas
    // del texto original se duplican después, como cualquier otro campo con
    // comillas (RFC 4180) — ambos mecanismos son independientes.
    expect(csv, contains('"\'=HYPERLINK(""http://evil"")"'));
  });

  test('categoría que empieza con @ se antepone con comilla (CSV injection)', () {
    final categoriaMaliciosa = CategoriaVariable(
      id: 'mal',
      nombre: '@SUM(1+1)',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: const Dinero.pesos(100),
    );
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(10), categoriaId: 'mal')],
      categorias: [categoriaMaliciosa],
    );
    expect(csv, contains('\'@SUM(1+1)'));
  });

  test('descripción con +, - o tab al inicio también se neutraliza', () {
    for (final peligrosa in ['+1+1', '-2+3', '\tcmd']) {
      final csv = exportarMovimientosCsv(
        movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(10), descripcion: peligrosa)],
        categorias: [_super],
      );
      expect(csv, contains("'$peligrosa"));
    }
  });

  test('monto negativo NO se neutraliza: sigue siendo número, no texto', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero(-150))],
      categorias: [_super],
    );
    expect(csv, contains(',-1.50,'));
    expect(csv, isNot(contains("'-1.50")));
  });

  test('descripción sin caracteres de fórmula no se toca', () {
    final csv = exportarMovimientosCsv(
      movimientos: [_mov(clientId: 'a', monto: const Dinero.pesos(10), descripcion: 'Café normal')],
      categorias: [_super],
    );
    expect(csv, contains('Café normal'));
    expect(csv, isNot(contains("'Café normal")));
  });

  test('varios movimientos: una fila por cada uno', () {
    final csv = exportarMovimientosCsv(
      movimientos: [
        _mov(clientId: 'a', monto: const Dinero.pesos(10)),
        _mov(clientId: 'b', monto: const Dinero.pesos(20)),
      ],
      categorias: [_super],
    );
    final lineas = csv.trim().split('\n');
    expect(lineas, hasLength(3)); // encabezado + 2 filas
  });
}
