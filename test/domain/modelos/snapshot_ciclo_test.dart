import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:test/test.dart';

SnapshotCiclo _snapshot() => SnapshotCiclo(
      cicloId: '2026-07',
      fechaCierre: DateTime(2026, 8, 12, 9, 30),
      ingresoTotal: const Dinero.pesos(87000),
      metaApartado: const Dinero.pesos(34800),
      totalGastado: const Dinero.pesos(42674),
      renglones: const [
        RenglonSnapshot(
          categoriaId: 'super',
          nombre: 'Súper',
          emoji: '🛒',
          presupuestoCentavos: Dinero.pesos(8000),
          realCentavos: Dinero.pesos(7500),
          conteoMovimientos: 12,
        ),
      ],
    );

void main() {
  group('SnapshotCiclo', () {
    test('apartado es ingresoTotal - totalGastado', () {
      expect(_snapshot().apartado, const Dinero.pesos(44326));
    });

    test('ida y vuelta de JSON conserva todos los campos', () {
      final original = _snapshot();
      final reconstruido = SnapshotCiclo.fromJson(original.toJson());
      expect(reconstruido, original);
    });

    test('toJson siempre incluye las claves de extras, aunque sean cero', () {
      final json = _snapshot().toJson();
      expect(json['extraAApartadoCentavos'], 0);
      expect(json['extraAGastoCentavos'], 0);
    });

    test('fromJson sin las claves de extras (snapshot viejo) las lee como cero', () {
      final json = _snapshot().toJson()
        ..remove('extraAApartadoCentavos')
        ..remove('extraAGastoCentavos');
      final reconstruido = SnapshotCiclo.fromJson(json);
      expect(reconstruido.extraAApartado, const Dinero.cero());
      expect(reconstruido.extraAGasto, const Dinero.cero());
      expect(reconstruido.metaBase, reconstruido.metaApartado);
    });

    test('los cuatro getters derivados con extra mixto', () {
      final snapshot = SnapshotCiclo(
        cicloId: '2026-07',
        fechaCierre: DateTime(2026, 8, 12),
        ingresoTotal: const Dinero.pesos(102000),
        metaApartado: const Dinero.pesos(44800),
        totalGastado: const Dinero.pesos(52103),
        renglones: const [],
        extraAApartado: const Dinero.pesos(10000),
        extraAGasto: const Dinero.pesos(5000),
      );
      expect(snapshot.ingresoExtra, const Dinero.pesos(15000));
      expect(snapshot.ingresoBase, const Dinero.pesos(87000));
      expect(snapshot.metaBase, const Dinero.pesos(34800));
      expect(snapshot.tuvoIngresoExtra, isTrue);
    });

    test('sin extra, tuvoIngresoExtra es falso y metaBase == metaApartado', () {
      final snapshot = _snapshot();
      expect(snapshot.tuvoIngresoExtra, isFalse);
      expect(snapshot.metaBase, snapshot.metaApartado);
      expect(snapshot.ingresoBase, snapshot.ingresoTotal);
    });

    test('ida y vuelta de JSON conserva el nombre y emoji congelados', () {
      final reconstruido = SnapshotCiclo.fromJson(_snapshot().toJson());
      expect(reconstruido.renglones.single.nombre, 'Súper');
      expect(reconstruido.renglones.single.emoji, '🛒');
    });

    test('igualdad y hashCode son consistentes entre dos instancias equivalentes', () {
      expect(_snapshot(), _snapshot());
      expect(_snapshot().hashCode, _snapshot().hashCode);
    });

    test('un totalGastado distinto rompe la igualdad', () {
      final otro = SnapshotCiclo(
        cicloId: _snapshot().cicloId,
        fechaCierre: _snapshot().fechaCierre,
        ingresoTotal: _snapshot().ingresoTotal,
        metaApartado: _snapshot().metaApartado,
        totalGastado: const Dinero.pesos(1),
        renglones: _snapshot().renglones,
      );
      expect(_snapshot() == otro, isFalse);
    });

    test('una lista de renglones de distinto tamaño rompe la igualdad', () {
      final otro = SnapshotCiclo(
        cicloId: _snapshot().cicloId,
        fechaCierre: _snapshot().fechaCierre,
        ingresoTotal: _snapshot().ingresoTotal,
        metaApartado: _snapshot().metaApartado,
        totalGastado: _snapshot().totalGastado,
        renglones: const [],
      );
      expect(_snapshot() == otro, isFalse);
    });
  });

  group('RenglonSnapshot', () {
    const original = RenglonSnapshot(
      categoriaId: 'vivienda',
      nombre: 'Vivienda',
      emoji: '🏠',
      presupuestoCentavos: Dinero.pesos(5000),
      realCentavos: Dinero.pesos(5000),
      conteoMovimientos: 1,
    );

    test('ida y vuelta de JSON', () {
      expect(RenglonSnapshot.fromJson(original.toJson()), original);
    });

    test('igualdad y hashCode son consistentes entre dos instancias equivalentes', () {
      expect(RenglonSnapshot.fromJson(original.toJson()), original);
      expect(RenglonSnapshot.fromJson(original.toJson()).hashCode, original.hashCode);
    });

    test('un conteoMovimientos distinto rompe la igualdad', () {
      const otro = RenglonSnapshot(
        categoriaId: 'vivienda',
        nombre: 'Vivienda',
        emoji: '🏠',
        presupuestoCentavos: Dinero.pesos(5000),
        realCentavos: Dinero.pesos(5000),
        conteoMovimientos: 2,
      );
      expect(original == otro, isFalse);
    });
  });
}
