import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/historial_ciclos.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(1); // cortes de mes natural

final _cicloJulio = _calculadora.calcularPara(DateTime(2026, 7, 15)); // "2026-07"
final _cicloJunio = _calculadora.calcularPara(DateTime(2026, 6, 15)); // "2026-06"
final _cicloAgosto = _calculadora.calcularPara(DateTime(2026, 8, 15)); // "2026-08", el "actual"

SnapshotCiclo _snapshot({
  required String cicloId,
  required Dinero totalGastado,
  Dinero extraAApartado = const Dinero.cero(),
}) =>
    SnapshotCiclo(
      cicloId: cicloId,
      fechaCierre: DateTime(2026, 8, 1),
      ingresoTotal: const Dinero.pesos(20000),
      metaApartado: const Dinero.pesos(6000),
      totalGastado: totalGastado,
      renglones: const [],
      extraAApartado: extraAApartado,
    );

IngresoExtra _extra({required String cicloId, required Dinero monto}) => IngresoExtra(
      id: 'ing-$cicloId',
      cicloId: cicloId,
      etiqueta: 'Bono',
      monto: monto,
      fecha: DateTime(2026, 7, 20),
      destino: DestinoExtra.apartado,
      estado: EstadoIngreso.activo,
    );

Movimiento _mov({
  required String clientId,
  required DateTime fecha,
  required int pesos,
  EstadoMovimiento estado = EstadoMovimiento.activo,
  OrigenCaptura origen = OrigenCaptura.manual,
}) {
  final r = crearMovimiento(
    clientId: clientId,
    fecha: fecha,
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(pesos),
    categoriaId: 'super',
    medio: MedioPago.tarjeta,
    descripcion: 'super',
    origenCaptura: origen,
  ) as Exito<Movimiento>;
  return r.valor.copyWith(estado: estado);
}

void main() {
  group('calcularHistorialCiclos', () {
    test('ciclo cerrado con snapshot usa la fotografía congelada, no recalcula', () {
      final guardado = CicloGuardado(
        ciclo: _cicloJulio.cerrar().valorOLanza,
        snapshot: _snapshot(cicloId: _cicloJulio.id, totalGastado: const Dinero.pesos(500)),
      );
      // Movimiento activo que, si se recalculara, daría un total distinto.
      final movimientos = [_mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 10), pesos: 9999)];

      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardado],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado, hasLength(1));
      expect(resultado.single.totalGastado, const Dinero.pesos(500));
      expect(resultado.single.tieneSnapshot, isTrue);
      expect(resultado.single.ciclo.estado, EstadoCiclo.cerrado);
    });

    test('ciclo sin CicloGuardado se reconstruye desde movimientos', () {
      final movimientos = [
        _mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 5), pesos: 300),
        _mov(clientId: 'b12345678', fecha: DateTime(2026, 7, 20), pesos: 200),
      ];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado, hasLength(1));
      expect(resultado.single.ciclo.id, _cicloJulio.id);
      expect(resultado.single.totalGastado, const Dinero.pesos(500));
      expect(resultado.single.tieneSnapshot, isFalse);
    });

    test('dos ciclos distintos con movimientos no se cruzan', () {
      final movimientos = [
        _mov(clientId: 'jul12345', fecha: DateTime(2026, 7, 10), pesos: 300),
        _mov(clientId: 'jun12345', fecha: DateTime(2026, 6, 10), pesos: 700),
      ];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado, hasLength(2));
      final julio = resultado.firstWhere((r) => r.ciclo.id == _cicloJulio.id);
      final junio = resultado.firstWhere((r) => r.ciclo.id == _cicloJunio.id);
      expect(julio.totalGastado, const Dinero.pesos(300));
      expect(junio.totalGastado, const Dinero.pesos(700));
    });

    test('movimientos anulados no cuentan en la suma sin snapshot', () {
      final movimientos = [
        _mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 10), pesos: 300),
        _mov(
          clientId: 'b12345678',
          fecha: DateTime(2026, 7, 12),
          pesos: 999,
          estado: EstadoMovimiento.anulado,
        ),
      ];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.totalGastado, const Dinero.pesos(300));
    });

    test('movimientos propuestos no cuentan en la suma sin snapshot', () {
      final movimientos = [
        _mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 10), pesos: 300),
        _mov(
          clientId: 'b12345678',
          fecha: DateTime(2026, 7, 12),
          pesos: 999,
          origen: OrigenCaptura.recurrente,
          estado: EstadoMovimiento.propuesto,
        ),
      ];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.totalGastado, const Dinero.pesos(300));
    });

    test('el ciclo actual se excluye aunque tenga movimientos y esté guardado', () {
      final guardado = CicloGuardado(
        ciclo: _cicloAgosto.cerrar().valorOLanza,
        snapshot: _snapshot(cicloId: _cicloAgosto.id, totalGastado: const Dinero.pesos(1000)),
      );
      final movimientos = [_mov(clientId: 'a12345678', fecha: DateTime(2026, 8, 10), pesos: 300)];

      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardado],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado, isEmpty);
    });

    test('orden más-reciente-primero', () {
      final movimientos = [
        _mov(clientId: 'jun12345', fecha: DateTime(2026, 6, 10), pesos: 100),
        _mov(clientId: 'jul12345', fecha: DateTime(2026, 7, 10), pesos: 200),
      ];
      final mayo = _calculadora.calcularPara(DateTime(2026, 5, 15));
      final guardadoMayo = CicloGuardado(
        ciclo: mayo.cerrar().valorOLanza,
        snapshot: _snapshot(cicloId: mayo.id, totalGastado: const Dinero.pesos(50)),
      );

      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardadoMayo],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado.map((r) => r.ciclo.id).toList(), [_cicloJulio.id, _cicloJunio.id, mayo.id]);
    });

    test('sin ciclos pasados regresa lista vacía, no lanza', () {
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: const [],
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado, isEmpty);
    });

    test('CicloGuardado con snapshot pero sin movimientos para ese id sigue usando la fotografía', () {
      final guardado = CicloGuardado(
        ciclo: _cicloJulio.cerrar().valorOLanza,
        snapshot: _snapshot(cicloId: _cicloJulio.id, totalGastado: const Dinero.pesos(800)),
      );
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardado],
        todosLosMovimientos: const [],
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.totalGastado, const Dinero.pesos(800));
      expect(resultado.single.tieneSnapshot, isTrue);
    });

    test('CicloGuardado sin snapshot cae al camino de reconstrucción desde movimientos', () {
      final guardadoSinSnapshot = CicloGuardado(ciclo: _cicloJulio, snapshot: null);
      final movimientos = [_mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 10), pesos: 400)];

      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardadoSinSnapshot],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado.single.tieneSnapshot, isFalse);
      expect(resultado.single.totalGastado, const Dinero.pesos(400));
    });

    test('CicloGuardado sin snapshot y sin movimientos usa guardado.ciclo con total cero, no lanza', () {
      final guardadoSinSnapshot = CicloGuardado(ciclo: _cicloJulio, snapshot: null);

      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardadoSinSnapshot],
        todosLosMovimientos: const [],
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );

      expect(resultado.single.ciclo, _cicloJulio);
      expect(resultado.single.totalGastado, const Dinero.cero());
      expect(resultado.single.tieneSnapshot, isFalse);
    });

    test('un movimiento migrado participa igual que uno manual en la reconstrucción', () {
      final movimientos = [
        _mov(
          clientId: 'hist-0001',
          fecha: DateTime(2026, 7, 10),
          pesos: 250,
          origen: OrigenCaptura.migracion,
        ),
      ];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.ciclo.id, _cicloJulio.id);
      expect(resultado.single.totalGastado, const Dinero.pesos(250));
    });

    test('con snapshot, ingresoExtra sale de la fotografía congelada', () {
      final guardado = CicloGuardado(
        ciclo: _cicloJulio.cerrar().valorOLanza,
        snapshot: _snapshot(
          cicloId: _cicloJulio.id,
          totalGastado: const Dinero.pesos(500),
          extraAApartado: const Dinero.pesos(15000),
        ),
      );
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: [guardado],
        todosLosMovimientos: const [],
        // Un extra registrado después del cierre no debe mover el resumen
        // (misma regla que el total gastado: el snapshot nunca se recalcula).
        todosLosIngresosExtra: [_extra(cicloId: _cicloJulio.id, monto: const Dinero.pesos(9999999))],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.ingresoExtra, const Dinero.pesos(15000));
      expect(resultado.single.tuvoIngresoExtra, isTrue);
    });

    test('sin snapshot, ingresoExtra se suma de la lista viva de extras', () {
      final movimientos = [_mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 10), pesos: 300)];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: [_extra(cicloId: _cicloJulio.id, monto: const Dinero.pesos(8000))],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.ingresoExtra, const Dinero.pesos(8000));
      expect(resultado.single.tuvoIngresoExtra, isTrue);
    });

    test('sin extras, tuvoIngresoExtra es falso', () {
      final movimientos = [_mov(clientId: 'a12345678', fecha: DateTime(2026, 7, 10), pesos: 300)];
      final resultado = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: movimientos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: _cicloAgosto.id,
      );
      expect(resultado.single.tuvoIngresoExtra, isFalse);
    });
  });

  group('CicloResumen', () {
    test('igualdad y hashCode son consistentes entre instancias equivalentes', () {
      final snapshot = _snapshot(cicloId: _cicloJulio.id, totalGastado: const Dinero.pesos(1));
      final a = CicloResumen(ciclo: _cicloJulio, snapshot: snapshot, totalGastado: const Dinero.pesos(1));
      final b = CicloResumen(ciclo: _cicloJulio, snapshot: snapshot, totalGastado: const Dinero.pesos(1));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('un totalGastado distinto rompe la igualdad', () {
      final snapshot = _snapshot(cicloId: _cicloJulio.id, totalGastado: const Dinero.pesos(1));
      final a = CicloResumen(ciclo: _cicloJulio, snapshot: snapshot, totalGastado: const Dinero.pesos(1));
      final b = CicloResumen(ciclo: _cicloJulio, snapshot: snapshot, totalGastado: const Dinero.pesos(2));
      expect(a == b, isFalse);
    });

    test('tieneSnapshot refleja si snapshot es null', () {
      final conSnapshot = CicloResumen(
        ciclo: _cicloJulio,
        snapshot: _snapshot(cicloId: _cicloJulio.id, totalGastado: const Dinero.pesos(1)),
        totalGastado: const Dinero.pesos(1),
      );
      final sinSnapshot =
          CicloResumen(ciclo: _cicloJulio, snapshot: null, totalGastado: const Dinero.pesos(1));
      expect(conSnapshot.tieneSnapshot, isTrue);
      expect(sinSnapshot.tieneSnapshot, isFalse);
    });
  });
}
