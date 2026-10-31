import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/reporte_analisis.dart';
import 'package:app_finanzas/domain/analisis/veredicto_ciclo.dart';
import 'package:test/test.dart';

final _calc = const CalculadoraCiclo(1);

/// Ciclo de agosto (31 días) visto el día [dia].
VeredictoCiclo _veredicto({required int dia, required int gastado, required int presupuesto}) {
  final hoy = DateTime(2026, 8, dia);
  final ciclo = _calc.calcularPara(hoy);
  final r = calcularReporteAnalisis(
    ciclo: ciclo,
    cicloAnterior: _calc.calcularPara(DateTime(2026, 7, 15)),
    movimientos: const [],
    categorias: const [],
    hoy: hoy,
  );
  final proyeccion = gastado + gastado * (r.diasDelCiclo - dia) ~/ dia;
  return calcularVeredicto(
    hoy: hoy,
    reporte: ReporteAnalisis(
      ciclo: ciclo,
      diaDelCiclo: dia,
      diasDelCiclo: r.diasDelCiclo,
      gastado: Dinero.pesos(gastado + 700),
      gastadoVariables: Dinero.pesos(gastado),
      gastadoFijas: const Dinero.pesos(700),
      presupuestoVariables: Dinero.pesos(presupuesto),
      presupuestoFijas: const Dinero.pesos(700),
      promedioDiarioVariables: const Dinero.cero(),
      proyeccionVariables: Dinero.pesos(proyeccion),
      porCategoria: const [],
      acumuladoVariablesPorDia: const [],
      variablesAnteriorMismoDia: null,
      contraAnterior: const [],
      ultimosCiclos: const [],
      promedioPorDiaSemana: r.promedioPorDiaSemana,
      diasConDatos: 0,
      dondeMasGastas: const [],
      conTarjeta: const Dinero.cero(),
      enEfectivo: const Dinero.cero(),
      gastosPequenos: 0,
      totalGastosPequenos: const Dinero.cero(),
    ),
  );
}

void main() {
  test('sin presupuesto: solo dice cuánto lleva, y cómo saber si va bien', () {
    final v = _veredicto(dia: 10, gastado: 100, presupuesto: 0);
    expect(v.tono, TonoVeredicto.neutro);
    expect(v.titulo, contains(r'$800'));
    expect(v.disponibleHoy, isNull);
  });

  test('a ritmo de cerrar dentro: vas bien, con lo que sobraría y lo de hoy', () {
    final v = _veredicto(dia: 10, gastado: 100, presupuesto: 1000);
    expect(v.tono, TonoVeredicto.bien);
    expect(v.titulo, 'Vas bien');
    expect(v.detalle, contains(r'$690')); // proyección 310
    expect(v.disponibleHoy, const Dinero(4090)); // $900 entre 22 días, contando hoy
  });

  test('a ritmo de pasarse: vas rápido, y cuánto', () {
    final v = _veredicto(dia: 10, gastado: 500, presupuesto: 1000);
    expect(v.tono, TonoVeredicto.atencion);
    expect(v.detalle, contains(r'$550')); // proyección 1550
    expect(v.disponibleHoy, isNotNull);
  });

  test('ya pasado: cuánto, con consejo según queden días', () {
    final conDias = _veredicto(dia: 10, gastado: 1200, presupuesto: 1000);
    expect(conDias.tono, TonoVeredicto.pasado);
    expect(conDias.titulo, contains(r'$200'));
    expect(conDias.detalle, contains('lo que queda'));
    expect(conDias.disponibleHoy, isNull);

    final ultimoDia = _veredicto(dia: 31, gastado: 1200, presupuesto: 1000);
    expect(ultimoDia.detalle, contains('próximo ciclo'));
  });

  test('último día dentro del presupuesto: cierra bien', () {
    final v = _veredicto(dia: 31, gastado: 900, presupuesto: 1000);
    expect(v.tono, TonoVeredicto.bien);
    expect(v.titulo, contains('Cierras'));
    expect(v.detalle, contains(r'$100'));
    expect(v.disponibleHoy, const Dinero.pesos(100));
  });

  test('justo en el presupuesto: nada que repartir hoy', () {
    final v = _veredicto(dia: 31, gastado: 1000, presupuesto: 1000);
    expect(v.disponibleHoy, isNull);
  });
}
