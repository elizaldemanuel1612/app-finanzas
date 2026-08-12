import 'dart:convert';
import 'dart:io';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/data/repositorios/local/categoria_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/ingreso_extra_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_repositorio_archivo.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/cierre_ciclo.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/ingresos_ciclo.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:app_finanzas/domain/presupuesto/plan_de_ajuste.dart';
import 'package:app_finanzas/domain/presupuesto/reparto.dart';
import 'package:app_finanzas/domain/pronostico/historico_desde_movimientos.dart';
import 'package:test/test.dart';

// Reformulación ejecutable del criterio de aceptación de la Fase 6
// (paquete-construccion-final.md §3.2): "una prueba de paridad automatizada
// que compara, con la misma semilla de datos, los resultados en iOS y
// Android". Todo lo que puede divergir entre binarios vive en domain/, que
// es Dart puro y determinista — si esas cifras están congeladas contra un
// juego de datos versionado, el binario puede cambiar, el cálculo no.
//
// Sustitución documentada (docs/paridad-3-2-procedimiento.md): sin Mac ni
// cuenta Apple Developer, esta prueba congela lo que domain/ produce en
// cualquier plataforma que corra Dart — que es lo mismo que corre dentro
// del binario de iOS o de Android. La comparación real dispositivo-contra-
// dispositivo queda como paso manual (Android-vs-Android) descrito en ese
// documento.

void main() {
  late Directory temp;
  late Map<String, dynamic> seed;
  late Map<String, dynamic> esperado;
  late CategoriaRepositorioArchivo categoriaRepositorio;
  late MovimientoRepositorioArchivo movimientoRepositorio;
  late IngresoExtraRepositorioArchivo ingresoExtraRepositorio;
  late Perfil perfil;
  late Ciclo ciclo;

  setUpAll(() async {
    seed = jsonDecode(
      await File('test/paridad/datos/semilla_paridad_v1.json').readAsString(),
    ) as Map<String, dynamic>;
    esperado = jsonDecode(
      await File('test/paridad/esperado/valores_congelados_v1.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_paridad_test_');
    categoriaRepositorio = CategoriaRepositorioArchivo(File('${temp.path}/categorias.json'));
    movimientoRepositorio = MovimientoRepositorioArchivo(File('${temp.path}/movimientos.json'));
    ingresoExtraRepositorio =
        IngresoExtraRepositorioArchivo(File('${temp.path}/ingresos.json'));

    perfil = Perfil.fromJson(seed['perfil'] as Map<String, dynamic>);
    for (final c in seed['categorias'] as List<dynamic>) {
      await categoriaRepositorio.guardar(Categoria.fromJson(c as Map<String, dynamic>));
    }
    // La semilla pasa por disco exactamente como en producción: cada
    // guardar() de aquí abajo escribe y relee el JSON vía AlmacenJsonLista,
    // no construye objetos en memoria a mano.
    for (final m in seed['movimientos'] as List<dynamic>) {
      await movimientoRepositorio.guardar(Movimiento.fromJson(m as Map<String, dynamic>));
    }
    for (final i in seed['ingresosExtra'] as List<dynamic>) {
      await ingresoExtraRepositorio.guardar(IngresoExtra.fromJson(i as Map<String, dynamic>));
    }

    final hoy = DateTime.parse(seed['hoy'] as String);
    ciclo = CalculadoraCiclo(perfil.diaCorte).calcularPara(hoy);
    expect(ciclo.id, seed['cicloEvaluadoId'], reason: 'la semilla asume este cicloId');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  DateTime hoy() => DateTime.parse(seed['hoy'] as String);

  test('1. cierre del ciclo cuadra contra los valores congelados', () async {
    final categorias = await categoriaRepositorio.listarTodas();
    final movimientosDelCiclo = await movimientoRepositorio.listarPorCiclo(ciclo.id);
    final extrasDelCiclo = await ingresoExtraRepositorio.listarPorCiclo(ciclo.id);

    final reparto = calcularReparto(
      ingresoDisponible: perfil.ingresoBaseMensual,
      fijas: categorias.whereType<CategoriaFija>().toList(),
      variables: categorias.whereType<CategoriaVariable>().toList(),
    );
    final metaBase =
        reparto is Exito<ResultadoReparto> ? reparto.valor.sinAsignar : const Dinero.cero();
    final ingresos = calcularIngresosDelCiclo(
      ingresoBase: perfil.ingresoBaseMensual,
      cicloId: ciclo.id,
      extras: extrasDelCiclo,
    );
    final resultado = calcularSnapshotCierre(
      ciclo: ciclo,
      movimientos: movimientosDelCiclo,
      categorias: categorias,
      ingresos: ingresos,
      metaBase: metaBase,
      fechaCierre: hoy(),
    );
    expect(resultado.esExito, isTrue, reason: '$resultado');
    final snapshot = (resultado as Exito<SnapshotCiclo>).valor;

    final esperadoCierre = esperado['cierreDelCiclo'] as Map<String, dynamic>;
    expect(snapshot.ingresoTotal.centavos, esperadoCierre['ingresoTotalCentavos']);
    expect(snapshot.metaApartado.centavos, esperadoCierre['metaApartadoCentavos']);
    expect(snapshot.totalGastado.centavos, esperadoCierre['totalGastadoCentavos']);

    final renglonesEsperados = esperadoCierre['renglones'] as List<dynamic>;
    expect(snapshot.renglones, hasLength(renglonesEsperados.length));
    for (final r in renglonesEsperados) {
      final renglon = snapshot.renglones.firstWhere((x) => x.categoriaId == r['categoriaId']);
      expect(renglon.realCentavos.centavos, r['realCentavos'], reason: renglon.categoriaId);
      expect(renglon.presupuestoCentavos.centavos, r['presupuestoCentavos'],
          reason: renglon.categoriaId);
      expect(renglon.conteoMovimientos, r['conteo'], reason: renglon.categoriaId);
    }
  });

  test('2. cierre estimado del MPC y plan de ajuste cuadran, texto incluido', () async {
    final categorias = await categoriaRepositorio.listarTodas();
    final todos = await movimientoRepositorio.listarTodos();

    final esperadoMpc =
        (esperado['cierreEstimadoMpc'] as Map<String, dynamic>)['porCategoria']
            as Map<String, dynamic>;
    final esperadoPlan =
        (esperado['planDeAjuste'] as Map<String, dynamic>)['porCategoria']
            as Map<String, dynamic>;

    for (final categoria in categorias.whereType<CategoriaVariable>()) {
      final pronostico = pronosticoDeCategoria(
        categoria: categoria,
        todos: todos,
        ciclo: ciclo,
        hoy: hoy(),
      );
      final mpcEsperado = esperadoMpc[categoria.id] as Map<String, dynamic>;
      expect(pronostico.pronosticoP50.centavos, mpcEsperado['p50'], reason: categoria.id);
      expect(pronostico.pronosticoP10.centavos, mpcEsperado['p10'], reason: categoria.id);
      expect(pronostico.pronosticoP90.centavos, mpcEsperado['p90'], reason: categoria.id);
      expect(pronostico.tipo.name, mpcEsperado['tipo'], reason: categoria.id);
      expect(pronostico.confianza.name, mpcEsperado['confianza'], reason: categoria.id);
      expect(pronostico.nivelMadurez.name, mpcEsperado['nivelMadurez'], reason: categoria.id);

      final plan = calcularPlanDeAjuste(
        categoria: categoria,
        pronostico: pronostico,
        ciclosCerradosRecienteAAntiguo: ciclosCerradosDeCategoria(
          todos: todos,
          categoriaId: categoria.id,
          cicloActualId: ciclo.id,
        ),
        fechaInicioCiclo: ciclo.fechaInicio,
        fechaFinCiclo: ciclo.fechaFin,
        hoy: hoy(),
      );
      final planEsperado = esperadoPlan[categoria.id];

      if (planEsperado == null) {
        expect(plan, isNull, reason: '${categoria.id}: se congeló que el plan no se dispara');
        continue;
      }
      expect(plan, isNotNull, reason: '${categoria.id}: se congeló que el plan SÍ se dispara');
      expect(plan!.disponible.centavos, planEsperado['disponibleCentavos'], reason: categoria.id);
      expect(plan.sugeridoPromedioPorDia.centavos, planEsperado['sugeridoPromedioPorDiaCentavos'],
          reason: categoria.id);
      expect(plan.diasRestantes, planEsperado['diasRestantes'], reason: categoria.id);
      // §3.1: "lo que nunca cambia son las cifras, los textos y la lógica"
      // — las tres piezas se congelan igual que el monto.
      expect(plan.piezaCuantoQueda, planEsperado['piezaCuantoQueda'], reason: categoria.id);
      expect(plan.piezaContraCostumbre, planEsperado['piezaContraCostumbre'],
          reason: categoria.id);
      expect(plan.piezaNumeroASeguir, planEsperado['piezaNumeroASeguir'], reason: categoria.id);
    }
  });

  test('3. lista de gastos: conteo y total cuadran contra los congelados', () async {
    // Mismo camino que pantalla_gastos.dart:224-225 — listarPorCiclo +
    // filtro por activo, sin ningún filtro adicional de UI.
    final movimientosDelCiclo = await movimientoRepositorio.listarPorCiclo(ciclo.id);
    final filtrados =
        movimientosDelCiclo.where((m) => m.estado == EstadoMovimiento.activo).toList();
    final total = Dinero.suma(filtrados.map((m) => m.monto));

    final esperadoLista = esperado['listaDeGastos'] as Map<String, dynamic>;
    expect(filtrados.length, esperadoLista['conteo']);
    expect(total.centavos, esperadoLista['totalCentavos']);
    expect(total.formateado(), esperadoLista['totalFormateado']);
  });

  test('4. Dinero.formateado() produce los mismos textos que la tabla congelada', () {
    final esperadoFormatos = esperado['formatos'] as Map<String, dynamic>;
    for (final entry in esperadoFormatos.entries) {
      final centavos = int.parse(entry.key);
      expect(Dinero(centavos).formateado(), entry.value, reason: entry.key);
    }
  });

  test(
    '5. un Movimiento serializado y reparseado conserva su cicloId en cualquier huso — '
    'la paridad depende de que fecha nunca se construya en UTC (divergencia deliberada '
    'frente al §3, ver docs/paridad-3-2-procedimiento.md)',
    () async {
      final original = (await movimientoRepositorio.listarTodos())
          .firstWhere((m) => m.clientId == 'super-2026-07-a');
      final reconstruido = Movimiento.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      // toJson() usa toIso8601String() sobre un DateTime local: sin sufijo
      // "Z", así que DateTime.parse reconstruye el mismo reloj de pared sin
      // importar en qué huso horario corra la máquina que lo lea.
      expect(original.fecha.toIso8601String().endsWith('Z'), isFalse);
      expect(reconstruido.fecha, original.fecha);
      expect(reconstruido.fecha.isUtc, isFalse);

      final calculadora = CalculadoraCiclo(perfil.diaCorte);
      expect(calculadora.calcularPara(reconstruido.fecha).id, original.cicloId);
      expect(calculadora.calcularPara(reconstruido.fecha).id, ciclo.id);
    },
  );
}
