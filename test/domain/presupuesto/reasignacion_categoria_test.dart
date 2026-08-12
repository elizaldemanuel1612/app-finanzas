import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/presupuesto/reasignacion_categoria.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);

CategoriaVariable _categoria(String id, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(1200),
    );

Movimiento _mov(String categoriaId) {
  final r = crearMovimiento(
    clientId: 'a12345678',
    fecha: DateTime(2026, 7, 15),
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(100),
    categoriaId: categoriaId,
    medio: MedioPago.tarjeta,
    descripcion: categoriaId,
    origenCaptura: OrigenCaptura.manual,
  ) as Exito<Movimiento>;
  return r.valor;
}

void main() {
  group('reasignarMovimiento', () {
    test('reasigna correctamente a una categoría activa distinta', () {
      final movimiento = _mov('super');
      final destino = _categoria('transporte');
      final resultado = reasignarMovimiento(movimiento: movimiento, destino: destino);
      expect(resultado, isA<Exito<Movimiento>>());
      final reasignado = (resultado as Exito<Movimiento>).valor;
      expect(reasignado.categoriaId, 'transporte');
      // El resto del movimiento no cambia.
      expect(reasignado.cicloId, movimiento.cicloId);
      expect(reasignado.monto, movimiento.monto);
    });

    test('falla si el destino es la misma categoría de origen', () {
      final movimiento = _mov('super');
      final destino = _categoria('super');
      final resultado = reasignarMovimiento(movimiento: movimiento, destino: destino);
      expect(resultado, isA<Falla<Movimiento>>());
    });

    test('falla si el destino está desactivado', () {
      final movimiento = _mov('super');
      final destino = _categoria('transporte', activa: false);
      final resultado = reasignarMovimiento(movimiento: movimiento, destino: destino);
      expect(resultado, isA<Falla<Movimiento>>());
    });
  });
}
