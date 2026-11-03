import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/exportacion/exportar_csv.dart';
import 'package:app_finanzas/domain/importacion/csv.dart';
import 'package:app_finanzas/domain/importacion/importar_movimientos.dart';
import 'package:app_finanzas/domain/importacion/plantilla_csv.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

void main() {
  test('los encabezados de la plantilla son los mismos que exportarMovimientosCsv', () {
    final filas = leerCsv(generarPlantillaCsvDeEjemplo());
    expect(filas.firstWhere((f) => !esRenglonDeInstrucciones(f)), encabezadosExportacion);
  });

  test('las instrucciones dicen los valores permitidos, el formato y el emoji', () {
    final texto = instruccionesParaIA.join(' ');
    for (final esperado in ['.csv', 'UTF-8', 'aaaa-mm-dd', 'Tarjeta o Efectivo', 'Activo o Anulado', 'Fija o Variable', 'Presupuesto', 'elimina', 'emoji']) {
      expect(texto, contains(esperado));
    }
    for (final columna in encabezadosExportacion) {
      expect(texto, contains(columna));
    }
    // Una comilla suelta rompería la lectura del CSV.
    expect(texto, isNot(contains('"')));
  });

  test('la plantilla se reimporta a sí misma sin renglones con problema', () {
    final resultado = previsualizarImportacion(
      contenidoCsv: generarPlantillaCsvDeEjemplo(),
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: const [],
      cuentasExistentes: cuentasBase(DateTime(2026, 8, 1)),
    );

    final datos = (resultado as Exito<ResultadoImportacion>).valor;
    expect(datos.renglonesConProblema, isEmpty);
    // Solo avisa que "BBVA débito" no existía y se crea, de débito.
    expect(datos.avisos.single.motivo, contains('BBVA débito'));
    expect(datos.cuentasPorCrear.single.tipo, TipoCuenta.debito);
    expect(datos.movimientos.first.cuentaId, datos.cuentasPorCrear.single.id);
    expect(datos.movimientos.last.cuentaId, idCuentaEfectivo);
    expect(datos.movimientos, hasLength(2));
    expect(datos.movimientos.first.monto, const Dinero.pesos(450));
    expect(datos.movimientos.first.fecha, DateTime(2026, 8, 5, 13, 30));
    expect(datos.movimientos.last.medio, MedioPago.efectivo);
    expect(
      [for (final c in datos.categoriasPorCrear) '${c.emoji} ${c.nombre}'],
      ['🛒 Súper', '🍿 Salidas', '🏠 Vivienda'],
    );
    expect((datos.categoriasFinales.first as CategoriaVariable).presupuestoMensualCentavos, const Dinero.pesos(6000));
    expect((datos.categoriasFinales.last as CategoriaFija).montoFijoCentavos, const Dinero.pesos(12000));
  });

  test('la ayuda describe cada columna, en el mismo orden', () {
    expect([for (final (columna, _) in ayudaColumnasCsv) columna], encabezadosExportacion);
  });

  test('ida y vuelta: lo que exportarMovimientosCsv escribe se reimporta igual', () {
    const categoria = CategoriaVariable(
      id: 'super',
      nombre: 'Súper',
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(8000),
    );
    final movimiento = Movimiento(
      clientId: 'c1',
      fecha: DateTime(2026, 8, 5),
      cicloId: '2026-08',
      periodoNatural: '2026-08',
      monto: const Dinero.pesos(450),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'Compra de la quincena',
      estado: EstadoMovimiento.activo,
      origenCaptura: OrigenCaptura.manual,
    );

    final csvExportado = exportarMovimientosCsv(movimientos: [movimiento], categorias: const [categoria]);

    final resultado = previsualizarImportacion(
      contenidoCsv: csvExportado,
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: const [categoria],
    );

    final datos = (resultado as Exito<ResultadoImportacion>).valor;
    expect(datos.renglonesConProblema, isEmpty);
    // La categoría "Súper" ya existía (mismo nombre): no hay que crearla de nuevo.
    expect(datos.categoriasPorCrear, isEmpty);
    expect(datos.movimientos, hasLength(1));
    expect(datos.movimientos.first.monto, movimiento.monto);
    expect(datos.movimientos.first.categoriaId, 'super');
    expect(datos.movimientos.first.descripcion, movimiento.descripcion);
  });

  test('ida y vuelta completa: estado, origen, hora, medio, ID y emoji se conservan', () {
    const categoria = CategoriaVariable(
      id: 'cafe',
      nombre: '=Café',
      emoji: '☕',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(500),
    );
    final movimientos = [
      for (final (i, estado, origen) in [
        (0, EstadoMovimiento.activo, OrigenCaptura.voz),
        (1, EstadoMovimiento.anulado, OrigenCaptura.ticket),
        (2, EstadoMovimiento.propuesto, OrigenCaptura.recurrente),
        (3, EstadoMovimiento.activo, OrigenCaptura.migracion),
      ])
        Movimiento(
          clientId: 'id-$i',
          fecha: DateTime(2026, 8, 5 + i, 8 + i, 15),
          cicloId: '2026-08',
          periodoNatural: '2026-08',
          monto: Dinero(1050 + i),
          categoriaId: 'cafe',
          medio: i.isEven ? MedioPago.efectivo : MedioPago.tarjeta,
          descripcion: '-Latte, "grande"',
          estado: estado,
          origenCaptura: origen,
        ),
    ];

    final csv = exportarMovimientosCsv(movimientos: movimientos, categorias: const [categoria]);
    // En una cuenta nueva: la categoría se recrea con su emoji.
    final datos = (previsualizarImportacion(
      contenidoCsv: csv,
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: const [],
    ) as Exito<ResultadoImportacion>)
        .valor;

    expect(datos.renglonesConProblema, isEmpty);
    expect(datos.avisos, isEmpty);
    expect(datos.categoriasPorCrear.single.nombre, '=Café');
    expect(datos.categoriasPorCrear.single.emoji, '☕');
    for (final (i, original) in movimientos.indexed) {
      final leido = datos.movimientos[i];
      expect(leido.clientId, original.clientId);
      expect(leido.fecha, original.fecha);
      expect(leido.monto, original.monto);
      expect(leido.medio, original.medio);
      expect(leido.descripcion, original.descripcion);
      expect(leido.estado, original.estado);
      expect(leido.origenCaptura, original.origenCaptura);
    }
    expect(datos.anulados, 1);
    // Solo lo activo suma: 10.50 + 10.53.
    expect(datos.totalesPorCiclo.values.single, Dinero(1050 + 1053));
  });

  test('ida y vuelta: el plan de las categorías, también las sin gastos', () {
    const categorias = <Categoria>[
      CategoriaVariable(
        id: 'super',
        nombre: 'Súper',
        emoji: '🛒',
        activa: true,
        esNecesaria: true,
        presupuestoMensualCentavos: Dinero.pesos(6000),
      ),
      CategoriaFija(
        id: 'renta',
        nombre: 'Renta',
        emoji: '🏠',
        activa: false,
        esNecesaria: true,
        montoFijoCentavos: Dinero(1234567),
        diaDelCiclo: 28,
      ),
    ];
    final csv = exportarMovimientosCsv(movimientos: const [], categorias: categorias);
    final datos = (previsualizarImportacion(
      contenidoCsv: csv,
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: categorias,
    ) as Exito<ResultadoImportacion>)
        .valor;
    expect(datos.avisos, isEmpty);
    expect(datos.eliminaDatos, isFalse);
    expect(datos.categoriasPorActualizar, isEmpty);
    expect([for (final c in datos.categoriasFinales) c.toJson()], [for (final c in categorias) c.toJson()]);
  });

  test('ida y vuelta de la cuenta de cada gasto', () {
    final amex = Cuenta(
      id: 'amex',
      nombre: 'Amex',
      emoji: '💳',
      tipo: TipoCuenta.credito,
      llevaSaldo: false,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 8, 1),
    );
    final cuentas = [...cuentasBase(DateTime(2026, 8, 1)), amex];
    Movimiento gasto(String id, {String? cuenta, MedioPago medio = MedioPago.tarjeta}) => Movimiento(
          clientId: id,
          fecha: DateTime(2026, 8, 5),
          cicloId: '2026-08',
          periodoNatural: '2026-08',
          monto: const Dinero.pesos(10),
          categoriaId: 'x',
          medio: medio,
          descripcion: 'x',
          estado: EstadoMovimiento.activo,
          origenCaptura: OrigenCaptura.manual,
          cuentaId: cuenta,
        );
    final csv = exportarMovimientosCsv(
      movimientos: [gasto('a', cuenta: 'amex'), gasto('b', medio: MedioPago.efectivo)],
      categorias: const [],
      cuentas: cuentas,
    );
    final datos = (previsualizarImportacion(
      contenidoCsv: csv,
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: const [],
      cuentasExistentes: cuentas,
    ) as Exito<ResultadoImportacion>)
        .valor;
    expect(datos.cuentasPorCrear, isEmpty);
    expect([for (final m in datos.movimientos) m.cuentaId], ['amex', idCuentaEfectivo]);
  });

  test('cuentas nuevas: el tipo sale del medio, y la cuenta manda sobre el medio', () {
    final datos = (previsualizarImportacion(
      contenidoCsv: 'fecha,monto,medio,cuenta\n'
          '2026-08-05,1,Débito,Nu\n2026-08-05,1,Efectivo,Cartera\n2026-08-05,1,,Amex\n2026-08-06,1,Efectivo,nu\n',
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: const [],
    ) as Exito<ResultadoImportacion>)
        .valor;
    expect([for (final c in datos.cuentasPorCrear) c.tipo], [TipoCuenta.debito, TipoCuenta.efectivo, TipoCuenta.credito]);
    expect(datos.cuentasPorCrear.first.llevaSaldo, isFalse);
    expect(datos.movimientos.last.cuentaId, datos.cuentasPorCrear.first.id);
    expect(datos.movimientos.last.medio, MedioPago.tarjeta);
  });
}
