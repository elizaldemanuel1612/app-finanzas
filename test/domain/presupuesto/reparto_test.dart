import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/reparto.dart';
import 'package:test/test.dart';

CategoriaFija _fija(String id, int pesos) => CategoriaFija(
      id: id,
      nombre: id,
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(pesos),
      diaDelCiclo: 1,
    );

CategoriaVariable _variable(String id, int pesos) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );

void main() {
  // Las cuatro fijas y el total de app-finanzas-fijos-cierre-v6.html §3:
  // Vivienda $9,910 + Gimnasio $658 + Plan celular $319 + Spotify $239 = $11,126.
  final fijasDelMockup = [
    _fija('vivienda', 9910),
    _fija('gimnasio', 658),
    _fija('plan_celular', 319),
    _fija('spotify', 239),
  ];

  test(r'el total de fijas coincide con el ejemplo documentado ($11,126)', () {
    final r = calcularReparto(
      ingresoDisponible: const Dinero.pesos(87000),
      fijas: fijasDelMockup,
      variables: const [],
    );
    expect((r as Exito<ResultadoReparto>).valor.totalFijas, const Dinero.pesos(11126));
  });

  test('reparto completo: fijas + variables caben, sinAsignar es exacto', () {
    final r = calcularReparto(
      ingresoDisponible: const Dinero.pesos(87000),
      fijas: fijasDelMockup,
      variables: [_variable('super', 8000), _variable('salidas', 6000)],
    );
    final reparto = (r as Exito<ResultadoReparto>).valor;
    expect(reparto.disponibleParaVariables, const Dinero.pesos(87000 - 11126));
    expect(reparto.totalPresupuestadoVariables, const Dinero.pesos(14000));
    expect(reparto.sinAsignar, const Dinero.pesos(87000 - 11126 - 14000));
  });

  test('las variables que exceden lo disponible bloquean el reparto entero', () {
    final r = calcularReparto(
      ingresoDisponible: const Dinero.pesos(15000),
      fijas: fijasDelMockup,
      variables: [_variable('super', 8000)],
    );
    // Disponible tras fijas: 15000-11126=3874, presupuesto variable pide 8000.
    expect(r.esFalla, isTrue);
  });

  test('las fijas que exceden el ingreso bloquean antes de llegar a variables', () {
    final r = calcularReparto(
      ingresoDisponible: const Dinero.pesos(5000),
      fijas: fijasDelMockup,
      variables: const [],
    );
    expect(r.esFalla, isTrue);
  });

  test('sin variables, sinAsignar es todo el disponible', () {
    final r = calcularReparto(
      ingresoDisponible: const Dinero.pesos(87000),
      fijas: fijasDelMockup,
      variables: const [],
    );
    final reparto = (r as Exito<ResultadoReparto>).valor;
    expect(reparto.sinAsignar, reparto.disponibleParaVariables);
  });

  test('toString describe el reparto', () {
    final r = calcularReparto(
      ingresoDisponible: const Dinero.pesos(87000),
      fijas: fijasDelMockup,
      variables: [_variable('super', 8000)],
    );
    final texto = (r as Exito<ResultadoReparto>).valor.toString();
    expect(texto, contains('ResultadoReparto'));
  });
}
