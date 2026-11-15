import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/presupuesto/cobertura_excesos.dart';
import 'package:test/test.dart';

CategoriaVariable _var(String id, int presupuesto) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(presupuesto),
    );

EstadoVariable _e(String id, int presupuesto, {required int gastado, required int proyeccion}) =>
    EstadoVariable(categoria: _var(id, presupuesto), gastado: Dinero.pesos(gastado), proyeccion: Dinero.pesos(proyeccion));

void main() {
  test('estado: exceso, sobrante y disponible', () {
    final pasada = _e('salidas', 1000, gastado: 1200, proyeccion: 1500);
    expect(pasada.exceso, const Dinero.pesos(200));
    expect(pasada.sobrante, const Dinero.cero());
    expect(pasada.disponible, const Dinero.pesos(-200));
    final holgada = _e('auto', 2000, gastado: 100, proyeccion: 300);
    expect(holgada.exceso, const Dinero.cero());
    expect(holgada.sobrante, const Dinero.pesos(1700));
    expect(holgada.disponible, const Dinero.pesos(1900));
  });

  test('de mayor exceso a menor, desde el mayor sobrante, sin ofrecerlo dos veces', () {
    final c = calcularCoberturas([
      _e('salidas', 1000, gastado: 1200, proyeccion: 1300),
      _e('super', 1000, gastado: 1500, proyeccion: 1600),
      _e('auto', 2000, gastado: 100, proyeccion: 300), // sobran 1,700
      _e('cafe', 500, gastado: 0, proyeccion: 400), // sobran 100
    ]);
    expect(c.map((x) => x.categoria.id), ['super', 'salidas']);
    expect(c[0].origen!.id, 'auto');
    expect(c[0].cubre, const Dinero.pesos(500));
    expect(c[0].sobranteOrigen, const Dinero.pesos(1700));
    expect(c[0].falta, const Dinero.cero());
    expect(c[0].frase, r'Mueve $500.00 desde auto: le sobrarán $1,200.00.');
    expect(c[1].origen!.id, 'auto', reason: 'aún le quedan 1,200, más que los 100 de cafe');
    expect(c[1].sobranteOrigen, const Dinero.pesos(1200));
  });

  test('si no alcanza cubre una parte; sin sobrante, sale de lo apartado', () {
    final parcial = calcularCoberturas([
      _e('salidas', 1000, gastado: 1600, proyeccion: 1600),
      _e('cafe', 1000, gastado: 300, proyeccion: 600),
    ]).single;
    expect(parcial.cubre, const Dinero.pesos(400));
    expect(parcial.falta, const Dinero.pesos(200));
    expect(parcial.frase, r'cafe cubre $400.00; los $200.00 restantes salen de lo que apartas.');

    final dos = calcularCoberturas([
      _e('a', 1000, gastado: 1600, proyeccion: 1600),
      _e('b', 1000, gastado: 1100, proyeccion: 1100),
      _e('cafe', 1000, gastado: 300, proyeccion: 600),
    ]);
    expect(dos[1].origen, isNull, reason: 'a se llevó todo lo de cafe');
    expect(dos[1].cubre, const Dinero.cero());
    expect(dos[1].frase, 'Ninguna categoría tiene de dónde: sale de lo que apartas.');
    expect(calcularCoberturas([_e('a', 1000, gastado: 900, proyeccion: 1100)]), isEmpty);
  });
}
