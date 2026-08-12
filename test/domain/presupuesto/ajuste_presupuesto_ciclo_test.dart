import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import 'package:test/test.dart';

AjustePresupuestoCiclo _ajuste({
  String cicloId = '2026-07',
  String categoriaId = 'cat-super',
  Dinero deltaCentavos = const Dinero.pesos(100),
}) =>
    AjustePresupuestoCiclo(
      cicloId: cicloId,
      categoriaId: categoriaId,
      deltaCentavos: deltaCentavos,
      cuando: DateTime(2026, 7, 15, 10, 30),
      dispositivo: 'android-1',
    );

CategoriaVariable _variable({
  String id = 'cat-super',
  Dinero presupuesto = const Dinero.pesos(2000),
}) =>
    CategoriaVariable(
      id: id,
      nombre: 'Súper',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: presupuesto,
    );

CategoriaFija _fija({String id = 'cat-renta'}) => CategoriaFija(
      id: id,
      nombre: 'Renta',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: const Dinero.pesos(5000),
      diaDelCiclo: 1,
    );

void main() {
  group('AjustePresupuestoCiclo — igualdad y JSON', () {
    test('dos ajustes con los mismos campos son iguales', () {
      expect(_ajuste(), _ajuste());
      expect(_ajuste().hashCode, _ajuste().hashCode);
    });

    test('difieren si el delta difiere', () {
      expect(_ajuste() == _ajuste(deltaCentavos: const Dinero.pesos(1)), isFalse);
    });

    test('toJson/fromJson hace un viaje redondo exacto', () {
      final original = _ajuste();
      final reconstruido = AjustePresupuestoCiclo.fromJson(original.toJson());
      expect(reconstruido, original);
    });

    test('toJson guarda el delta en centavos', () {
      final json = _ajuste(deltaCentavos: const Dinero.pesos(-50)).toJson();
      expect(json['deltaCentavos'], -5000);
    });

    test('toString incluye datos identificables', () {
      final texto = _ajuste().toString();
      expect(texto, contains('2026-07'));
      expect(texto, contains('cat-super'));
    });
  });

  group('sumarDeltasPorCategoria', () {
    test('lista vacía da un mapa vacío', () {
      expect(sumarDeltasPorCategoria([]), isEmpty);
    });

    test('acumula varios deltas de la misma categoría', () {
      final resultado = sumarDeltasPorCategoria([
        _ajuste(categoriaId: 'a', deltaCentavos: const Dinero.pesos(100)),
        _ajuste(categoriaId: 'a', deltaCentavos: const Dinero.pesos(-30)),
      ]);
      expect(resultado['a'], const Dinero.pesos(70));
    });

    test('mantiene categorías separadas', () {
      final resultado = sumarDeltasPorCategoria([
        _ajuste(categoriaId: 'a', deltaCentavos: const Dinero.pesos(100)),
        _ajuste(categoriaId: 'b', deltaCentavos: const Dinero.pesos(50)),
      ]);
      expect(resultado['a'], const Dinero.pesos(100));
      expect(resultado['b'], const Dinero.pesos(50));
    });
  });

  group('presupuestosEfectivosParaCiclo', () {
    test('sin ajustes del ciclo, el presupuesto base no cambia', () {
      final resultado = presupuestosEfectivosParaCiclo(
        base: [_variable()],
        ajustesDelCiclo: [],
      );
      expect(
        (resultado.single as CategoriaVariable).presupuestoMensualCentavos,
        const Dinero.pesos(2000),
      );
    });

    test('delta positivo aumenta el presupuesto efectivo', () {
      final resultado = presupuestosEfectivosParaCiclo(
        base: [_variable()],
        ajustesDelCiclo: [_ajuste(deltaCentavos: const Dinero.pesos(500))],
      );
      expect(
        (resultado.single as CategoriaVariable).presupuestoMensualCentavos,
        const Dinero.pesos(2500),
      );
    });

    test('delta negativo reduce el presupuesto efectivo', () {
      final resultado = presupuestosEfectivosParaCiclo(
        base: [_variable()],
        ajustesDelCiclo: [_ajuste(deltaCentavos: const Dinero.pesos(-500))],
      );
      expect(
        (resultado.single as CategoriaVariable).presupuestoMensualCentavos,
        const Dinero.pesos(1500),
      );
    });

    test('CategoriaFija pasa sin cambios aunque haya ajustes con su id', () {
      final fija = _fija();
      final resultado = presupuestosEfectivosParaCiclo(
        base: [fija],
        ajustesDelCiclo: [
          _ajuste(categoriaId: fija.id, deltaCentavos: const Dinero.pesos(500)),
        ],
      );
      expect(resultado.single, fija);
    });

    test('clampea a 1 centavo si el delta deja el presupuesto en cero o menos', () {
      final resultado = presupuestosEfectivosParaCiclo(
        base: [_variable(presupuesto: const Dinero.pesos(100))],
        ajustesDelCiclo: [
          _ajuste(deltaCentavos: const Dinero.pesos(-100)),
        ],
      );
      expect(
        (resultado.single as CategoriaVariable).presupuestoMensualCentavos,
        const Dinero(1),
      );
    });

    test('clampea a 1 centavo si el delta deja el presupuesto negativo', () {
      final resultado = presupuestosEfectivosParaCiclo(
        base: [_variable(presupuesto: const Dinero.pesos(100))],
        ajustesDelCiclo: [
          _ajuste(deltaCentavos: const Dinero.pesos(-500)),
        ],
      );
      expect(
        (resultado.single as CategoriaVariable).presupuestoMensualCentavos,
        const Dinero(1),
      );
    });

    test('solo afecta a la categoría de los ajustes, deja las demás intactas', () {
      final otra = _variable(id: 'cat-otra', presupuesto: const Dinero.pesos(300));
      final resultado = presupuestosEfectivosParaCiclo(
        base: [_variable(), otra],
        ajustesDelCiclo: [_ajuste(deltaCentavos: const Dinero.pesos(500))],
      );
      final otraEfectiva =
          resultado.firstWhere((c) => c.id == 'cat-otra') as CategoriaVariable;
      expect(otraEfectiva.presupuestoMensualCentavos, const Dinero.pesos(300));
    });
  });
}
