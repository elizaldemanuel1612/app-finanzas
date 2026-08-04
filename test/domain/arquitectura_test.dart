// Guarda automatizada de la "regla dura de arquitectura" (paquete-
// construccion-final.md §2): domain/ y core/ no pueden importar Flutter,
// Firebase, ni nada de las capas data/ ui/ plataforma/. Sin esta prueba, la
// regla depende de que cada quien se acuerde de respetarla — con esta
// prueba, cualquier import prohibido rompe `dart test` de inmediato.
import 'dart:io';

import 'package:test/test.dart';

const _prefijosProhibidos = [
  'package:flutter/',
  'package:flutter_test/',
  'package:cloud_firestore/',
  'package:firebase_',
  'package:app_finanzas/ui/',
  'package:app_finanzas/data/',
  'package:app_finanzas/plataforma/',
];

const _fragmentosRelativosProhibidos = [
  '/ui/',
  '/data/',
  '/plataforma/',
];

final _importRegExp = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

void main() {
  final raiz = Directory.current;
  final carpetasPuras = [
    Directory('${raiz.path}/lib/domain'),
    Directory('${raiz.path}/lib/core'),
  ];

  for (final carpeta in carpetasPuras) {
    if (!carpeta.existsSync()) {
      test('${carpeta.path} existe', () => fail('No se encontró ${carpeta.path}'));
      continue;
    }

    final archivos = carpeta
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final archivo in archivos) {
      final nombreCorto = archivo.path.substring(raiz.path.length + 1);

      test('$nombreCorto no importa Flutter, Firebase ni ui/data/plataforma', () {
        final lineas = archivo.readAsLinesSync();
        for (final linea in lineas) {
          final match = _importRegExp.firstMatch(linea);
          if (match == null) continue;
          final uri = match.group(1)!;

          for (final prohibido in _prefijosProhibidos) {
            expect(
              uri.startsWith(prohibido),
              isFalse,
              reason: '$nombreCorto importa "$uri", prohibido en domain/core.',
            );
          }

          if (uri.startsWith('.')) {
            for (final fragmento in _fragmentosRelativosProhibidos) {
              expect(
                uri.contains(fragmento),
                isFalse,
                reason: '$nombreCorto importa "$uri", que sale de domain/core.',
              );
            }
          }
        }
      });
    }
  }

  test('la carpeta lib/domain existe y tiene al menos un archivo .dart', () {
    final domain = Directory('${raiz.path}/lib/domain');
    final tieneArchivos = domain
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.endsWith('.dart'));
    expect(tieneArchivos, isTrue);
  });
}
