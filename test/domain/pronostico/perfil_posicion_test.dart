import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/pronostico/perfil_posicion.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_categoria.dart';
import 'package:app_finanzas/domain/pronostico/punto_monto.dart';
import 'package:test/test.dart';

// modelo-pronostico-ciclo.md §3.2 y Tipo C (2026-11-21): posición dentro
// del ciclo. Lo que se paga al inicio ya no se proyecta al triple.

PuntoMonto _p(DateTime inicio, int dia, double pesos) => PuntoMonto(inicio.add(Duration(days: dia, hours: 12)), pesos * 100);

CategoriaVariable _cat(int presupuesto) => CategoriaVariable(
      id: 'c',
      nombre: 'Victoria',
      emoji: '👶',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(presupuesto),
    );

void main() {
  final inicios = [DateTime(2026, 10, 12), DateTime(2026, 9, 12), DateTime(2026, 8, 12)];

  group('diaEnCiclo', () {
    test('días de calendario desde el inicio; antes del inicio es el día 0', () {
      expect(diaEnCiclo(DateTime(2026, 11, 12, 23, 59), DateTime(2026, 11, 12)), 0);
      expect(diaEnCiclo(DateTime(2026, 11, 21, 0, 1), DateTime(2026, 11, 12)), 9);
      expect(diaEnCiclo(DateTime(2026, 11, 1), DateTime(2026, 11, 12)), 0);
      // El cambio de horario no mueve la cuenta.
      expect(diaEnCiclo(DateTime(2026, 4, 6), DateTime(2026, 4, 4)), 2);
    });
  });

  group('avanceConPosicion', () {
    test('si todo se gastó al inicio en los ciclos pasados, el avance es casi completo', () {
      final ciclos = [
        for (final i in inicios) [_p(i, 1, 3000)],
      ];
      final p = avanceConPosicion(ciclosCerrados: ciclos, iniciosCiclosCerrados: inicios, diaDeHoy: 9, avanceCalendario: 1 / 3);
      // λ = 3 ÷ 3.5: 0.857 × 1 + 0.143 × 0.333.
      expect(p, closeTo(0.9048, 0.0001));
    });

    test('lo que aún no pasaba a esta altura no cuenta; con un ciclo se cree menos', () {
      final ciclos = [
        [_p(inicios[0], 2, 100), _p(inicios[0], 20, 300)],
      ];
      final p = avanceConPosicion(ciclosCerrados: ciclos, iniciosCiclosCerrados: [inicios[0]], diaDeHoy: 9, avanceCalendario: 0.4);
      // λ = 1 ÷ 1.5: 0.667 × 0.25 + 0.333 × 0.4.
      expect(p, closeTo(0.3, 0.0001));
    });

    test('sin ciclos con gasto se queda el avance de calendario', () {
      expect(
        avanceConPosicion(ciclosCerrados: const [[]], iniciosCiclosCerrados: [inicios[0]], diaDeHoy: 5, avanceCalendario: 0.2),
        0.2,
      );
      expect(avanceConPosicion(ciclosCerrados: const [], iniciosCiclosCerrados: const [], diaDeHoy: 5, avanceCalendario: 0.2), 0.2);
    });
  });

  group('faltaPorPosicion', () {
    test('mitad promedio y mitad mediana de lo gastado después de este día', () {
      final ciclos = [
        [_p(inicios[0], 1, 100), _p(inicios[0], 20, 600)],
        [_p(inicios[1], 15, 300)],
      ];
      final falta = faltaPorPosicion(
        ciclosCerrados: ciclos,
        iniciosCiclosCerrados: inicios.sublist(0, 2),
        diaDeHoy: 9,
        movimientosDeEsteCiclo: 0,
      );
      // Después del día 9: 600 y 300 → promedio 450, mediana 450.
      expect(falta, 45000);
    });

    test('con 3 ciclos, no se esperan más gastos que los más que ha habido', () {
      final ciclos = [
        [_p(inicios[0], 20, 150)],
        [_p(inicios[1], 22, 150)],
        [_p(inicios[2], 3, 150)],
      ];
      double falta(int hechos) => faltaPorPosicion(
            ciclosCerrados: ciclos,
            iniciosCiclosCerrados: inicios,
            diaDeHoy: 9,
            movimientosDeEsteCiclo: hechos,
          );
      // Sin pagar todavía: promedio 100, mediana 150 → 125.
      expect(falta(0), 12500);
      // Ya pagado y nunca ha habido dos en un ciclo: no falta nada.
      expect(falta(1), 0);
      expect(falta(2), 0);
    });

    test('con menos de 3 ciclos el tope no se aplica; sin ciclos no falta nada', () {
      final ciclos = [
        [_p(inicios[0], 20, 150)],
        [_p(inicios[1], 22, 150)],
      ];
      expect(
        faltaPorPosicion(ciclosCerrados: ciclos, iniciosCiclosCerrados: inicios.sublist(0, 2), diaDeHoy: 9, movimientosDeEsteCiclo: 1),
        15000,
      );
      expect(faltaPorPosicion(ciclosCerrados: const [], iniciosCiclosCerrados: const [], diaDeHoy: 9, movimientosDeEsteCiclo: 0), 0);
      // Tres ciclos sin un solo gasto: nada que esperar.
      expect(
        faltaPorPosicion(ciclosCerrados: const [[], [], []], iniciosCiclosCerrados: inicios, diaDeHoy: 9, movimientosDeEsteCiclo: 0),
        0,
      );
    });
  });

  group('en el pronóstico', () {
    final inicio = DateTime(2026, 11, 12);
    final fin = DateTime(2026, 12, 11);
    final hoy = DateTime(2026, 11, 21, 17); // día 10 de 30

    PronosticoCategoria pronosticar(List<PuntoMonto> actual, List<List<PuntoMonto>> cerrados, {bool conPosicion = true, int presupuesto = 3000}) =>
        calcularPronosticoCategoria(
          categoria: _cat(presupuesto),
          cicloId: '2026-11',
          fechaInicioCiclo: inicio,
          fechaFinCiclo: fin,
          hoy: hoy,
          movimientosCicloActual: actual,
          ciclosCerradosRecienteAAntiguo: cerrados,
          iniciosCiclosCerradosRecienteAAntiguo: conPosicion ? inicios.sublist(0, cerrados.length) : null,
        );

    test('un pago al inicio del ciclo ya no se proyecta como si se repitiera', () {
      final cerrados = [
        for (final i in inicios) [_p(i, 1, 2980)],
      ];
      final actual = [_p(inicio, 1, 2980)];
      final antes = pronosticar(actual, cerrados, conPosicion: false);
      final ahora = pronosticar(actual, cerrados);
      // Antes: 2,980 + 1 × (1 − 10/30) × 2,980.
      expect(antes.pronosticoP50, const Dinero(496667));
      expect(ahora.pronosticoP50, const Dinero.pesos(2980));
      expect(ahora.tipo, TipoMpc.esporadica);
    });

    test('muchas compras concentradas al inicio: el ritmo se mide contra lo habitual a esta altura', () {
      List<PuntoMonto> ciclo(DateTime i) => [
            for (var d = 0; d < 9; d++) _p(i, d, 300),
            _p(i, 20, 300),
          ];
      final cerrados = [for (final i in inicios) ciclo(i)];
      final actual = [for (var d = 0; d < 9; d++) _p(inicio, d, 300)];
      final antes = pronosticar(actual, cerrados, conPosicion: false);
      final ahora = pronosticar(actual, cerrados);
      expect(ahora.tipo, TipoMpc.variableFrecuente);
      expect(ahora.avanceEfectivo, closeTo(0.819, 0.001));
      // Cierre real habitual: $3,000. Antes decía ~$5,500.
      expect(antes.pronosticoP50.centavos, greaterThan(540000));
      expect(ahora.pronosticoP50.centavos, inInclusiveRange(300000, 335000));
    });

    test('con 3 gastos o más por ciclo no hay tope: se espera lo que suele faltar', () {
      final cerrados = [
        for (final i in inicios) [_p(i, 1, 500), _p(i, 10, 500), _p(i, 25, 500)],
      ];
      final actual = [_p(inicio, 1, 500), _p(inicio, 5, 500), _p(inicio, 8, 500)];
      // Después del día 10 (índice 9) suelen faltar dos de $500.
      expect(pronosticar(actual, cerrados).pronosticoP50, const Dinero.pesos(2500));
    });

    test('si ya no se gasta, el estimado baja con los días hasta lo observado', () {
      final cerrados = [
        for (final i in inicios) [_p(i, 1, 500), _p(i, 10, 500), _p(i, 25, 500)],
      ];
      final actual = [_p(inicio, 1, 500)];
      Dinero al(int dia) => calcularPronosticoCategoria(
            categoria: _cat(1500),
            cicloId: '2026-11',
            fechaInicioCiclo: inicio,
            fechaFinCiclo: fin,
            hoy: inicio.add(Duration(days: dia, hours: 20)),
            movimientosCicloActual: actual,
            ciclosCerradosRecienteAAntiguo: cerrados,
            iniciosCiclosCerradosRecienteAAntiguo: inicios,
          ).pronosticoP50;
      expect([al(5), al(15), al(26)], const [Dinero.pesos(1500), Dinero.pesos(1000), Dinero.pesos(500)]);
    });

    test('inicios que no cuadran con los ciclos se ignoran: avance de calendario', () {
      final cerrados = [
        for (final i in inicios) [_p(i, 1, 2980)],
      ];
      final p = calcularPronosticoCategoria(
        categoria: _cat(3000),
        cicloId: '2026-11',
        fechaInicioCiclo: inicio,
        fechaFinCiclo: fin,
        hoy: hoy,
        movimientosCicloActual: [_p(inicio, 1, 2980)],
        ciclosCerradosRecienteAAntiguo: cerrados,
        iniciosCiclosCerradosRecienteAAntiguo: [inicios.first],
      );
      expect(p.pronosticoP50, const Dinero(496667));
    });

    test('sin historial sigue mostrando el presupuesto', () {
      final p = pronosticar([_p(inicio, 1, 100)], const [], conPosicion: true);
      expect(p.pronosticoP50, const Dinero.pesos(3000));
    });
  });
}
