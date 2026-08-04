import 'dart:io';

import 'package:app_finanzas/data/almacenamiento/almacen_fotos.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('app_finanzas_test_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('copia la foto a <documentos>/tickets/ y regresa la ruta final', () async {
    final origen = File('${temp.path}/original.jpg')..writeAsBytesSync([1, 2, 3]);
    final documentos = Directory('${temp.path}/documentos')..createSync();

    final ruta = await guardarFotoTicket(origen, documentos: documentos);

    expect(ruta, startsWith('${documentos.path}/tickets/'));
    expect(ruta, endsWith('.jpg'));
    expect(await File(ruta).exists(), isTrue);
    expect(await File(ruta).readAsBytes(), [1, 2, 3]);
  });

  test('no borra ni mueve el archivo original', () async {
    final origen = File('${temp.path}/original.png')..writeAsBytesSync([9, 9]);
    final documentos = Directory('${temp.path}/documentos')..createSync();

    await guardarFotoTicket(origen, documentos: documentos);

    expect(await origen.exists(), isTrue);
  });

  test('crea la carpeta tickets si no existe', () async {
    final origen = File('${temp.path}/original.jpg')..writeAsBytesSync([1]);
    final documentos = Directory('${temp.path}/documentos_nuevo');

    await guardarFotoTicket(origen, documentos: documentos);

    expect(await Directory('${documentos.path}/tickets').exists(), isTrue);
  });

  test('dos fotos guardadas obtienen rutas distintas', () async {
    final origen = File('${temp.path}/original.jpg')..writeAsBytesSync([1]);
    final documentos = Directory('${temp.path}/documentos')..createSync();

    final ruta1 = await guardarFotoTicket(origen, documentos: documentos);
    final ruta2 = await guardarFotoTicket(origen, documentos: documentos);

    expect(ruta1, isNot(ruta2));
  });
}
