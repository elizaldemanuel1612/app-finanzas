import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/analisis/reporte_analisis.dart';
import 'package:app_finanzas/domain/analisis/veredicto_ciclo.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/presupuesto/categorias.dart';
import 'package:app_finanzas/domain/presupuesto/cobertura_excesos.dart';
import 'package:app_finanzas/domain/reglas/monto.dart';
import 'package:test/test.dart';

// Categorías sin presupuesto: solo registrar (spec-app-finanzas-v2.md §7.3.6).

CategoriaVariable _var(String id, int pesos) => CategoriaVariable(
      id: id,
      nombre: id,
      emoji: '•',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(pesos),
    );

void main() {
  test(r'$0 es válido para una variable; negativo no', () {
    expect(validarMontoNoNegativo(const Dinero.cero()), isA<Exito<void>>());
    expect(validarMontoNoNegativo(const Dinero(-1)), isA<Falla<void>>());
    final creada = crearCategoriaVariable(
      id: 'cafe',
      nombre: 'Café',
      emoji: '☕',
      presupuestoMensualCentavos: const Dinero.cero(),
    );
    expect((creada as Exito<CategoriaVariable>).valor.sinPresupuesto, isTrue);
    expect(
      crearCategoriaVariable(id: 'x', nombre: 'x', emoji: '•', presupuestoMensualCentavos: const Dinero(-100)),
      isA<Falla<CategoriaVariable>>(),
    );
    final quitada = actualizarPresupuestoVariable(categoria: _var('super', 500), nuevoPresupuesto: const Dinero.cero());
    expect((quitada as Exito<CategoriaVariable>).valor.sinPresupuesto, isTrue);
    expect(_var('super', 500).sinPresupuesto, isFalse);
  });

  test('sin presupuesto no hay exceso ni coberturas', () {
    final estados = [
      EstadoVariable(categoria: _var('cafe', 0), gastado: const Dinero.pesos(800), proyeccion: const Dinero.pesos(1600)),
      EstadoVariable(categoria: _var('super', 1000), gastado: const Dinero.pesos(200), proyeccion: const Dinero.pesos(400)),
    ];
    expect(estados.first.exceso, const Dinero.cero());
    expect(estados.first.sobrante, const Dinero.cero());
    expect(calcularCoberturas(estados), isEmpty);
  });

  group('reporte y veredicto', () {
    const calc = CalculadoraCiclo(1);
    final hoy = DateTime(2026, 11, 15);
    final ciclo = calc.calcularPara(hoy);
    Movimiento gasto(String id, String categoria, int pesos) => Movimiento(
          clientId: id,
          fecha: hoy,
          cicloId: ciclo.id,
          periodoNatural: periodoNatural(hoy),
          monto: Dinero.pesos(pesos),
          categoriaId: categoria,
          medio: MedioPago.tarjeta,
          descripcion: id,
          estado: EstadoMovimiento.activo,
          origenCaptura: OrigenCaptura.manual,
        );
    ReporteAnalisis reporte(List<Categoria> categorias) => calcularReporteAnalisis(
          ciclo: ciclo,
          cicloAnterior: null,
          movimientos: [gasto('a', 'cafe', 900), gasto('b', 'super', 300)],
          categorias: categorias,
          hoy: hoy,
        );

    test('mixto: solo se compara lo de las categorías con presupuesto', () {
      final r = reporte([_var('cafe', 0), _var('super', 1000)]);
      expect(r.gastadoVariables, const Dinero.pesos(1200));
      expect(r.gastadoConPresupuesto, const Dinero.pesos(300));
      expect(r.gastadoSinPresupuesto, const Dinero.pesos(900));
      expect(r.soloRegistro, isFalse);
      final v = calcularVeredicto(reporte: r, hoy: hoy);
      expect(v.tono, isNot(TonoVeredicto.pasado), reason: r'$900 sin presupuesto no hacen "te pasaste"');
      // La línea de la gráfica se compara contra el presupuesto: solo lo
      // de las categorías que lo tienen.
      expect(r.acumuladoVariablesPorDia.last, const Dinero.pesos(300));
    });

    test('solo registro: sin presupuestos no se pide ponerlos', () {
      final r = reporte([_var('cafe', 0), _var('super', 0)]);
      expect(r.soloRegistro, isTrue);
      final v = calcularVeredicto(reporte: r, hoy: hoy);
      expect(v.tono, TonoVeredicto.neutro);
      expect(v.titulo, r'Llevas $1,200.00 este ciclo');
      expect(v.detalle, isNot(contains('Ponles presupuesto')));
      expect(r.acumuladoVariablesPorDia.last, const Dinero.pesos(1200), reason: 'sin presupuestos, la línea es todo lo gastado');
    });
  });
}
