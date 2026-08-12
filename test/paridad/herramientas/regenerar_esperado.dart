// Imprime a stdout el JSON esperado de la prueba de paridad §3.2, calculado
// contra `test/paridad/datos/semilla_paridad_v1.json`. No es `*_test.dart`
// — `dart test` lo ignora — porque regenerar es un acto deliberado, no algo
// que corra solo. Uso:
//
//   dart run test/paridad/herramientas/regenerar_esperado.dart > salida.json
//
// Al congelar por primera vez (o tras un cambio real de lógica), revisar el
// diff a mano y verificar al menos tres cifras contra el cálculo esperado
// antes de copiar sobre valores_congelados_v1.json — copiar sin verificar
// congela el bug en vez de prevenirlo (Fase 6, Bloque 1.5).
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

Future<void> main() async {
  final raizSeed = File('test/paridad/datos/semilla_paridad_v1.json');
  final seed = jsonDecode(await raizSeed.readAsString()) as Map<String, dynamic>;

  final temp = await Directory.systemTemp.createTemp('app_finanzas_paridad_');
  try {
    final categoriaRepositorio =
        CategoriaRepositorioArchivo(File('${temp.path}/categorias.json'));
    final movimientoRepositorio =
        MovimientoRepositorioArchivo(File('${temp.path}/movimientos.json'));
    final ingresoExtraRepositorio =
        IngresoExtraRepositorioArchivo(File('${temp.path}/ingresos.json'));

    final perfil = Perfil.fromJson(seed['perfil'] as Map<String, dynamic>);
    for (final c in seed['categorias'] as List<dynamic>) {
      await categoriaRepositorio.guardar(Categoria.fromJson(c as Map<String, dynamic>));
    }
    for (final m in seed['movimientos'] as List<dynamic>) {
      await movimientoRepositorio
          .guardar(Movimiento.fromJson(m as Map<String, dynamic>));
    }
    for (final i in seed['ingresosExtra'] as List<dynamic>) {
      await ingresoExtraRepositorio
          .guardar(IngresoExtra.fromJson(i as Map<String, dynamic>));
    }

    final hoy = DateTime.parse(seed['hoy'] as String);
    final calculadora = CalculadoraCiclo(perfil.diaCorte);
    final ciclo = calculadora.calcularPara(hoy);
    if (ciclo.id != seed['cicloEvaluadoId']) {
      stderr.writeln(
        'ADVERTENCIA: cicloEvaluadoId de la semilla (${seed['cicloEvaluadoId']}) '
        'no coincide con el calculado (${ciclo.id}).',
      );
    }

    final categorias = await categoriaRepositorio.listarTodas();
    final todosLosMovimientos = await movimientoRepositorio.listarTodos();
    final movimientosDelCiclo = await movimientoRepositorio.listarPorCiclo(ciclo.id);
    final extrasDelCiclo = await ingresoExtraRepositorio.listarPorCiclo(ciclo.id);

    // 1. Cierre del ciclo — mismo camino que pantalla_cierre_ciclo.dart:94-113.
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
    final resultadoCierre = calcularSnapshotCierre(
      ciclo: ciclo,
      movimientos: movimientosDelCiclo,
      categorias: categorias,
      ingresos: ingresos,
      metaBase: metaBase,
      fechaCierre: hoy,
    );
    if (resultadoCierre is! Exito<SnapshotCiclo>) {
      stderr.writeln('Cierre de ciclo falló: $resultadoCierre');
      exitCode = 1;
      return;
    }
    final snapshot = resultadoCierre.valor;

    // 2. Cierre estimado del MPC y plan de ajuste, por categoría variable.
    final porCategoriaMpc = <String, dynamic>{};
    final porCategoriaPlan = <String, dynamic>{};
    for (final categoria in categorias.whereType<CategoriaVariable>()) {
      final pronostico = pronosticoDeCategoria(
        categoria: categoria,
        todos: todosLosMovimientos,
        ciclo: ciclo,
        hoy: hoy,
      );
      porCategoriaMpc[categoria.id] = {
        'p50': pronostico.pronosticoP50.centavos,
        'p10': pronostico.pronosticoP10.centavos,
        'p90': pronostico.pronosticoP90.centavos,
        'tipo': pronostico.tipo.name,
        'confianza': pronostico.confianza.name,
        'nivelMadurez': pronostico.nivelMadurez.name,
      };

      final plan = calcularPlanDeAjuste(
        categoria: categoria,
        pronostico: pronostico,
        ciclosCerradosRecienteAAntiguo: ciclosCerradosDeCategoria(
          todos: todosLosMovimientos,
          categoriaId: categoria.id,
          cicloActualId: ciclo.id,
        ),
        fechaInicioCiclo: ciclo.fechaInicio,
        fechaFinCiclo: ciclo.fechaFin,
        hoy: hoy,
      );
      porCategoriaPlan[categoria.id] = plan == null
          ? null
          : {
              'disponibleCentavos': plan.disponible.centavos,
              'sugeridoPromedioPorDiaCentavos': plan.sugeridoPromedioPorDia.centavos,
              'diasRestantes': plan.diasRestantes,
              'piezaCuantoQueda': plan.piezaCuantoQueda,
              'piezaContraCostumbre': plan.piezaContraCostumbre,
              'piezaNumeroASeguir': plan.piezaNumeroASeguir,
            };
    }

    // 3. Lista de gastos — mismo camino que pantalla_gastos.dart:224-225.
    final filtrados = movimientosDelCiclo
        .where((m) => m.estado == EstadoMovimiento.activo)
        .toList();
    final totalListaGastos = Dinero.suma(filtrados.map((m) => m.monto));

    final salida = {
      'cicloEvaluado': ciclo.id,
      'cierreDelCiclo': {
        'ingresoTotalCentavos': snapshot.ingresoTotal.centavos,
        'metaApartadoCentavos': snapshot.metaApartado.centavos,
        'totalGastadoCentavos': snapshot.totalGastado.centavos,
        'renglones': [
          for (final r in snapshot.renglones)
            {
              'categoriaId': r.categoriaId,
              'realCentavos': r.realCentavos.centavos,
              'presupuestoCentavos': r.presupuestoCentavos.centavos,
              'conteo': r.conteoMovimientos,
            },
        ],
      },
      'cierreEstimadoMpc': {'porCategoria': porCategoriaMpc},
      'planDeAjuste': {'porCategoria': porCategoriaPlan},
      'listaDeGastos': {
        'conteo': filtrados.length,
        'totalCentavos': totalListaGastos.centavos,
        'totalFormateado': totalListaGastos.formateado(),
      },
      'formatos': {
        '123456': const Dinero(123456).formateado(),
        '-99': const Dinero(-99).formateado(),
        '0': const Dinero(0).formateado(),
        '100000000': const Dinero(100000000).formateado(),
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    // El propósito de este script es imprimir a stdout (ver docstring).
    // ignore: avoid_print
    print(encoder.convert(salida));
  } finally {
    if (await temp.exists()) await temp.delete(recursive: true);
  }
}
