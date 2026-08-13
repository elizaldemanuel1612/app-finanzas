import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/meta_apartado.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/presupuesto/meta_base.dart';
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
  test('sin meta declarada, usa lo que sobra del reparto (sinAsignar)', () {
    final perfil = const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(87000));
    final categorias = <Categoria>[_fija('renta', 11126), _variable('super', 14000)];

    final meta = calcularMetaBase(perfil: perfil, categorias: categorias);

    expect(meta, const Dinero.pesos(87000 - 11126 - 14000));
  });

  test('con meta declarada por porcentaje, ignora las categorías', () {
    final perfil = Perfil(
      diaCorte: 12,
      ingresoBaseMensual: const Dinero.pesos(87000),
      metaApartado: const MetaPorPorcentaje(40),
    );
    // Fijas que ni siquiera caben en el ingreso: si se usara el reparto
    // derivado, esto daría Dinero.cero(). La meta declarada no debe verse
    // afectada por eso.
    final categorias = <Categoria>[_fija('renta', 999999)];

    final meta = calcularMetaBase(perfil: perfil, categorias: categorias);

    expect(meta, const Dinero.pesos(34800));
  });

  test('con meta declarada por monto fijo, ignora ingreso y categorías', () {
    final perfil = Perfil(
      diaCorte: 12,
      ingresoBaseMensual: const Dinero.pesos(87000),
      metaApartado: const MetaPorMonto(Dinero.pesos(5000)),
    );

    final meta = calcularMetaBase(perfil: perfil, categorias: const []);

    expect(meta, const Dinero.pesos(5000));
  });

  test('sin meta declarada y el reparto falla (fijas no caben), da cero', () {
    final perfil = const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(5000));
    final categorias = <Categoria>[_fija('renta', 11126)];

    final meta = calcularMetaBase(perfil: perfil, categorias: categorias);

    expect(meta, const Dinero.cero());
  });
}
