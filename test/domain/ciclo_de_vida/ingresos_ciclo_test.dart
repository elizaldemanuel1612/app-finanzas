import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/ingresos_ciclo.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:test/test.dart';

IngresoExtra _extra({
  String id = 'ing-1',
  String cicloId = '2026-07',
  Dinero monto = const Dinero.pesos(15000),
  DestinoExtra destino = DestinoExtra.apartado,
  EstadoIngreso estado = EstadoIngreso.activo,
}) =>
    IngresoExtra(
      id: id,
      cicloId: cicloId,
      etiqueta: 'Bono',
      monto: monto,
      fecha: DateTime(2026, 7, 15),
      destino: destino,
      estado: estado,
    );

void main() {
  group('calcularIngresosDelCiclo', () {
    test('lista vacía: solo el base', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: const [],
      );
      expect(ingresos.base, const Dinero.pesos(87000));
      expect(ingresos.extraAApartado, const Dinero.cero());
      expect(ingresos.extraAGasto, const Dinero.cero());
      expect(ingresos.extraTotal, const Dinero.cero());
      expect(ingresos.total, const Dinero.pesos(87000));
      expect(ingresos.huboExtra, isFalse);
    });

    test('solo apartado', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [_extra(destino: DestinoExtra.apartado, monto: const Dinero.pesos(15000))],
      );
      expect(ingresos.extraAApartado, const Dinero.pesos(15000));
      expect(ingresos.extraAGasto, const Dinero.cero());
      expect(ingresos.total, const Dinero.pesos(102000));
      expect(ingresos.huboExtra, isTrue);
    });

    test('solo gasto', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [_extra(destino: DestinoExtra.gasto, monto: const Dinero.pesos(15000))],
      );
      expect(ingresos.extraAApartado, const Dinero.cero());
      expect(ingresos.extraAGasto, const Dinero.pesos(15000));
      expect(ingresos.total, const Dinero.pesos(102000));
    });

    test('mixto: uno a cada destino se suman por separado', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [
          _extra(id: 'a', destino: DestinoExtra.apartado, monto: const Dinero.pesos(10000)),
          _extra(id: 'b', destino: DestinoExtra.gasto, monto: const Dinero.pesos(5000)),
        ],
      );
      expect(ingresos.extraAApartado, const Dinero.pesos(10000));
      expect(ingresos.extraAGasto, const Dinero.pesos(5000));
      expect(ingresos.extraTotal, const Dinero.pesos(15000));
      expect(ingresos.total, const Dinero.pesos(102000));
    });

    test('extras de otro cicloId se ignoran', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [_extra(cicloId: '2026-08', monto: const Dinero.pesos(15000))],
      );
      expect(ingresos.huboExtra, isFalse);
    });

    test('extras anulados se ignoran', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [_extra(estado: EstadoIngreso.anulado, monto: const Dinero.pesos(15000))],
      );
      expect(ingresos.huboExtra, isFalse);
    });
  });

  group('calcularMetaDelCiclo', () {
    test('destino apartado sube la meta', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [_extra(destino: DestinoExtra.apartado, monto: const Dinero.pesos(15000))],
      );
      final meta = calcularMetaDelCiclo(metaBase: const Dinero.pesos(34800), ingresos: ingresos);
      expect(meta, const Dinero.pesos(49800));
    });

    test('destino gasto no mueve la meta', () {
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: '2026-07',
        extras: [_extra(destino: DestinoExtra.gasto, monto: const Dinero.pesos(15000))],
      );
      final meta = calcularMetaDelCiclo(metaBase: const Dinero.pesos(34800), ingresos: ingresos);
      expect(meta, const Dinero.pesos(34800));
    });
  });

  group('IngresosDelCiclo.soloBase', () {
    test('construye sin extras', () {
      const ingresos = IngresosDelCiclo.soloBase(Dinero.pesos(87000));
      expect(ingresos.base, const Dinero.pesos(87000));
      expect(ingresos.total, const Dinero.pesos(87000));
      expect(ingresos.huboExtra, isFalse);
    });
  });
}
