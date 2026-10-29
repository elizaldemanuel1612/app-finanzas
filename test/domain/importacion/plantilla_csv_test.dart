import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/exportacion/exportar_csv.dart';
import 'package:app_finanzas/domain/importacion/csv.dart';
import 'package:app_finanzas/domain/importacion/importar_movimientos.dart';
import 'package:app_finanzas/domain/importacion/plantilla_csv.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

void main() {
  test('los encabezados de la plantilla son los mismos que exportarMovimientosCsv', () {
    final filas = leerCsv(generarPlantillaCsvDeEjemplo());
    expect(filas.first, encabezadosExportacion);
  });

  test('la plantilla se reimporta a sí misma sin renglones con problema', () {
    final resultado = previsualizarImportacion(
      contenidoCsv: generarPlantillaCsvDeEjemplo(),
      calculadoraCiclo: const CalculadoraCiclo(1),
      categoriasExistentes: const [],
    );

    final datos = (resultado as Exito<ResultadoImportacion>).valor;
    expect(datos.renglonesConProblema, isEmpty);
    expect(datos.avisos, isEmpty);
    expect(datos.movimientos, hasLength(2));
    expect(datos.movimientos.first.monto, const Dinero.pesos(450));
    expect(datos.movimientos.first.fecha, DateTime(2026, 8, 5, 13, 30));
    expect(datos.movimientos.last.medio, MedioPago.efectivo);
    expect([for (final c in datos.categoriasPorCrear) '${c.emoji} ${c.nombre}'], ['🛒 Súper', '🍿 Salidas']);
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
}
