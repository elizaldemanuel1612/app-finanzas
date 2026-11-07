import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/historial_ciclos.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/periodo_historial.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(12);

/// 20 ciclos, del más reciente (sep 2026) al más viejo (feb 2025), como
/// los entrega `calcularHistorialCiclos`.
final _historial = [
  for (var i = 0; i < 20; i++)
    CicloResumen(
      ciclo: _calculadora.calcularPara(DateTime(2026, 9 - i, 15)),
      snapshot: null,
      totalGastado: const Dinero.pesos(1000),
    ),
];

void main() {
  test('etiquetaConAnio lleva el año en que empieza el ciclo', () {
    final dic = _calculadora.calcularPara(DateTime(2026, 1, 5)); // 12 dic 2025 – 11 ene 2026
    expect(dic.etiquetaConAnio, 'Dic 2025');
  });

  test('años del historial, del más reciente al más viejo', () {
    expect(aniosDelHistorial(_historial), [2026, 2025]);
    expect(aniosDelHistorial(const []), isEmpty);
  });

  test('últimos N ciclos respeta el orden', () {
    final r = filtrarHistorial(_historial, const UltimosCiclos());
    expect(r, hasLength(12));
    expect(r.first.ciclo.id, '2026-09');
    expect(filtrarHistorial(_historial, const UltimosCiclos(3)).map((c) => c.ciclo.id), ['2026-09', '2026-08', '2026-07']);
  });

  test('un año calendario, por el año en que empieza el ciclo', () {
    final r = filtrarHistorial(_historial, const AnioCalendario(2025));
    expect(r, hasLength(11)); // feb–dic 2025
    expect(r.every((c) => c.ciclo.fechaInicio.year == 2025), isTrue);
    expect(filtrarHistorial(_historial, const AnioCalendario(2020)), isEmpty);
  });

  test('todo el historial', () {
    expect(filtrarHistorial(_historial, const TodoElHistorial()), hasLength(20));
  });

  test('igualdad de periodos (para marcar el chip elegido)', () {
    expect(const UltimosCiclos(), const UltimosCiclos(12));
    expect(const UltimosCiclos(), isNot(const UltimosCiclos(6)));
    expect(const AnioCalendario(2025), const AnioCalendario(2025));
    expect(const AnioCalendario(2025), isNot(const AnioCalendario(2026)));
    expect(const TodoElHistorial(), const TodoElHistorial());
    expect({const UltimosCiclos().hashCode, const AnioCalendario(2025).hashCode, const TodoElHistorial().hashCode}, hasLength(3));
  });
}
