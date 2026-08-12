import 'dart:convert';
import 'dart:io';

import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/gastos/pantalla_gastos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Cierra el hueco de "el dominio calcula bien, la pantalla muestra otra
// cosa" (Fase 6, Bloque 1.6): monta PantallaGastos con la misma semilla que
// test/paridad/paridad_3_2_test.dart y compara las cadenas en pantalla
// contra los mismos valores congelados.
//
// Repositorios en memoria, no los de archivo (`data/repositorios/local/`):
// el binding de `flutter_test` corre en una zona de tiempo simulado que no
// deja avanzar E/S real de `dart:io` por sí sola — con los repositorios de
// archivo, `pumpWidget` se queda esperando el `File.readAsString()` de
// `_cargar()` para siempre y `pump`/`pumpAndSettle` nunca ven el dato
// llegar (probado: agota el timeout de 10 minutos incluso con
// `tester.runAsync`). Un `Future.value(...)` en memoria se resuelve como
// microtarea, que `pump()` sí procesa. La semilla ya se prueba pasando por
// disco de verdad en `test/paridad/paridad_3_2_test.dart` — aquí solo hace
// falta que la pantalla pinte lo que el dominio calculó.
//
// Solo PantallaGastos entra aquí: recibe `cicloId` explícito por
// constructor, así que es determinista sin importar el reloj real de la
// máquina que corre la prueba. PantallaInicio no — calcula su ciclo con
// `CalculadoraCiclo(...).calcularPara(DateTime.now())` dentro de
// `initState` (lib/ui/inicio/pantalla_inicio.dart:64-66), sin forma de
// inyectar "hoy" desde afuera (a diferencia de `calcularRollups`, que sí
// acepta `ahora`). Pinearla a una semilla de fecha fija se rompería solo en
// el día en que el reloj real saliera del ciclo `2026-07` de la semilla —
// una prueba que pasa hoy y falla sola en el futuro es peor que no
// tenerla. Documentado también en docs/paridad-3-2-procedimiento.md.

void main() {
  testWidgets('PantallaGastos muestra el mismo conteo y total que domain/', (tester) async {
    // Los dos File.readAsString() son E/S real de dart:io — necesitan la
    // ventana de tiempo real de runAsync() para resolver dentro de la zona
    // simulada de testWidgets. Todo lo demás (los repositorios en
    // memoria) resuelve por microtareas, que pump() sí procesa sin ayuda.
    late Map<String, dynamic> seed;
    late Map<String, dynamic> esperado;
    await tester.runAsync(() async {
      seed = jsonDecode(
        await File('test/paridad/datos/semilla_paridad_v1.json').readAsString(),
      ) as Map<String, dynamic>;
      esperado = jsonDecode(
        await File('test/paridad/esperado/valores_congelados_v1.json').readAsString(),
      ) as Map<String, dynamic>;
    });

    final perfil = Perfil.fromJson(seed['perfil'] as Map<String, dynamic>);
    final categorias = [
      for (final c in seed['categorias'] as List<dynamic>)
        Categoria.fromJson(c as Map<String, dynamic>),
    ];
    // Igual que MovimientoRepositorioArchivo.guardar(): un movimiento sin
    // id recibe id = clientId. Sin esto, todos los Dismissible de la
    // lista comparten ValueKey(null) y Flutter revienta con "Duplicate
    // keys found" al construir la columna del día.
    final movimientos = [
      for (final m in seed['movimientos'] as List<dynamic>)
        conId(Movimiento.fromJson(m as Map<String, dynamic>)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaGastos(
          cicloId: seed['cicloEvaluadoId'] as String,
          perfil: perfil,
          categoriaRepositorio: CategoriaRepositorioMemoria(categorias),
          movimientoRepositorio: MovimientoRepositorioMemoria(movimientos),
          reglasAprendidasRepositorio: ReglasAprendidasRepositorioMemoria(),
          cicloRepositorio: CicloRepositorioMemoria(),
          documentos: Directory.systemTemp,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El resumen "N movimiento(s) · $total" solo se muestra con un filtro
    // activo (pantalla_gastos.dart:192,218) — "e" aparece en la
    // descripción o categoría de los 7 movimientos activos del ciclo
    // sembrado, así que filtra sin excluir a ninguno.
    //
    // pump() puntual, no pumpAndSettle(): el cursor parpadeante del
    // TextField enfocado es una animación infinita por diseño, así que
    // pumpAndSettle() nunca terminaría de "asentarse".
    await tester.enterText(find.byType(TextField), 'e');
    await tester.pump();

    final esperadoLista = esperado['listaDeGastos'] as Map<String, dynamic>;
    final conteo = esperadoLista['conteo'] as int;
    final totalFormateado = esperadoLista['totalFormateado'] as String;

    expect(
      find.textContaining('$conteo movimiento(s) · $totalFormateado'),
      findsOneWidget,
      reason: 'PantallaGastos debe mostrar exactamente el conteo y total congelados',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
