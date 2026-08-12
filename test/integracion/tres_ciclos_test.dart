import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/data/repositorios/local/categoria_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/ciclo_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/ingreso_extra_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_repositorio_archivo.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/cierre_ciclo.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/ingresos_ciclo.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:app_finanzas/domain/reglas/creacion_ingreso_extra.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

// Criterio de aceptación de la Fase 5 (paquete-construccion-final.md §9):
// tres ciclos simulados de punta a punta sin descuadre. Un cuarto ciclo
// con ingreso extra se agrega para cubrir la última pieza de la fase.

const _calculadora = CalculadoraCiclo(1); // cortes de mes natural: más fácil de razonar

final _renta = CategoriaFija(
  id: 'renta',
  nombre: 'Renta',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: const Dinero.pesos(5000),
  diaDelCiclo: 1,
);

final _super = CategoriaVariable(
  id: 'super',
  nombre: 'Súper',
  emoji: '🛒',
  activa: true,
  esNecesaria: false,
  presupuestoMensualCentavos: const Dinero.pesos(8000),
);

Movimiento _movimiento({
  required String clientId,
  required String categoriaId,
  required DateTime fecha,
  required int pesos,
}) {
  final resultado = crearMovimiento(
    clientId: clientId,
    fecha: fecha,
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(pesos),
    categoriaId: categoriaId,
    medio: MedioPago.tarjeta,
    descripcion: categoriaId,
    origenCaptura: OrigenCaptura.manual,
  ) as Exito<Movimiento>;
  return resultado.valor;
}

void main() {
  late Directory temp;
  late CategoriaRepositorioArchivo categoriaRepositorio;
  late MovimientoRepositorioArchivo movimientoRepositorio;
  late CicloRepositorioArchivo cicloRepositorio;
  late IngresoExtraRepositorioArchivo ingresoExtraRepositorio;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
    categoriaRepositorio = CategoriaRepositorioArchivo(File('${temp.path}/categorias.json'));
    movimientoRepositorio = MovimientoRepositorioArchivo(File('${temp.path}/movimientos.json'));
    cicloRepositorio = CicloRepositorioArchivo(File('${temp.path}/ciclos.json'));
    ingresoExtraRepositorio = IngresoExtraRepositorioArchivo(File('${temp.path}/ingresos.json'));

    await categoriaRepositorio.guardar(_renta);
    await categoriaRepositorio.guardar(_super);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// Captura los movimientos de un ciclo, opcionalmente un ingreso extra,
  /// calcula su snapshot de cierre y lo persiste — el flujo completo que
  /// hoy hace `PantallaCierreCiclo`, aquí ejercitado directo contra los
  /// repositorios.
  Future<void> capturarYCerrarCiclo({
    required DateTime fechaDentroDelCiclo,
    required List<(String categoriaId, int pesos)> gastosVariables,
    required bool conMovimientoAnulado,
    int? extraApartadoPesos,
    int? extraGastoPesos,
  }) async {
    final ciclo = _calculadora.calcularPara(fechaDentroDelCiclo);

    await movimientoRepositorio.guardar(_movimiento(
      clientId: 'renta-${ciclo.id}',
      categoriaId: 'renta',
      fecha: DateTime(ciclo.fechaInicio.year, ciclo.fechaInicio.month, 1),
      pesos: 5000,
    ));

    for (var i = 0; i < gastosVariables.length; i++) {
      final (categoriaId, pesos) = gastosVariables[i];
      await movimientoRepositorio.guardar(_movimiento(
        clientId: 'gasto-${ciclo.id}-$i',
        categoriaId: categoriaId,
        fecha: fechaDentroDelCiclo,
        pesos: pesos,
      ));
    }

    if (conMovimientoAnulado) {
      final anulado = await movimientoRepositorio.guardar(_movimiento(
        clientId: 'anulado-${ciclo.id}',
        categoriaId: 'super',
        fecha: fechaDentroDelCiclo,
        pesos: 999,
      ));
      await movimientoRepositorio.anular(anulado.id!);
    }

    if (extraApartadoPesos != null) {
      final extra = crearIngresoExtra(
        id: 'extra-apartado-${ciclo.id}',
        fecha: fechaDentroDelCiclo,
        calculadoraCiclo: _calculadora,
        monto: Dinero.pesos(extraApartadoPesos),
        etiqueta: 'Bono',
        destino: DestinoExtra.apartado,
      ) as Exito<IngresoExtra>;
      await ingresoExtraRepositorio.guardar(extra.valor);
    }
    if (extraGastoPesos != null) {
      final extra = crearIngresoExtra(
        id: 'extra-gasto-${ciclo.id}',
        fecha: fechaDentroDelCiclo,
        calculadoraCiclo: _calculadora,
        monto: Dinero.pesos(extraGastoPesos),
        etiqueta: 'Venta',
        destino: DestinoExtra.gasto,
      ) as Exito<IngresoExtra>;
      await ingresoExtraRepositorio.guardar(extra.valor);
    }

    final categorias = await categoriaRepositorio.listarTodas();
    final movimientosDelCiclo = await movimientoRepositorio.listarPorCiclo(ciclo.id);
    final extrasDelCiclo = await ingresoExtraRepositorio.listarPorCiclo(ciclo.id);
    final ingresos = calcularIngresosDelCiclo(
      ingresoBase: const Dinero.pesos(20000),
      cicloId: ciclo.id,
      extras: extrasDelCiclo,
    );

    final resultado = calcularSnapshotCierre(
      ciclo: ciclo,
      movimientos: movimientosDelCiclo,
      categorias: categorias,
      ingresos: ingresos,
      metaBase: const Dinero.pesos(6000),
      fechaCierre: ciclo.fechaFin.add(const Duration(days: 1)),
    );
    expect(resultado.esExito, isTrue, reason: 'cierre de ${ciclo.id}: $resultado');

    final snapshot = (resultado as Exito<SnapshotCiclo>).valor;
    final cerrado = cerrarCiclo(ciclo: ciclo, snapshot: snapshot);
    expect(cerrado.esExito, isTrue);
    await cicloRepositorio.guardar((cerrado as Exito<CicloGuardado>).valor);
  }

  test('tres ciclos capturados y cerrados de punta a punta no descuadran', () async {
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 1, 15),
      gastosVariables: const [('super', 300), ('super', 200)],
      conMovimientoAnulado: true,
    );
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 2, 15),
      gastosVariables: const [('super', 1000), ('super', 1500)],
      conMovimientoAnulado: false,
    );
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 3, 15),
      gastosVariables: const [('super', 700)],
      conMovimientoAnulado: true,
    );

    final ciclosGuardados = await cicloRepositorio.listarTodos();
    expect(ciclosGuardados, hasLength(3));
    expect(ciclosGuardados.every((g) => g.ciclo.estado == EstadoCiclo.cerrado), isTrue);

    final sumaSnapshots = Dinero.suma(ciclosGuardados.map((g) => g.snapshot!.totalGastado));

    final cicloIds = ciclosGuardados.map((g) => g.ciclo.id).toSet();
    final todosLosMovimientos = await movimientoRepositorio.listarTodos();
    final sumaMovimientosCrudos = Dinero.suma(
      todosLosMovimientos
          .where((m) => cicloIds.contains(m.cicloId) && m.estado == EstadoMovimiento.activo)
          .map((m) => m.monto),
    );

    expect(sumaSnapshots - sumaMovimientosCrudos, const Dinero.cero());
  });

  test('un cuarto ciclo con ingreso extra mixto cierra sin descuadre', () async {
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 1, 15),
      gastosVariables: const [('super', 300)],
      conMovimientoAnulado: false,
    );
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 2, 15),
      gastosVariables: const [('super', 1000)],
      conMovimientoAnulado: false,
    );
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 3, 15),
      gastosVariables: const [('super', 700)],
      conMovimientoAnulado: false,
    );
    await capturarYCerrarCiclo(
      fechaDentroDelCiclo: DateTime(2026, 4, 15),
      gastosVariables: const [('super', 500)],
      conMovimientoAnulado: false,
      extraApartadoPesos: 3000,
      extraGastoPesos: 1500,
    );

    final ciclosGuardados = await cicloRepositorio.listarTodos();
    expect(ciclosGuardados, hasLength(4));

    final cicloAbril = ciclosGuardados.firstWhere((g) => g.ciclo.id == '2026-04');
    final snapshotAbril = cicloAbril.snapshot!;
    expect(snapshotAbril.extraAApartado, const Dinero.pesos(3000));
    expect(snapshotAbril.extraAGasto, const Dinero.pesos(1500));
    // metaBase 6000 + extraAApartado 3000.
    expect(snapshotAbril.metaApartado, const Dinero.pesos(9000));
    // base 20000 + extraAApartado 3000 + extraAGasto 1500.
    expect(snapshotAbril.ingresoTotal, const Dinero.pesos(24500));
    expect(snapshotAbril.tuvoIngresoExtra, isTrue);

    final sumaSnapshots = Dinero.suma(ciclosGuardados.map((g) => g.snapshot!.totalGastado));
    final cicloIds = ciclosGuardados.map((g) => g.ciclo.id).toSet();
    final todosLosMovimientos = await movimientoRepositorio.listarTodos();
    final sumaMovimientosCrudos = Dinero.suma(
      todosLosMovimientos
          .where((m) => cicloIds.contains(m.cicloId) && m.estado == EstadoMovimiento.activo)
          .map((m) => m.monto),
    );
    expect(sumaSnapshots - sumaMovimientosCrudos, const Dinero.cero());
  });
}
