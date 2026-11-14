import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/ciclos_para_consultar.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);

Movimiento _mov(String id, DateTime fecha, int pesos, {EstadoMovimiento estado = EstadoMovimiento.activo}) {
  final r = crearMovimiento(
    clientId: 'movimiento-$id',
    fecha: fecha,
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(pesos),
    categoriaId: 'super',
    medio: MedioPago.tarjeta,
    descripcion: 'super',
    origenCaptura: OrigenCaptura.manual,
  ) as Exito<Movimiento>;
  return r.valor.copyWith(estado: estado);
}

void main() {
  final enCurso = _calculadora.calcularPara(DateTime(2026, 11, 14)); // 2026-11
  final septiembre = _calculadora.calcularPara(DateTime(2026, 9, 20)); // 2026-09
  final septiembreCerrado = CicloGuardado(
    ciclo: Ciclo(
      id: septiembre.id,
      fechaInicio: septiembre.fechaInicio,
      fechaFin: septiembre.fechaFin,
      etiqueta: septiembre.etiqueta,
      estado: EstadoCiclo.cerrado,
    ),
  );

  test('el ciclo en curso y los que tienen gastos, del más reciente al más viejo', () {
    final lista = ciclosParaConsultar(
      enCurso: enCurso,
      movimientos: [
        _mov('a', DateTime(2026, 9, 20), 100),
        _mov('b', DateTime(2026, 9, 25), 50),
        _mov('c', DateTime(2026, 10, 15), 300),
        // Anulado: no cuenta, y un ciclo con solo anulados no aparece.
        _mov('d', DateTime(2026, 7, 20), 999, estado: EstadoMovimiento.anulado),
        _mov('e', DateTime(2026, 9, 21), 999, estado: EstadoMovimiento.anulado),
      ],
      guardados: [septiembreCerrado],
      calculadora: _calculadora,
    );
    expect(lista.map((c) => c.ciclo.id), ['2026-11', '2026-10', '2026-09']);
    // Sin gastos todavía, el ciclo en curso aparece igual.
    expect(lista[0].cuantos, 0);
    expect(lista[0].totalCentavos, 0);
    expect(lista[0].cerrado, isFalse);
    // Sin guardar: abierto, con fechas de la calculadora.
    expect(lista[1].cerrado, isFalse);
    expect(lista[1].ciclo.fechaInicio, DateTime(2026, 10, 12));
    // Guardado como cerrado.
    expect(lista[2].cerrado, isTrue);
    expect(lista[2].cuantos, 2);
    expect(lista[2].totalCentavos, 15000);
  });

  test('si el ciclo en curso está guardado, se usa su estado', () {
    final reabierto = CicloGuardado(ciclo: enCurso);
    final lista = ciclosParaConsultar(
      enCurso: enCurso,
      movimientos: [_mov('a', DateTime(2026, 11, 13), 80)],
      guardados: [reabierto],
      calculadora: _calculadora,
    );
    expect(lista.single.ciclo, same(reabierto.ciclo));
    expect(lista.single.cuantos, 1);
  });
}
