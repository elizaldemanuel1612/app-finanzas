import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/ciclo_comparable.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

Ciclo _oct(EstadoCiclo estado) =>
    Ciclo(id: '2026-10', fechaInicio: DateTime(2026, 10, 1), fechaFin: DateTime(2026, 10, 31), etiqueta: 'Oct', estado: estado);

var _n = 0;
Movimiento _gasto(DateTime fecha, {EstadoMovimiento estado = EstadoMovimiento.activo}) => Movimiento(
      clientId: 'movimiento-${_n++}',
      fecha: fecha,
      cicloId: '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}',
      periodoNatural: '${fecha.year}-${fecha.month}',
      monto: const Dinero.pesos(10),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: '',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
    );

void main() {
  final cerrado = [CicloGuardado(ciclo: _oct(EstadoCiclo.cerrado))];

  test('cerrado y con registros desde su primera semana: sirve', () {
    expect(
      cicloComparable(anterior: _oct(EstadoCiclo.abierto), guardados: cerrado, movimientos: [_gasto(DateTime(2026, 10, 7, 23))]),
      isTrue,
    );
  });

  test('empezó a registrar a medias: no sirve', () {
    expect(
      cicloComparable(anterior: _oct(EstadoCiclo.abierto), guardados: cerrado, movimientos: [
        _gasto(DateTime(2026, 10, 8)),
        _gasto(DateTime(2026, 9, 2), estado: EstadoMovimiento.anulado),
      ]),
      isFalse,
    );
  });

  test('sin cerrar o sin ningún gasto: no sirve', () {
    expect(
      cicloComparable(anterior: _oct(EstadoCiclo.abierto), guardados: const [], movimientos: [_gasto(DateTime(2026, 9, 2))]),
      isFalse,
    );
    expect(
      cicloComparable(
        anterior: _oct(EstadoCiclo.abierto),
        guardados: [CicloGuardado(ciclo: _oct(EstadoCiclo.abierto))],
        movimientos: [_gasto(DateTime(2026, 9, 2))],
      ),
      isFalse,
    );
    expect(cicloComparable(anterior: _oct(EstadoCiclo.abierto), guardados: cerrado, movimientos: const []), isFalse);
  });
}
