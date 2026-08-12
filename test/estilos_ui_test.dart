// Guardia barata contra la erosión del TextTheme centralizado (Fase 6,
// Bloque 3): lib/ui/comun/tema.dart define 5 ranuras (displaySmall,
// headlineMedium, titleMedium, bodySmall, labelSmall) para lo que antes
// eran `fontSize:` sueltos repartidos por lib/ui/. Sin esta prueba, nada
// impide que un `fontSize:` nuevo se cuele en vez de usar
// `Theme.of(context).textTheme.*` — con esta prueba, cualquier archivo que
// suba su conteo por encima de lo ya auditado rompe `dart test` de
// inmediato.
//
// El mapa de abajo es la lista de excepciones explícita que pide el plan:
// cada entrada es un `fontSize:` que **no** migró a una ranura del tema
// porque su tamaño, peso o color no calzan exactamente con ninguna de las
// 5 (tamaños de emoji, textos con color dinámico según estado, texto
// blanco sobre fondo oscuro con tono secundario, etc. — forzarlos a una
// ranura habría cambiado cómo se ven). `tema.dart` es la excepción
// esperada más alta: ahí es donde las 5 ranuras se declaran.
import 'dart:io';

import 'package:test/test.dart';

const _maximoPorArchivo = {
  'lib/ui/ajustes/pantalla_ajustes.dart': 2,
  'lib/ui/captura/hoja_dictado.dart': 3,
  'lib/ui/captura/pantalla_captura.dart': 4,
  'lib/ui/captura/pantalla_dividir_ticket.dart': 2,
  'lib/ui/captura/pantalla_revision_dictado.dart': 3,
  'lib/ui/categorias/pantalla_categorias.dart': 2,
  'lib/ui/categorias/pantalla_detalle_categoria.dart': 7,
  'lib/ui/categorias/pantalla_mover_presupuesto.dart': 2,
  'lib/ui/ciclo/pantalla_ciclos_anteriores.dart': 6,
  'lib/ui/ciclo/pantalla_cierre_ciclo.dart': 3,
  'lib/ui/comun/grafica_evolucion.dart': 4,
  'lib/ui/comun/pantalla_login.dart': 1,
  'lib/ui/comun/tema.dart': 8,
  'lib/ui/gastos/pantalla_gastos.dart': 2,
  'lib/ui/inicio/pantalla_inicio.dart': 4,
};

void main() {
  final raiz = Directory.current;
  final carpetaUi = Directory('${raiz.path}/lib/ui');

  final archivos = carpetaUi
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final archivo in archivos) {
    final rutaRelativa =
        archivo.path.substring(raiz.path.length + 1).replaceAll(r'\', '/');
    final maximo = _maximoPorArchivo[rutaRelativa] ?? 0;

    test('$rutaRelativa no tiene más fontSize: sueltos de los auditados ($maximo)', () {
      final conteo = 'fontSize:'.allMatches(archivo.readAsStringSync()).length;
      expect(
        conteo,
        lessThanOrEqualTo(maximo),
        reason: rutaRelativa == 'lib/ui/comun/tema.dart'
            ? '$rutaRelativa: subió el número de ranuras del TextTheme central. '
                'Si es intencional, actualiza el máximo de esta prueba.'
            : '$rutaRelativa: un fontSize: nuevo que no está en Theme.of(context).textTheme.* '
                '— usa una ranura existente o, si de verdad no calza en ninguna, súbela '
                'a $rutaRelativa Y sube el máximo en test/estilos_ui_test.dart a propósito.',
      );
    });
  }
}
