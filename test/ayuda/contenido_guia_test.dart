// Valida el contenido de la guía por temas sin necesitar `flutter_test`:
// `modelo_guia.dart` y `contenido_guia.dart` son Dart puro a propósito
// (ver docstring de ambos), así que esta prueba corre con `dart test` en
// vez de vivir en `test/ui/`. Agregada a `paths:` en `dart_test.yaml`.
import 'dart:io';

import 'package:app_finanzas/ui/ayuda/contenido_guia.dart';
import 'package:app_finanzas/ui/ayuda/modelo_guia.dart';
import 'package:test/test.dart';

const _idsEsperados = {
  'ritmo',
  'inicio',
  'registrar-gasto',
  'voz-y-tickets',
  'movimientos',
  'categorias',
  'salirse-de-control',
  'ingresos-y-meta',
  'ciclos',
  'tus-datos',
};

// Cadenas que la guía cita literal de otras pantallas — si una de estas
// desaparece de lib/ui/, la guía se queda hablando de algo que ya no
// existe (el único riesgo estructural de este enfoque).
const _citasLiteralesDeLaApp = [
  'Gastos Variables',
  'Buscar gasto o comercio',
  'Cierre estimado',
  'Mover presupuesto',
  'Sugerida por tus gastos anteriores',
];

const _vocabularioProhibido = [
  'Variación',
  '% del presupuesto',
  'Avance efectivo',
  'registrado con éxito',
];

String _textoPlanoDeBloque(BloqueGuia b) => switch (b) {
  Parrafo(:final texto) => texto,
  Subtitulo(:final texto) => texto,
  Vinetas(:final puntos) => puntos.join(' '),
  Pasos(:final pasos) => pasos.join(' '),
  Nota(:final etiqueta, :final texto) => '$etiqueta $texto',
  Ejemplo(:final pie) => pie ?? '',
};

void main() {
  test('cada sección tiene al menos un tema', () {
    for (final seccion in guiaDeLaApp) {
      expect(seccion.temas, isNotEmpty, reason: 'Sección "${seccion.titulo}" vacía');
    }
  });

  test('los ids de tema no están vacíos y son únicos', () {
    final ids = [for (final s in guiaDeLaApp) for (final t in s.temas) t.id];
    expect(ids.every((id) => id.isNotEmpty), isTrue);
    expect(ids.toSet().length, ids.length, reason: 'Hay ids de tema repetidos: $ids');
  });

  test('titulo, resumen y emoji no están vacíos en ningún tema', () {
    for (final tema in temasEnOrden) {
      expect(tema.titulo, isNotEmpty, reason: tema.id);
      expect(tema.resumen, isNotEmpty, reason: tema.id);
      expect(tema.emoji, isNotEmpty, reason: tema.id);
    }
  });

  test('ningún tema tiene la lista de bloques vacía', () {
    for (final tema in temasEnOrden) {
      expect(tema.bloques, isNotEmpty, reason: tema.id);
    }
  });

  test('cada bloque trae contenido válido según su tipo', () {
    for (final tema in temasEnOrden) {
      for (final bloque in tema.bloques) {
        switch (bloque) {
          case Parrafo(:final texto):
            expect(texto, isNotEmpty, reason: '${tema.id}: Parrafo vacío');
          case Subtitulo(:final texto):
            expect(texto, isNotEmpty, reason: '${tema.id}: Subtitulo vacío');
          case Vinetas(:final puntos):
            expect(puntos.length, greaterThanOrEqualTo(2), reason: '${tema.id}: Vinetas');
            expect(puntos.every((p) => p.isNotEmpty), isTrue, reason: '${tema.id}: Vinetas con punto vacío');
          case Pasos(:final pasos):
            expect(pasos.length, greaterThanOrEqualTo(2), reason: '${tema.id}: Pasos');
            expect(pasos.every((p) => p.isNotEmpty), isTrue, reason: '${tema.id}: Pasos con paso vacío');
          case Nota(:final etiqueta, :final texto):
            expect(etiqueta, isNotEmpty, reason: '${tema.id}: Nota sin etiqueta');
            expect(texto, isNotEmpty, reason: '${tema.id}: Nota sin texto');
          case Ejemplo():
            break;
        }
      }
    }
  });

  test('cobertura congelada: los 10 temas siguen todos presentes', () {
    final ids = temasEnOrden.map((t) => t.id).toSet();
    expect(ids, containsAll(_idsEsperados));
    expect(ids.length, _idsEsperados.length);
  });

  test('el vocabulario prohibido por addendum-v3 §3.3 no aparece en la guía', () {
    final textoCompleto = [
      for (final tema in temasEnOrden) ...[
        tema.titulo,
        tema.resumen,
        for (final bloque in tema.bloques) _textoPlanoDeBloque(bloque),
      ],
    ].join(' ');
    for (final prohibida in _vocabularioProhibido) {
      expect(textoCompleto, isNot(contains(prohibida)));
    }
  });

  test('cada EjemploGuia se usa al menos una vez (sin ejemplos huérfanos)', () {
    final usados = <EjemploGuia>{
      for (final tema in temasEnOrden)
        for (final bloque in tema.bloques)
          if (bloque case Ejemplo(:final cual)) cual,
    };
    expect(usados, EjemploGuia.values.toSet());
  });

  test('las cadenas que la guía cita literal siguen existiendo en lib/ui/', () {
    final raiz = Directory.current;
    final carpetaUi = Directory('${raiz.path}/lib/ui');
    final contenidoCompleto = carpetaUi
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    for (final cita in _citasLiteralesDeLaApp) {
      expect(
        contenidoCompleto,
        contains(cita),
        reason: 'La guía cita "$cita" pero ya no aparece en lib/ui/ — actualiza el tema correspondiente.',
      );
    }
  });
}
