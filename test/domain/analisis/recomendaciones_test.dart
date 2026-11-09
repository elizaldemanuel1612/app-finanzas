import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/analisis/recomendaciones.dart';
import 'package:app_finanzas/domain/analisis/reporte_analisis.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:test/test.dart';

final _ciclo = Ciclo(
  id: '2026-10',
  fechaInicio: DateTime(2026, 10, 1),
  fechaFin: DateTime(2026, 10, 30),
  etiqueta: 'Oct',
  estado: EstadoCiclo.abierto,
);

CategoriaVariable _var(String id, int pesos) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );
const _renta = CategoriaFija(
  id: 'renta',
  nombre: 'renta',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: Dinero.pesos(5000),
  diaDelCiclo: 1,
);

GastoCategoria _g(Categoria c, int pesos) =>
    GastoCategoria(categoria: c, total: Dinero.pesos(pesos), porcentaje: 0, conteo: 1);

ReporteAnalisis _reporte({
  int dia = 15,
  List<GastoCategoria> porCategoria = const [],
  int gastadoVariables = 0,
  int gastadoFijas = 0,
  int presupuestoFijas = 0,
  int proyeccionVariables = 0,
  int? anteriorMismoDia,
  List<ComparacionCategoria> contraAnterior = const [],
  List<int> semana = const [0, 0, 0, 0, 0, 0, 0],
  int diasConDatos = 0,
  int pequenos = 0,
  int totalPequenos = 0,
}) =>
    ReporteAnalisis(
      ciclo: _ciclo,
      diaDelCiclo: dia,
      diasDelCiclo: 30,
      gastado: Dinero.pesos(gastadoVariables + gastadoFijas),
      gastadoVariables: Dinero.pesos(gastadoVariables),
      gastadoFijas: Dinero.pesos(gastadoFijas),
      presupuestoVariables: const Dinero.cero(),
      presupuestoFijas: Dinero.pesos(presupuestoFijas),
      promedioDiarioVariables: const Dinero.cero(),
      proyeccionVariables: Dinero.pesos(proyeccionVariables),
      porCategoria: porCategoria,
      acumuladoVariablesPorDia: const [],
      variablesAnteriorMismoDia: anteriorMismoDia == null ? null : Dinero.pesos(anteriorMismoDia),
      contraAnterior: contraAnterior,
      ultimosCiclos: const [],
      promedioPorDiaSemana: [for (final p in semana) Dinero.pesos(p)],
      diasConDatos: diasConDatos,
      dondeMasGastas: const [],
      conTarjeta: const Dinero.cero(),
      enEfectivo: const Dinero.cero(),
      gastosPequenos: pequenos,
      totalGastosPequenos: Dinero.pesos(totalPequenos),
    );

List<Recomendacion> _recs(ReporteAnalisis r, {int ingreso = 0, int? meta}) => calcularRecomendaciones(
      reporte: r,
      ingresoCiclo: Dinero.pesos(ingreso),
      metaCiclo: meta == null ? null : Dinero.pesos(meta),
    );

void main() {
  test('te pasaste: cuánto mover y desde dónde, con el ritmo', () {
    // Día 15 de 30. salidas: 1200 de 1000 → proyecta 2400 (1400 arriba).
    // auto: 100 de 2000 → proyecta 200, le sobrarían 1800.
    final recs = _recs(_reporte(porCategoria: [_g(_var('salidas', 1000), 1200), _g(_var('auto', 2000), 100)]));
    final r = recs.first;
    expect(r.tono, TonoRecomendacion.alerta);
    expect(r.titulo, r'Te pasaste en salidas por $200.00');
    expect(r.detalle, r'A este ritmo cerraría $1,400.00 arriba. Muévele $200.00 desde auto '
        r'(se estima que le sobren $1,800.00) y cuadras sin tocar lo que apartas.');
    expect(r.detalle, isNot(contains('Nada grave')));
    expect(r.accion, AccionRecomendacion.verCategoria);
    expect(r.categoriaId, 'salidas');
  });

  test('el sobrante se reparte: no se ofrece dos veces el mismo dinero', () {
    // auto sobra 1800. super (500 arriba, la mayor) toma 500; salidas
    // (200) lo que queda, de la misma auto.
    final alertas = _recs(_reporte(porCategoria: [
      _g(_var('salidas', 1000), 1200),
      _g(_var('super', 1000), 1500),
      _g(_var('auto', 2000), 100),
    ])).where((r) => r.tono == TonoRecomendacion.alerta).toList();
    expect(alertas[0].titulo, contains('super'));
    expect(alertas[0].detalle, contains(r'Muévele $500.00 desde auto (se estima que le sobren $1,800.00)'));
    expect(alertas[1].detalle, contains(r'Muévele $200.00 desde auto (se estima que le sobren $1,300.00)'));

    // Sobrante que no alcanza: cubre una parte y el resto sale de lo apartado.
    final parcial = _recs(_reporte(porCategoria: [
      _g(_var('salidas', 1000), 1600),
      _g(_var('cafe', 1000), 300), // proyecta 600, sobran 400
    ])).first;
    expect(parcial.detalle, contains(r'Desde cafe puedes cubrir $400.00; los otros $200.00 saldrían de lo que apartas.'));
  });

  test('con más de dos excedidas, el resto va junto en una sola', () {
    final recs = _recs(_reporte(porCategoria: [
      _g(_var('a', 1000), 1500),
      _g(_var('b', 1000), 1400),
      _g(_var('c', 1000), 1300),
      _g(_var('d', 1000), 1200),
      _g(_var('e', 1000), 1100),
      _g(_var('f', 1000), 1050),
    ]));
    final alertas = recs.where((r) => r.tono == TonoRecomendacion.alerta).toList();
    expect(alertas, hasLength(3));
    expect(alertas[0].titulo, contains(' a '));
    expect(alertas[1].titulo, contains(' b '));
    expect(alertas[2].titulo, 'También te pasaste en 4 categorías más');
    expect(alertas[2].detalle, startsWith(r'c ($300.00), d ($200.00), e ($100.00) y 1 más: $650.00 en total.'));
    expect(alertas[2].categoriaId, 'c');

    final una = _recs(_reporte(porCategoria: [
      _g(_var('a', 1000), 1500),
      _g(_var('b', 1000), 1400),
      _g(_var('c', 1000), 1300),
    ])).where((r) => r.tono == TonoRecomendacion.alerta).last;
    expect(una.titulo, 'También te pasaste en 1 categoría más');
    expect(una.detalle, startsWith(r'c ($300.00): $300.00 en total.'));
  });

  test('ya usaste todo: llegó justo o le quedan centavos', () {
    final justo = _recs(_reporte(porCategoria: [_g(_var('auto', 2700), 2700)])).single;
    expect(justo.titulo, 'Ya usaste todo lo de auto');
    expect(justo.detalle, contains('Faltan 15 días'));
    final centavos = GastoCategoria(
      categoria: _var('cafe', 100),
      total: const Dinero(9990),
      porcentaje: 0,
      conteo: 1,
    );
    expect(_recs(_reporte(porCategoria: [centavos])).single.titulo, 'Ya usaste todo lo de cafe');
    // El último día ya no aplica: no hay días por delante.
    expect(_recs(_reporte(dia: 30, porCategoria: [_g(_var('auto', 2700), 2700)])), isEmpty);
  });

  test('te pasaste sin ninguna holgada: sale de lo que apartas', () {
    final recs = _recs(_reporte(porCategoria: [_g(_var('salidas', 1000), 1200)]));
    expect(recs.single.detalle, contains('sale de lo que apartas'));
    // Último día: ya no hay ritmo ni días por delante.
    final cierre = _recs(_reporte(dia: 30, porCategoria: [_g(_var('salidas', 1000), 1200)])).single;
    expect(cierre.detalle, r'Salió de lo que apartaste. Si pasa seguido, súbele el presupuesto el próximo ciclo.');
  });

  test('va rápido: proyección, cuánto arriba y máximo por día', () {
    // Día 15 de 30: 600 de 1000 → proyecta 1200; quedan 400 en 15 días.
    final recs = _recs(_reporte(porCategoria: [_g(_var('super', 1000), 600)]));
    expect(recs.single.titulo, 'super va rápido');
    expect(recs.single.detalle, contains(r'cerraría en $1,200.00, $200.00 arriba'));
    expect(recs.single.detalle, contains(r'máximo $26.66 al día los 15 días'));
    expect(recs.single.tono, TonoRecomendacion.atencion);
  });

  test('va rápido no aplica los primeros días ni el último día', () {
    expect(_recs(_reporte(dia: 2, porCategoria: [_g(_var('super', 1000), 600)])), isEmpty);
    expect(_recs(_reporte(dia: 30, porCategoria: [_g(_var('super', 1000), 990)])), isEmpty);
  });

  test('te está sobrando: pasada la mitad, menos de la mitad de lo que tocaría', () {
    final recs = _recs(_reporte(dia: 20, porCategoria: [_g(_var('auto', 3000), 500)]));
    expect(recs.single.tono, TonoRecomendacion.positivo);
    expect(recs.single.titulo, 'Te está sobrando en auto');
    expect(recs.single.detalle, contains('van 20 de 30 días'));
    // Presupuesto chico o antes de la mitad: nada.
    expect(_recs(_reporte(dia: 20, porCategoria: [_g(_var('cafe', 400), 10)])), isEmpty);
    expect(_recs(_reporte(dia: 10, porCategoria: [_g(_var('auto', 3000), 100)])), isEmpty);
  });

  test('las fijas no generan avisos de ritmo', () {
    expect(_recs(_reporte(porCategoria: [_g(_renta, 6000)])), isEmpty);
  });

  test('más que el ciclo pasado, con sus umbrales', () {
    ComparacionCategoria c(Categoria cat, int actual, int anterior) =>
        ComparacionCategoria(categoria: cat, actual: Dinero.pesos(actual), anterior: Dinero.pesos(anterior));
    final s = _var('super', 9000);
    final recs = _recs(_reporte(contraAnterior: [
      c(s, 1300, 1000),
      c(_var('poco', 9000), 400, 100), // base < 200
      c(_var('chico', 9000), 450, 300), // diferencia < 300
      c(_var('igual', 9000), 2400, 2000), // < 125 %
      c(_renta, 9000, 5000), // fija
    ]));
    expect(recs.single.titulo, 'Más en super que el ciclo pasado');
    expect(recs.single.detalle, contains(r'A los 15 días llevas $1,300.00; el ciclo pasado llevabas $1,000.00'));
  });

  test('gastos pequeños: 6 o más que suman al menos 10 %', () {
    final recs = _recs(_reporte(gastadoVariables: 1000, pequenos: 6, totalPequenos: 100));
    expect(recs.single.titulo, 'Los gastos pequeños suman');
    expect(recs.single.accion, AccionRecomendacion.verGastos);
    expect(_recs(_reporte(gastadoVariables: 1000, pequenos: 5, totalPequenos: 500)), isEmpty);
    expect(_recs(_reporte(gastadoVariables: 1000, pequenos: 6, totalPequenos: 99)), isEmpty);
  });

  test('tu meta: a favor, en juego y sin meta', () {
    final r = _reporte(gastadoFijas: 4000, presupuestoFijas: 5000, gastadoVariables: 5000);
    final aFavor = _recs(r, ingreso: 20000, meta: 5000).single;
    expect(aFavor.titulo, 'Vas para cumplir tu meta');
    expect(aFavor.detalle, contains(r'apartarías $5,000.00 de $5,000.00'));
    expect(aFavor.accion, AccionRecomendacion.verMeta);

    final enJuego = _recs(r, ingreso: 16000, meta: 2000).single;
    expect(enJuego.titulo, 'Tu meta está en juego');
    expect(enJuego.detalle, contains(r'apartarías $1,000.00 de $2,000.00'));
    expect(enJuego.detalle, contains(r'Gastando $66.66 menos al día'));

    final noAlcanza = _recs(r, ingreso: 14000, meta: 2000).single;
    expect(noAlcanza.tono, TonoRecomendacion.alerta);
    expect(noAlcanza.titulo, 'A este ritmo no alcanza para apartar');
    expect(noAlcanza.detalle, contains(r'pasarían lo que entra por $1,000.00'));

    // Fijas ya por encima de su presupuesto: cuenta lo gastado.
    final pasadas = _reporte(gastadoFijas: 6000, presupuestoFijas: 5000);
    expect(_recs(pasadas, ingreso: 10000, meta: 1000).single.detalle, contains(r'$4,000.00'));

    expect(_recs(r, ingreso: 20000), isEmpty);
    expect(_recs(r, ingreso: 20000, meta: 0), isEmpty);
    expect(_recs(_reporte(dia: 2), ingreso: 20000, meta: 100), isEmpty);
    expect(_recs(_reporte(dia: 30), ingreso: 20000, meta: 100), isEmpty);
  });

  test('vas abajo del ciclo pasado', () {
    final recs = _recs(_reporte(gastadoVariables: 800, anteriorMismoDia: 1000));
    expect(recs.single.titulo, r'Vas $200.00 abajo del ciclo pasado');
    expect(_recs(_reporte(gastadoVariables: 900, anteriorMismoDia: 1000)), isEmpty);
    expect(_recs(_reporte(gastadoVariables: 100, anteriorMismoDia: 400)), isEmpty);
  });

  test('tu día de más gasto: 1.8 veces el resto, con 14 días de datos', () {
    final recs = _recs(_reporte(diasConDatos: 14, semana: [100, 100, 100, 100, 100, 400, 100]));
    expect(recs.single.titulo, 'Los sábados gastas más');
    expect(recs.single.tono, TonoRecomendacion.informativo);
    expect(_recs(_reporte(diasConDatos: 13, semana: [100, 100, 100, 100, 100, 400, 100])), isEmpty);
    expect(_recs(_reporte(diasConDatos: 14, semana: [100, 100, 100, 100, 100, 150, 100])), isEmpty);
    expect(_recs(_reporte(diasConDatos: 14, semana: [0, 0, 0, 0, 0, 0, 50])), isEmpty);
  });

  test('máximo 5, lo urgente primero', () {
    final cats = [for (var i = 0; i < 4; i++) _g(_var('c$i', 100), 200)];
    final recs = _recs(_reporte(
      porCategoria: [...cats, _g(_var('rapido', 1000), 600)],
      diasConDatos: 14,
      semana: [100, 100, 100, 100, 100, 400, 100],
      pequenos: 6,
      totalPequenos: 500,
    ));
    // 4 excedidas = 2 detalladas + 1 que junta el resto; luego 2 de
    // atención (va rápido, gastos pequeños); el día de más gasto se queda fuera.
    expect(recs, hasLength(5));
    expect(recs.take(3).every((r) => r.tono == TonoRecomendacion.alerta), isTrue);
    expect(recs.skip(3).every((r) => r.tono == TonoRecomendacion.atencion), isTrue);
    expect(nombresDiaSemana, hasLength(7));
  });
}
