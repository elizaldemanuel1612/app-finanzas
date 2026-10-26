import 'package:app_finanzas/domain/sincronizacion/fusion.dart';
import 'package:test/test.dart';

String _id(Map<String, dynamic> m) => m['id'] as String;

Map<String, dynamic> _r(String id, [String valor = 'x', String estado = 'activo']) =>
    {'id': id, 'valor': valor, 'estado': estado};

ResultadoFusion _fusionar(
  List<Map<String, dynamic>> local,
  List<Map<String, dynamic>> nube, {
  ModoFusion modo = ModoFusion.combinar,
  Set<String>? base,
  bool anular = false,
}) =>
    fusionarColeccion(
      local: local,
      nube: {for (final m in nube) _id(m): m},
      clave: _id,
      modo: modo,
      base: base,
      anularEnVezDeBorrar: anular,
    );

void main() {
  group('combinar, primera vez (sin base)', () {
    test('une ambos lados y sube solo lo que falta o difiere', () {
      final r = _fusionar([_r('a'), _r('b', 'mio')], [_r('b', 'suyo'), _r('c')]);
      expect(r.local.map(_id), ['a', 'b', 'c']);
      expect(r.local[1]['valor'], 'mio', reason: 'gana el dispositivo');
      expect(r.subir.keys, unorderedEquals(['a', 'b']));
      expect(r.borrarEnNube, isEmpty);
      expect(r.base, {'a', 'b', 'c'});
      expect(r.hayCambiosEnNube, isTrue);
    });

    test('anulado gana sin importar el lado', () {
      final r = _fusionar([_r('a', 'x')], [_r('a', 'x', 'anulado')]);
      expect(r.local.single['estado'], 'anulado');
      expect(r.subir, isEmpty);
      final r2 = _fusionar([_r('a', 'x', 'anulado')], [_r('a', 'y')]);
      expect(r2.subir['a']!['estado'], 'anulado');
    });

    test('un ciclo cerrado gana sobre uno abierto', () {
      final r = _fusionar([_r('c', 'x', 'abierto')], [_r('c', 'y', 'cerrado')]);
      expect(r.local.single['estado'], 'cerrado');
      final r2 = _fusionar([_r('c', 'x', 'cerrado')], [_r('c', 'y', 'abierto')]);
      expect(r2.subir['c']!['estado'], 'cerrado');
    });

    test('igualdad por contenido, sin importar el orden de las llaves', () {
      final r = _fusionar([{'id': 'a', 'n': 1, 'm': {'y': 2, 'x': 1}, 'l': [1]}],
          [{'l': [1], 'm': {'x': 1, 'y': 2}, 'n': 1, 'id': 'a'}]);
      expect(r.hayCambiosEnNube, isFalse);
    });
  });

  group('combinar con base (tres vías)', () {
    test('lo borrado aquí se borra de la nube; lo borrado allá, de aquí', () {
      final r = _fusionar([_r('a'), _r('nuevo')], [_r('b'), _r('c')], base: {'a', 'b'});
      // 'a' estaba y la nube ya no lo tiene → se borró en otro dispositivo.
      // 'b' estaba y aquí ya no → se borró aquí → se borra de la nube.
      expect(r.local.map(_id), ['nuevo', 'c']);
      expect(r.borrarEnNube, {'b'});
      expect(r.subir.keys, ['nuevo']);
      expect(r.base, {'nuevo', 'c'});
    });

    test('con anular (movimientos) nada se pierde por un lado faltante', () {
      final r = _fusionar([_r('a')], [_r('b')], base: {'a', 'b'}, anular: true);
      expect(r.local.map(_id), unorderedEquals(['a', 'b']));
      expect(r.borrarEnNube, isEmpty);
      expect(r.subir.keys, ['a']);
    });
  });

  test('usar la nube: el dispositivo queda igual que la nube', () {
    final r = _fusionar([_r('a')], [_r('b')], modo: ModoFusion.usarNube);
    expect(r.local.map(_id), ['b']);
    expect(r.hayCambiosEnNube, isFalse);
    expect(r.base, {'b'});
  });

  group('usar el dispositivo', () {
    test('la nube queda igual: sube lo distinto y borra lo que sobra', () {
      final r = _fusionar([_r('a'), _r('b', 'igual')], [_r('b', 'igual'), _r('c')], modo: ModoFusion.usarDispositivo);
      expect(r.local.map(_id), ['a', 'b']);
      expect(r.subir.keys, ['a']);
      expect(r.borrarEnNube, {'c'});
      expect(r.base, {'a', 'b'});
    });

    test('movimientos: lo que sobra en la nube se anula, no se borra', () {
      final r = _fusionar([_r('a')], [_r('c'), _r('d', 'x', 'anulado')],
          modo: ModoFusion.usarDispositivo, anular: true);
      expect(r.borrarEnNube, isEmpty);
      expect(r.subir['c']!['estado'], 'anulado');
      expect(r.subir.containsKey('d'), isFalse, reason: 'ya estaba anulado');
      expect(r.base, {'a', 'c', 'd'});
    });
  });

  test('claves por archivo', () {
    expect(claveDeArchivo('categorias.json')!({'id': 'c1'}), 'c1');
    expect(claveDeArchivo('ciclos.json')!({'id': '2026-10'}), '2026-10');
    expect(claveDeArchivo('ingresos.json')!({'id': 'i1'}), 'i1');
    expect(claveDeArchivo('movimientos.json')!({'clientId': 'm1'}), 'm1');
    expect(claveDeArchivo('reglas_aprendidas.json')!({'patron': 'oxxo'}), 'oxxo');
    expect(
      claveDeArchivo('ajustes_presupuesto_ciclo.json')!({'cicloId': 'c', 'categoriaId': 'k', 'cuando': 't'}),
      'c|k|t',
    );
    expect(claveDeArchivo('perfil.json')!({}), 'perfil');
    expect(claveDeArchivo('otro.json'), isNull);
  });
}
