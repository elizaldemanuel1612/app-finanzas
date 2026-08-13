import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/coherencia_meta.dart';
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
  test('cabe: los presupuestos dejan sobrante', () {
    final r = evaluarMeta(
      ingresoBase: const Dinero.pesos(87000),
      metaBase: const Dinero.pesos(34800),
      fijas: [_fija('renta', 11126)],
      variables: [_variable('super', 14000)],
    );

    expect(r.disponibleParaGastar, const Dinero.pesos(87000 - 34800));
    expect(r.totalPresupuestado, const Dinero.pesos(11126 + 14000));
    expect(r.estado, EstadoCoherenciaMeta.cabe);
    expect(r.excedente.esPositivo, isTrue);
  });

  test('exacto: los presupuestos cuadran al centavo con lo disponible', () {
    final r = evaluarMeta(
      ingresoBase: const Dinero.pesos(87000),
      metaBase: const Dinero.pesos(34800),
      fijas: [_fija('renta', 11126)],
      variables: [_variable('super', 87000 - 34800 - 11126)],
    );

    expect(r.estado, EstadoCoherenciaMeta.exacto);
    expect(r.excedente, const Dinero.cero());
  });

  test('no cabe: informa el exceso y la meta que sí respetaría los presupuestos', () {
    final r = evaluarMeta(
      ingresoBase: const Dinero.pesos(87000),
      metaBase: const Dinero.pesos(60000),
      fijas: [_fija('renta', 11126)],
      variables: [_variable('super', 20000)],
    );

    // disponible = 87000-60000=27000; presupuestado=31126; excedente=-4126.
    expect(r.estado, EstadoCoherenciaMeta.noCabe);
    expect(r.excedente, const Dinero.pesos(27000 - 31126));
    // metaSiRespetaPresupuestos = ingreso - presupuestado = 87000-31126=55874.
    expect(r.metaSiRespetaPresupuestos, const Dinero.pesos(87000 - 31126));
    // 55874/87000 = 64.22% -> redondeo medio arriba a 64%.
    expect(r.porcentajeSiRespetaPresupuestos, 64);
  });

  test('ingreso cero: no truena, porcentaje da cero y la meta ajustada tiene piso cero', () {
    final r = evaluarMeta(
      ingresoBase: const Dinero.cero(),
      metaBase: const Dinero.cero(),
      fijas: [_fija('renta', 100)],
      variables: const [],
    );

    expect(r.disponibleParaGastar, const Dinero.cero());
    expect(r.estado, EstadoCoherenciaMeta.noCabe);
    expect(r.metaSiRespetaPresupuestos, const Dinero.cero());
    expect(r.porcentajeSiRespetaPresupuestos, 0);
  });

  test('sin fijas ni variables, todo el ingreso menos la meta sobra', () {
    final r = evaluarMeta(
      ingresoBase: const Dinero.pesos(1000),
      metaBase: const Dinero.pesos(200),
      fijas: const [],
      variables: const [],
    );

    expect(r.estado, EstadoCoherenciaMeta.cabe);
    expect(r.totalPresupuestado, const Dinero.cero());
    expect(r.metaSiRespetaPresupuestos, const Dinero.pesos(1000));
    expect(r.porcentajeSiRespetaPresupuestos, 100);
  });
}
