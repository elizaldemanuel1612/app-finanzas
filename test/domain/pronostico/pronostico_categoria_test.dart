import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/pronostico/nivel_madurez.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_categoria.dart';
import 'package:app_finanzas/domain/pronostico/punto_monto.dart';
import 'package:app_finanzas/domain/pronostico/subcaptura.dart';
import 'package:test/test.dart';

CategoriaFija _fija({Dinero? monto}) => CategoriaFija(
      id: 'renta',
      nombre: 'Vivienda',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: monto ?? const Dinero.pesos(8000),
      diaDelCiclo: 1,
    );

CategoriaVariable _variable() => const CategoriaVariable(
      id: 'super',
      nombre: 'Súper/Comida',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(6000),
    );

List<PuntoMonto> _ciclo(List<double> montos, {DateTime? desde}) {
  final inicio = desde ?? DateTime(2026, 5, 1);
  return [for (var i = 0; i < montos.length; i++) PuntoMonto(inicio.add(Duration(days: i)), montos[i])];
}

void main() {
  group('Tipo A (categoría fija)', () {
    test('sin movimientos capturados: comprometido = monto fijo, pronóstico = monto fijo', () {
      final p = calcularPronosticoCategoria(
        categoria: _fija(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 5),
        movimientosCicloActual: const [],
        ciclosCerradosRecienteAAntiguo: const [],
      );

      expect(p.tipo, TipoMpc.fija);
      expect(p.observado, const Dinero.cero());
      expect(p.comprometido, const Dinero.pesos(8000));
      expect(p.pronosticoP50, const Dinero.pesos(8000));
      expect(p.pronosticoP10, p.pronosticoP50);
      expect(p.pronosticoP90, p.pronosticoP50);
      expect(p.confianza, ConfianzaMpc.alta);
    });

    test('ya pagada: observado = monto fijo, comprometido = 0', () {
      final p = calcularPronosticoCategoria(
        categoria: _fija(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 5),
        movimientosCicloActual: [PuntoMonto(DateTime(2026, 7, 1), 800000)],
        ciclosCerradosRecienteAAntiguo: const [],
      );

      expect(p.observado, const Dinero.pesos(8000));
      expect(p.comprometido, const Dinero.cero());
      expect(p.pronosticoP50, const Dinero.pesos(8000));
    });
  });

  group('Tipo B vs Tipo C — clasificación por frecuencia', () {
    test('>=8 movimientos por ciclo (histórico) es Tipo B', () {
      final historico = [_ciclo(List.filled(10, 500.0))];
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 16),
        movimientosCicloActual: _ciclo(List.filled(5, 500.0), desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: historico,
      );
      expect(p.tipo, TipoMpc.variableFrecuente);
    });

    test('<8 movimientos por ciclo (histórico) es Tipo C', () {
      final historico = [_ciclo([200.0, 300, 150])];
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 16),
        movimientosCicloActual: _ciclo([200.0], desde: DateTime(2026, 7, 3)),
        ciclosCerradosRecienteAAntiguo: historico,
      );
      expect(p.tipo, TipoMpc.esporadica);
    });

    test('sin histórico, se decide por lo observado en el ciclo actual', () {
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 16),
        movimientosCicloActual: _ciclo(List.filled(9, 100.0), desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: const [],
      );
      expect(p.tipo, TipoMpc.variableFrecuente);
    });
  });

  group('rango y cota inferior dura', () {
    test('P10 <= P50 <= P90 siempre', () {
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 10),
        movimientosCicloActual: _ciclo(List.filled(6, 400.0), desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: [
          _ciclo(List.filled(20, 450.0), desde: DateTime(2026, 6, 1)),
          _ciclo(List.filled(20, 470.0), desde: DateTime(2026, 5, 1)),
        ],
      );
      expect(p.pronosticoP10.centavos, lessThanOrEqualTo(p.pronosticoP50.centavos));
      expect(p.pronosticoP50.centavos, lessThanOrEqualTo(p.pronosticoP90.centavos));
    });

    test('el pronóstico nunca es menor a lo ya gastado (§6, cota inferior dura)', () {
      // Ya se gastó mucho más que el histórico predeciría para el resto
      // del ciclo -> P50 y P10 no pueden caer por debajo de lo observado.
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 3),
        movimientosCicloActual: _ciclo(List.filled(9, 5000.0), desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: [
          _ciclo(List.filled(10, 100.0), desde: DateTime(2026, 6, 1)),
        ],
      );
      final observadoCentavos = p.observado.centavos;
      expect(p.pronosticoP50.centavos, greaterThanOrEqualTo(observadoCentavos));
      expect(p.pronosticoP10.centavos, greaterThanOrEqualTo(observadoCentavos));
    });
  });

  group('arranque en frío (§7)', () {
    test('0 ciclos cerrados -> nivel sinHistorial y explicación lo dice', () {
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 5),
        movimientosCicloActual: _ciclo([200.0, 150], desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: const [],
      );
      expect(p.nivelMadurez, NivelMadurezMpc.sinHistorial);
      expect(p.explicacion, contains('Sin historial. Mostrando tu presupuesto.'));
    });

    test('0 ciclos cerrados: el pronóstico es literalmente el presupuesto (§7, no una proyección calculada)', () {
      // Encontrado probando con datos reales: sin historial, la fórmula de
      // Tipo B igual "proyecta" algo (apoyada solo en lo observado), pero
      // eso no es lo que dice la tabla del §7 ("Presupuesto como
      // pronóstico") ni lo que tiene sentido mostrar cuando no hay con
      // qué comparar.
      final p = calcularPronosticoCategoria(
        categoria: _variable(), // presupuesto $6,000
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 5),
        movimientosCicloActual: _ciclo([200.0, 150], desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: const [],
      );
      expect(p.pronosticoP50, const Dinero.pesos(6000));
    });

    test('0 ciclos cerrados pero ya se gastó más que el presupuesto: gana lo observado (cota inferior dura)', () {
      final p = calcularPronosticoCategoria(
        categoria: _variable(), // presupuesto $6,000
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 5),
        movimientosCicloActual: _ciclo(List.filled(9, 100000.0), desde: DateTime(2026, 7, 1)), // $9,000
        ciclosCerradosRecienteAAntiguo: const [],
      );
      expect(p.pronosticoP50.centavos, greaterThanOrEqualTo(p.observado.centavos));
    });

    test('7+ ciclos cerrados -> nivel completo, sin mensaje de advertencia', () {
      final ciclos = List.generate(7, (i) => _ciclo(List.filled(10, 500.0), desde: DateTime(2026, 1, 1 + i)));
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 16),
        movimientosCicloActual: _ciclo(List.filled(5, 500.0), desde: DateTime(2026, 7, 1)),
        ciclosCerradosRecienteAAntiguo: ciclos,
      );
      expect(p.nivelMadurez, NivelMadurezMpc.completo);
    });
  });

  group('gating del perfil de día de semana por nivel de madurez (§7)', () {
    test('con menos de 4 ciclos cerrados, el avance efectivo es igual al de calendario (perfil neutro forzado)', () {
      // Historial con fuerte sesgo de fin de semana, pero solo 2 ciclos
      // cerrados -> nivel atipicosYCredibilidad, todavía sin estacionalidad.
      final finDeSemanaFuerte = [
        for (var s = 0; s < 4; s++) ...[
          PuntoMonto(DateTime(2026, 5, 2).add(Duration(days: 7 * s)), 1000), // sábado
        ],
      ];
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 6), // lunes
        fechaFinCiclo: DateTime(2026, 7, 12), // domingo
        hoy: DateTime(2026, 7, 11), // sábado, día 6 de 7
        movimientosCicloActual: _ciclo(List.filled(8, 100.0), desde: DateTime(2026, 7, 6)),
        ciclosCerradosRecienteAAntiguo: [finDeSemanaFuerte, finDeSemanaFuerte],
      );
      expect(p.avanceEfectivo, closeTo(6 / 7, 0.001));
    });

    test('con 4+ ciclos cerrados, el perfil de día de semana sí se aplica', () {
      // Lunes fuerte, miércoles flojo. Se consulta el martes (ya pasó el
      // lunes fuerte, todavía no el miércoles flojo) para que el efecto
      // del lunes se note sin que el miércoles lo cancele en la misma
      // ventana — si se consultara después del miércoles, ambos quedarían
      // del lado "ya transcurrido" y sus pesos se cancelarían entre sí.
      final lunesFuerte = DateTime(2026, 7, 6).subtract(const Duration(days: 7));
      final miercolesFlojo = lunesFuerte.add(const Duration(days: 2));
      final historial = [
        for (var s = 0; s < 6; s++) PuntoMonto(lunesFuerte.subtract(Duration(days: 7 * s)), 1000),
        for (var s = 0; s < 6; s++) PuntoMonto(miercolesFlojo.subtract(Duration(days: 7 * s)), 100),
      ];
      final ciclos = List.generate(4, (_) => historial);
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 6), // lunes
        fechaFinCiclo: DateTime(2026, 7, 12), // domingo
        hoy: DateTime(2026, 7, 7), // martes: ya pasó el lunes fuerte
        movimientosCicloActual: _ciclo(List.filled(8, 100.0), desde: DateTime(2026, 7, 6)),
        ciclosCerradosRecienteAAntiguo: ciclos,
      );
      // El avance de calendario a este punto es 2/7 ≈ 0.286; el lunes
      // fuerte ya pasado debe adelantar el avance efectivo por encima.
      expect(p.avanceEfectivo, greaterThan(2 / 7));
    });
  });

  group('subcaptura (§8) baja la confianza', () {
    test('muy pocos movimientos vs. lo esperado marca confianza baja', () {
      final historico = List.generate(4, (i) => _ciclo(List.filled(20, 100.0), desde: DateTime(2026, i + 1, 1)));
      final p = calcularPronosticoCategoria(
        categoria: _variable(),
        cicloId: '2026-07',
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 20), // ya avanzado el ciclo
        movimientosCicloActual: _ciclo([50.0], desde: DateTime(2026, 7, 2)), // casi nada capturado
        ciclosCerradosRecienteAAntiguo: historico,
      );
      expect(p.senalSubcaptura, SenalSubcaptura.noConfiable);
      expect(p.confianza, ConfianzaMpc.baja);
    });
  });
}
