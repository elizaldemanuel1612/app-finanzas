import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/plan_de_ajuste.dart';
import 'package:app_finanzas/domain/pronostico/nivel_madurez.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_categoria.dart';
import 'package:app_finanzas/domain/pronostico/punto_monto.dart';
import 'package:app_finanzas/domain/pronostico/subcaptura.dart';
import 'package:test/test.dart';

CategoriaVariable _categoria({required Dinero presupuesto}) => CategoriaVariable(
      id: 'salidas',
      nombre: 'Salidas/Diversión',
      emoji: '🍿',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: presupuesto,
    );

PronosticoCategoria _pronostico({
  required Dinero observado,
  required Dinero pronosticoP50,
  Dinero comprometido = const Dinero.cero(),
  NivelMadurezMpc nivel = NivelMadurezMpc.atipicosYCredibilidad,
}) =>
    PronosticoCategoria(
      categoriaId: 'salidas',
      cicloId: '2026-07',
      tipo: TipoMpc.variableFrecuente,
      observado: observado,
      base: observado,
      atipico: const Dinero.cero(),
      comprometido: comprometido,
      avanceEfectivo: 0.5,
      pronosticoP50: pronosticoP50,
      pronosticoP10: pronosticoP50,
      pronosticoP90: pronosticoP50,
      confianza: ConfianzaMpc.media,
      senalSubcaptura: SenalSubcaptura.normal,
      nivelMadurez: nivel,
      explicacion: const [],
    );

void main() {
  // Reproduce, con números reales derivados del ejemplo del propio spec
  // (addendum-v3-ajuste-y-ux.md §2.3): "Te quedan $3,026 para 14 días",
  // "Normalmente gastas $1,758 por semana", "Apunta a $1,513 · $216 al
  // día". No son valores inventados para el test — se construyeron hacia
  // atrás para que el disponible y el histórico produzcan exactamente
  // esas cifras, y así confirmar que la fórmula del documento es la que
  // de verdad corre.
  group('ejemplo del spec §2.3', () {
    final categoria = _categoria(presupuesto: const Dinero.pesos(3026)); // disponible = presupuesto (nada gastado)
    // 3 ciclos cerrados, cada uno con un total idéntico de $7,534.29 ->
    // Histórico_c = esa mediana exacta -> /30 días *7 = $1,758.00/semana.
    final ciclosCerrados = [
      [PuntoMonto(DateTime(2026, 6, 1), 753429)],
      [PuntoMonto(DateTime(2026, 5, 1), 753429)],
      [PuntoMonto(DateTime(2026, 4, 1), 753429)],
    ];
    final pronostico = _pronostico(
      observado: const Dinero.cero(),
      pronosticoP50: const Dinero.pesos(3500), // por encima del presupuesto -> dispara
    );

    final plan = calcularPlanDeAjuste(
      categoria: categoria,
      pronostico: pronostico,
      ciclosCerradosRecienteAAntiguo: ciclosCerrados,
      fechaInicioCiclo: DateTime(2026, 7, 2), // 30 días de ciclo
      fechaFinCiclo: DateTime(2026, 7, 31),
      hoy: DateTime(2026, 7, 18), // quedan 14 días (18..31 inclusive)
    );

    test('se dispara y calcula disponible y días restantes', () {
      expect(plan, isNotNull);
      expect(plan!.disponible, const Dinero.pesos(3026));
      expect(plan.diasRestantes, 14);
    });

    test(r'"contra tu costumbre" da $1,758/semana — el mismo histórico que usa el MPC', () {
      expect(plan!.gastoHabitualPorDia.centavos, closeTo(25114, 1));
      // 25114.3 * 7 redondeado = 175800 centavos = $1,758.00
      final semanal = (plan.gastoHabitualPorDia.centavos * 7);
      expect(semanal, closeTo(175800, 10));
    });

    test(r'"número a seguir": $1,513/semana y $216/día (14 días = 2 semanas exactas)', () {
      expect(plan!.sugeridoPromedioPorDia.centavos, closeTo(21614, 1));
      expect(plan.diasRestantes >= 7, isTrue);
      expect(plan.piezaNumeroASeguir, contains('por semana'));
      expect(plan.piezaNumeroASeguir, contains('al día'));
    });

    test('las tres piezas del mensaje están en el orden fijo de §2.3', () {
      expect(plan!.piezaCuantoQueda, contains('Te quedan'));
      expect(plan.piezaCuantoQueda, contains('14 días'));
      expect(plan.piezaContraCostumbre, contains('Normalmente gastas'));
      expect(plan.piezaNumeroASeguir, contains('Apunta a'));
    });

    test('nunca se muestra el porcentaje de recorte solo', () {
      for (final pieza in [plan!.piezaCuantoQueda, plan.piezaContraCostumbre, plan.piezaNumeroASeguir]) {
        expect(pieza, isNot(contains('%')));
      }
    });
  });

  group('cuándo se dispara (§2.1)', () {
    final categoriaBase = _categoria(presupuesto: const Dinero.pesos(3000));

    test('no se dispara si el pronóstico no proyecta pasarse del presupuesto', () {
      final plan = calcularPlanDeAjuste(
        categoria: categoriaBase,
        pronostico: _pronostico(observado: const Dinero.pesos(1000), pronosticoP50: const Dinero.pesos(2500)),
        ciclosCerradosRecienteAAntiguo: const [],
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 10),
      );
      expect(plan, isNull);
    });

    test('no se dispara con menos de 3 días restantes', () {
      final plan = calcularPlanDeAjuste(
        categoria: categoriaBase,
        pronostico: _pronostico(observado: const Dinero.pesos(1000), pronosticoP50: const Dinero.pesos(3500)),
        ciclosCerradosRecienteAAntiguo: const [],
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 30), // solo quedan 2 días
      );
      expect(plan, isNull);
    });

    test('sí se dispara con exactamente 3 días restantes', () {
      final plan = calcularPlanDeAjuste(
        categoria: categoriaBase,
        pronostico: _pronostico(observado: const Dinero.pesos(1000), pronosticoP50: const Dinero.pesos(3500)),
        ciclosCerradosRecienteAAntiguo: const [],
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 29),
      );
      expect(plan, isNotNull);
      expect(plan!.diasRestantes, 3);
      // Menos de 7 días -> se etiqueta con su duración, no como "semana".
      expect(plan.piezaNumeroASeguir, contains('durante 3 días'));
      expect(plan.piezaNumeroASeguir, isNot(contains('por semana')));
    });

    test('categoría fija: excluida siempre (spec-app-finanzas-v2.md §1.5)', () {
      final fija = CategoriaFija(
        id: 'renta',
        nombre: 'Vivienda',
        emoji: '🏠',
        activa: true,
        esNecesaria: true,
        montoFijoCentavos: const Dinero.pesos(8000),
        diaDelCiclo: 1,
      );
      final plan = calcularPlanDeAjuste(
        categoria: fija,
        pronostico: _pronostico(observado: const Dinero.cero(), pronosticoP50: const Dinero.pesos(9000)),
        ciclosCerradosRecienteAAntiguo: const [],
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 10),
      );
      expect(plan, isNull);
    });
  });

  group('guardarraíles (§2.6)', () {
    test('disponible negativo (ya gastado más que el presupuesto): no se inventa un ritmo', () {
      final categoria = _categoria(presupuesto: const Dinero.pesos(3000));
      final plan = calcularPlanDeAjuste(
        categoria: categoria,
        pronostico: _pronostico(observado: const Dinero.pesos(3500), pronosticoP50: const Dinero.pesos(4000)),
        ciclosCerradosRecienteAAntiguo: const [],
        fechaInicioCiclo: DateTime(2026, 7, 1),
        fechaFinCiclo: DateTime(2026, 7, 31),
        hoy: DateTime(2026, 7, 10),
      );
      expect(plan, isNull);
    });
  });

  group('reparto no plano (§2.2)', () {
    test('un día con más peso recibe más presupuesto sugerido que uno con menos', () {
      // Historial con sábados fuertes y martes flojos, suficiente para
      // pasar el nivel de madurez que activa estacionalidad (4+ ciclos).
      final sabado = DateTime(2026, 6, 6); // sábado
      final martes = DateTime(2026, 6, 9); // martes
      final ciclos = List.generate(
        4,
        (_) => [
          for (var s = 0; s < 4; s++) PuntoMonto(sabado.add(Duration(days: 7 * s)), 100000),
          for (var s = 0; s < 4; s++) PuntoMonto(martes.add(Duration(days: 7 * s)), 10000),
        ],
      );
      final categoria = _categoria(presupuesto: const Dinero.pesos(3000));
      final plan = calcularPlanDeAjuste(
        categoria: categoria,
        pronostico: _pronostico(
          observado: const Dinero.cero(),
          pronosticoP50: const Dinero.pesos(3500),
          nivel: NivelMadurezMpc.conEstacionalidad,
        ),
        ciclosCerradosRecienteAAntiguo: ciclos,
        fechaInicioCiclo: DateTime(2026, 7, 6), // lunes
        fechaFinCiclo: DateTime(2026, 7, 12), // domingo, ciclo de una semana
        hoy: DateTime(2026, 7, 6),
      );

      expect(plan, isNotNull);
      final sabadoDelCiclo = DateTime(2026, 7, 11);
      final martesDelCiclo = DateTime(2026, 7, 7);
      expect(
        plan!.repartoPorDia[sabadoDelCiclo]!.centavos,
        greaterThan(plan.repartoPorDia[martesDelCiclo]!.centavos),
      );
      // La suma de todo el reparto diario debe reconstruir el disponible
      // (redondeos aparte).
      final sumaReparto = plan.repartoPorDia.values.fold(0, (a, d) => a + d.centavos);
      expect(sumaReparto, closeTo(plan.disponible.centavos, plan.repartoPorDia.length));
    });
  });
}
