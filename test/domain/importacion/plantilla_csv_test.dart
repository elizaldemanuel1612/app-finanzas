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
    expect(datos.movimientos, hasLength(1));
    expect(datos.movimientos.first.monto, const Dinero.pesos(450));
    expect(datos.categoriasPorCrear, hasLength(1));
    expect(datos.categoriasPorCrear.first.nombre, 'Súper');
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
}
