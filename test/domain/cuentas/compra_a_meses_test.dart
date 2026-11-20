import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/analisis/gastos_recurrentes.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/ciclos_para_consultar.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/historial_ciclos.dart';
import 'package:app_finanzas/domain/cuentas/compra_a_meses.dart';
import 'package:app_finanzas/domain/cuentas/fechas_tarjeta.dart';
import 'package:app_finanzas/domain/cuentas/saldos.dart';
import 'package:app_finanzas/domain/exportacion/exportar_csv.dart';
import 'package:app_finanzas/domain/importacion/importar_movimientos.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §7.3.1 (2026-11-16): compras a meses sin
// intereses.

const _calculadora = CalculadoraCiclo(1);

Cuenta _tarjeta({bool conSaldo = true}) => Cuenta(
      id: 'platino',
      nombre: 'Platino',
      emoji: '💳',
      tipo: TipoCuenta.credito,
      llevaSaldo: conSaldo,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 1, 1),
      diaCorte: 5,
      diaPago: 25,
    );

List<Movimiento> _compra({
  String id = 'compra-tv-0001',
  int pesos = 12000,
  int meses = 12,
  DateTime? fecha,
  String? cuentaId = 'platino',
}) =>
    switch (crearCompraAMeses(
      compraId: id,
      fecha: fecha ?? DateTime(2026, 11, 10, 18, 30),
      calculadoraCiclo: _calculadora,
      total: Dinero.pesos(pesos),
      meses: meses,
      categoriaId: 'casa',
      descripcion: 'Pantalla',
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuentaId,
    )) {
      Exito(:final valor) => valor,
      Falla(:final mensaje) => throw StateError(mensaje),
    };

void main() {
  group('reparto', () {
    test('el total entre los meses; los centavos que sobran, en la primera', () {
      expect(repartirEnMensualidades(const Dinero.pesos(12000), 12), List.filled(12, const Dinero.pesos(1000)));
      final raro = repartirEnMensualidades(const Dinero(100000), 3);
      expect(raro, const [Dinero(33334), Dinero(33333), Dinero(33333)]);
      expect(Dinero.suma(raro), const Dinero(100000));
    });

    test('un mes después cada una, mismo día y hora; en meses cortos, el último día', () {
      final compra = DateTime(2026, 1, 31, 9, 15);
      expect(fechaDeMensualidad(compra, 1), compra);
      expect(fechaDeMensualidad(compra, 2), DateTime(2026, 2, 28, 9, 15));
      expect(fechaDeMensualidad(compra, 3), DateTime(2026, 3, 31, 9, 15));
      expect(fechaDeMensualidad(DateTime(2026, 11, 10), 3), DateTime(2027, 1, 10));
    });
  });

  group('crear', () {
    test('una mensualidad por ciclo, ligadas, con clientId estable', () {
      final lista = _compra();
      expect(lista, hasLength(12));
      expect({for (final m in lista) m.cicloId}, hasLength(12));
      expect(lista.first.cicloId, '2026-11');
      expect(lista.last.cicloId, '2027-10');
      expect(lista.map((m) => m.clientId).take(2), ['compra-tv-0001-m1', 'compra-tv-0001-m2']);
      expect(lista.every((m) => m.compraId == 'compra-tv-0001' && m.meses == 12 && m.cuentaId == 'platino'), isTrue);
      expect(lista.every((m) => m.medio == MedioPago.tarjeta && m.estado == EstadoMovimiento.activo), isTrue);
      expect([for (final m in lista) m.mensualidad], List.generate(12, (i) => i + 1));
      expect(lista.first.esAMeses, isTrue);
    });

    test('se ida y vuelta por JSON con sus campos', () {
      final m = _compra().first;
      expect(Movimiento.fromJson(m.toJson()), m);
      expect(m.toJson(), containsPair('compraId', 'compra-tv-0001'));
      final contado = m.copyWith();
      expect(contado.hashCode, m.hashCode);
    });

    test('no acepta plazos fuera de rango, montos muy chicos ni un monto inválido', () {
      Resultado<List<Movimiento>> con({int meses = 3, Dinero total = const Dinero.pesos(300), String id = 'compra-larga-0001'}) =>
          crearCompraAMeses(
            compraId: id,
            fecha: DateTime(2026, 11, 10),
            calculadoraCiclo: _calculadora,
            total: total,
            meses: meses,
            categoriaId: 'c',
            descripcion: 'd',
            origenCaptura: OrigenCaptura.manual,
            cuentaId: null,
          );
      expect(con(meses: 1), isA<Falla<List<Movimiento>>>());
      expect(con(meses: maxMeses + 1), isA<Falla<List<Movimiento>>>());
      expect(con(total: const Dinero(2)), isA<Falla<List<Movimiento>>>());
      // Un clientId vacío no pasa las reglas de creación.
      expect(con(id: ''), isA<Falla<List<Movimiento>>>());
    });

    test('mensualidadesDe las regresa en orden', () {
      final lista = _compra(meses: 3).reversed.toList();
      expect([for (final m in mensualidadesDe('compra-tv-0001', lista)) m.mensualidad], [1, 2, 3]);
    });
  });

  group('la tarjeta', () {
    test('se debe el total, pero cada corte pide solo su mensualidad', () {
      final gastos = _compra();
      final tarjeta = _tarjeta();
      expect(deudaDe(tarjeta, gastos, const []), const Dinero.pesos(12000));

      // Corte del 5 de diciembre: entra la primera (10 nov).
      final dic = pagoDeTarjeta(tarjeta, gastos, const [], hoy: DateTime(2026, 12, 6))!;
      expect(dic.monto, const Dinero.pesos(1000));
      // Corte del 5 de enero: la de diciembre (sin pagar la primera, se suman).
      final ene = pagoDeTarjeta(tarjeta, gastos, const [], hoy: DateTime(2027, 1, 6))!;
      expect(ene.monto, const Dinero.pesos(2000));

      // Sin saldo: lo del periodo, una mensualidad.
      final referencia = pagoDeTarjeta(_tarjeta(conSaldo: false), gastos, const [], hoy: DateTime(2027, 1, 6))!;
      expect(referencia.monto, const Dinero.pesos(1000));
    });

    test('cuánto falta a meses y qué compras siguen vigentes', () {
      final gastos = [..._compra(), ..._compra(id: 'compra-cel-0001', pesos: 900, meses: 3, fecha: DateTime(2026, 6, 1))];
      final tarjeta = _tarjeta();
      final hoy = DateTime(2026, 11, 10, 20);
      expect(porPagarAMeses(tarjeta, gastos, hoy: hoy), const Dinero.pesos(11000));
      final compras = comprasAMesesDe(tarjeta, gastos, hoy: hoy);
      expect(compras, hasLength(1));
      final tv = compras.single;
      expect((tv.descripcion, tv.total, tv.mensualidad, tv.meses, tv.pagadas, tv.falta, tv.terminada),
          ('Pantalla', const Dinero.pesos(12000), const Dinero.pesos(1000), 12, 1, const Dinero.pesos(11000), false));

      final dos = comprasAMesesDe(tarjeta, [..._compra(id: 'compra-aaa-0001', fecha: DateTime(2026, 10, 1)), ..._compra(id: 'compra-bbb-0001')], hoy: hoy);
      expect([for (final c in dos) c.compraId], ['compra-bbb-0001', 'compra-aaa-0001']);

      final otraCuenta = comprasAMesesDe(tarjeta, _compra(cuentaId: 'otra'), hoy: hoy);
      expect(otraCuenta, isEmpty);
    });
  });

  group('las mensualidades futuras', () {
    final enCurso = _calculadora.calcularPara(DateTime(2026, 11, 15));

    test('no son ciclos para consultar ni ciclos anteriores', () {
      final gastos = _compra(fecha: DateTime(2026, 10, 10));
      final consultables = ciclosParaConsultar(
        enCurso: enCurso,
        movimientos: gastos,
        guardados: const [],
        calculadora: _calculadora,
      );
      expect([for (final c in consultables) c.ciclo.id], ['2026-11', '2026-10']);

      final historial = calcularHistorialCiclos(
        ciclosGuardados: const [],
        todosLosMovimientos: gastos,
        todosLosIngresosExtra: const [],
        calculadoraCiclo: _calculadora,
        cicloActualId: enCurso.id,
      );
      expect([for (final c in historial) c.ciclo.id], ['2026-10']);
    });

    test('no cuentan como gasto que se repite', () {
      final gastos = _compra(fecha: DateTime(2026, 1, 10));
      expect(detectarRecurrentes(gastos, hoy: DateTime(2026, 11, 15)), isEmpty);
    });
  });

  group('CSV', () {
    test('la columna Meses va y vuelve: la compra se vuelve a ligar', () {
      const casa = CategoriaVariable(
        id: 'casa',
        nombre: 'Casa',
        emoji: '🏠',
        activa: true,
        esNecesaria: true,
        presupuestoMensualCentavos: Dinero.pesos(3000),
      );
      final gastos = _compra(meses: 3, pesos: 900);
      final csv = exportarMovimientosCsv(movimientos: gastos, categorias: const [casa], cuentas: [_tarjeta()]);
      expect(csv.split('\n')[1], endsWith(',compra-tv-0001-m1,1 de 3'));
      final r = previsualizarImportacion(
        contenidoCsv: csv,
        calculadoraCiclo: _calculadora,
        categoriasExistentes: const [casa],
        cuentasExistentes: [_tarjeta()],
      );
      final leidos = (r as Exito<ResultadoImportacion>).valor.movimientos;
      expect([for (final m in leidos) (m.compraId, m.mensualidad, m.meses)], [
        ('compra-tv-0001', 1, 3),
        ('compra-tv-0001', 2, 3),
        ('compra-tv-0001', 3, 3),
      ]);
    });

    test('lee "2 de 12" y "2/12"; sin ID de mensualidad entra de contado con aviso', () {
      expect(leerMensualidad('2 de 12'), (2, 12));
      expect(leerMensualidad(' 3/6 '), (3, 6));
      for (final malo in ['13 de 12', '0 de 3', '1 de 1', '1 de 60', 'dos de doce']) {
        expect(leerMensualidad(malo), isNull, reason: malo);
      }
      const csv = 'Fecha,Monto,Categoría,ID,Meses\n'
          '2026-11-10,100.00,Casa,gasto-suelto-01,1 de 3\n'
          '2026-11-10,100.00,Casa,compra-x-0001-m2,1 de 3\n'
          '2026-11-10,100.00,Casa,,basura\n';
      final r = previsualizarImportacion(contenidoCsv: csv, calculadoraCiclo: _calculadora, categoriasExistentes: const []);
      final valor = (r as Exito<ResultadoImportacion>).valor;
      expect(valor.movimientos.every((m) => !m.esAMeses), isTrue);
      expect(valor.avisos.where((a) => a.motivo.contains('de contado')), hasLength(3));
    });
  });
}
