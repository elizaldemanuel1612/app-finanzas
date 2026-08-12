import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/alcance.dart';
import 'package:test/test.dart';

void main() {
  group('calcularMetricasApartado', () {
    test('los números del prototipo (app-finanzas-fijos-cierre-v6.html §5)', () {
      final metricas = calcularMetricasApartado(
        ingresoTotal: const Dinero.pesos(87000),
        totalGastado: const Dinero.pesos(42674),
        meta: const Dinero.pesos(34800),
        extraAApartado: const Dinero.cero(),
        extraAGasto: const Dinero.cero(),
      );
      expect(metricas.apartado, const Dinero.pesos(44326));
      expect((metricas.alcance! * 100).round(), 127);
      expect((metricas.tasaDeAhorro! * 100).round(), 51);
      expect(metricas.alcanceSinExtra, isNull);
    });

    test('meta en cero: alcance es null', () {
      final metricas = calcularMetricasApartado(
        ingresoTotal: const Dinero.pesos(1000),
        totalGastado: const Dinero.pesos(400),
        meta: const Dinero.cero(),
        extraAApartado: const Dinero.cero(),
        extraAGasto: const Dinero.cero(),
      );
      expect(metricas.alcance, isNull);
      expect(metricas.tasaDeAhorro, isNotNull);
    });

    test('ingreso en cero: tasaDeAhorro es null', () {
      final metricas = calcularMetricasApartado(
        ingresoTotal: const Dinero.cero(),
        totalGastado: const Dinero.cero(),
        meta: const Dinero.pesos(500),
        extraAApartado: const Dinero.cero(),
        extraAGasto: const Dinero.cero(),
      );
      expect(metricas.tasaDeAhorro, isNull);
      expect(metricas.alcance, isNotNull);
    });

    test('apartado puede ser negativo si se gastó más de lo que entró', () {
      final metricas = calcularMetricasApartado(
        ingresoTotal: const Dinero.pesos(1000),
        totalGastado: const Dinero.pesos(1500),
        meta: const Dinero.pesos(500),
        extraAApartado: const Dinero.cero(),
        extraAGasto: const Dinero.cero(),
      );
      expect(metricas.apartado, const Dinero.pesos(-500));
      expect(metricas.tasaDeAhorro, lessThan(0));
    });

    test('sin extra, alcanceSinExtra siempre es null aunque metaBase sea positiva', () {
      final metricas = calcularMetricasApartado(
        ingresoTotal: const Dinero.pesos(87000),
        totalGastado: const Dinero.pesos(30000),
        meta: const Dinero.pesos(34800),
        extraAApartado: const Dinero.cero(),
        extraAGasto: const Dinero.cero(),
      );
      expect(metricas.alcanceSinExtra, isNull);
    });

    // Tabla de verificación del plan de Fase 5 — filas A y B reproducen los
    // mockups app-finanzas-fijos-cierre-v6.html §5 y app-finanzas-ingresos-
    // ajustes-v11.html §3 al centavo.
    group('tabla A-H', () {
      void verificar({
        required String fila,
        required int basePesos,
        required int extraApartadoPesos,
        required int extraGastoPesos,
        required int gastadoPesos,
        required int metaBasePesos,
        required int metaPesos,
        required int alcanceEsperado,
        required int? sinExtraEsperado,
        required int tasaEsperada,
      }) {
        test(fila, () {
          final extraAApartado = Dinero.pesos(extraApartadoPesos);
          final extraAGasto = Dinero.pesos(extraGastoPesos);
          final ingresoTotal =
              Dinero.pesos(basePesos) + extraAApartado + extraAGasto;
          final metricas = calcularMetricasApartado(
            ingresoTotal: ingresoTotal,
            totalGastado: Dinero.pesos(gastadoPesos),
            meta: Dinero.pesos(metaPesos),
            extraAApartado: extraAApartado,
            extraAGasto: extraAGasto,
          );
          expect((metricas.alcance! * 100).round(), alcanceEsperado, reason: 'alcance');
          expect(
            metricas.alcanceSinExtra == null ? null : (metricas.alcanceSinExtra! * 100).round(),
            sinExtraEsperado,
            reason: 'alcanceSinExtra',
          );
          expect((metricas.tasaDeAhorro! * 100).round(), tasaEsperada, reason: 'tasa');
        });
      }

      verificar(
        fila: 'A — sin extra (v6 §5)',
        basePesos: 87000,
        extraApartadoPesos: 0,
        extraGastoPesos: 0,
        gastadoPesos: 42674,
        metaBasePesos: 34800,
        metaPesos: 34800,
        alcanceEsperado: 127,
        sinExtraEsperado: null,
        tasaEsperada: 51,
      );

      verificar(
        fila: 'B — gasto (v11 §3)',
        basePesos: 87000,
        extraApartadoPesos: 0,
        extraGastoPesos: 15000,
        gastadoPesos: 52103,
        metaBasePesos: 34800,
        metaPesos: 34800,
        alcanceEsperado: 143,
        sinExtraEsperado: 100,
        tasaEsperada: 49,
      );

      verificar(
        fila: 'C — gasto, se lo gastó',
        basePesos: 87000,
        extraApartadoPesos: 0,
        extraGastoPesos: 15000,
        gastadoPesos: 67103,
        metaBasePesos: 34800,
        metaPesos: 34800,
        alcanceEsperado: 100,
        sinExtraEsperado: 57,
        tasaEsperada: 34,
      );

      verificar(
        fila: 'D — apartado, cumplió',
        basePesos: 87000,
        extraApartadoPesos: 15000,
        extraGastoPesos: 0,
        gastadoPesos: 52103,
        metaBasePesos: 34800,
        metaPesos: 49800,
        alcanceEsperado: 100,
        sinExtraEsperado: 100,
        tasaEsperada: 49,
      );

      verificar(
        fila: 'E — apartado, se pasó',
        basePesos: 87000,
        extraApartadoPesos: 15000,
        extraGastoPesos: 0,
        gastadoPesos: 60000,
        metaBasePesos: 34800,
        metaPesos: 49800,
        alcanceEsperado: 84,
        sinExtraEsperado: 78,
        tasaEsperada: 41,
      );

      verificar(
        fila: 'F — apartado, sobre-cumplió',
        basePesos: 87000,
        extraApartadoPesos: 15000,
        extraGastoPesos: 0,
        gastadoPesos: 30000,
        metaBasePesos: 34800,
        metaPesos: 49800,
        alcanceEsperado: 145,
        sinExtraEsperado: 164,
        tasaEsperada: 71,
      );

      verificar(
        fila: 'G — mixto 10k+5k',
        basePesos: 87000,
        extraApartadoPesos: 10000,
        extraGastoPesos: 5000,
        gastadoPesos: 52103,
        metaBasePesos: 34800,
        metaPesos: 44800,
        alcanceEsperado: 111,
        sinExtraEsperado: 100,
        tasaEsperada: 49,
      );

      verificar(
        fila: 'H — metaBase cero',
        basePesos: 87000,
        extraApartadoPesos: 15000,
        extraGastoPesos: 0,
        gastadoPesos: 52103,
        metaBasePesos: 0,
        metaPesos: 15000,
        alcanceEsperado: 333,
        sinExtraEsperado: null,
        tasaEsperada: 49,
      );
    });
  });

  group('calcularNivelAlcance', () {
    test('null pasa a null — meta en cero, no hay contra qué medir', () {
      expect(calcularNivelAlcance(null), isNull);
    });

    test('exactamente 1.0 es logrado, la frontera pertenece al de arriba', () {
      expect(calcularNivelAlcance(1.0), NivelAlcance.logrado);
    });

    test('justo debajo de 1.0 es cerca, no logrado', () {
      expect(calcularNivelAlcance(0.99), NivelAlcance.cerca);
    });

    test('exactamente 0.7 es cerca, la frontera pertenece al de arriba', () {
      expect(calcularNivelAlcance(0.7), NivelAlcance.cerca);
    });

    test('justo debajo de 0.7 es corto', () {
      expect(calcularNivelAlcance(0.69), NivelAlcance.corto);
    });

    test('muy por encima de la meta sigue siendo logrado', () {
      expect(calcularNivelAlcance(2.5), NivelAlcance.logrado);
    });

    test('alcance negativo es corto', () {
      expect(calcularNivelAlcance(-0.5), NivelAlcance.corto);
    });
  });
}
