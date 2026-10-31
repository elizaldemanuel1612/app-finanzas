import 'dart:convert';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/nube/respaldo_remoto.dart';
import 'package:app_finanzas/data/nube/servicio_nube.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/sincronizacion/fusion.dart';
import 'package:test/test.dart';

AlmacenLocal _dispositivo() => AlmacenLocal.sobre({
      for (final nombre in AlmacenLocal.nombresDeArchivo) nombre: ArchivoTextoMemoria(),
    });

const _perfil = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(30000));

Map<String, dynamic> _mov(String clientId, [String estado = 'activo']) =>
    {'clientId': clientId, 'estado': estado};

Map<String, dynamic> _cat(String id) => {'id': id, 'nombre': id};

Future<void> _escribir(AlmacenLocal a, String archivo, List<Map<String, dynamic>> items) =>
    a.archivos[archivo]!.escribir(jsonEncode(items));

Future<List<Map<String, dynamic>>> _leer(AlmacenLocal a, String archivo) async {
  final texto = await a.archivos[archivo]!.leer();
  return texto == null ? [] : (jsonDecode(texto) as List<dynamic>).cast<Map<String, dynamic>>();
}

void main() {
  late RespaldoEnMemoria drive;

  setUp(() => drive = RespaldoEnMemoria());

  test('activar sube todo lo del dispositivo cuando no había respaldo', () async {
    final a = _dispositivo();
    await a.perfil.guardar(_perfil);
    final nube = ServicioNube(almacen: a, remoto: drive);

    final estado = await nube.estadoInicial();
    expect(estado.hayDatosLocales, isTrue);
    expect(estado.hayDatosEnNube, isFalse);
    expect(estado.hayQueElegir, isFalse);

    // Registro mínimo: la fusión solo mira la clave y el estado.
    await _escribir(a, 'movimientos.json', [_mov('m1')]);

    await nube.activar(ModoFusion.usarDispositivo);
    expect(await nube.estaActiva(), isTrue);
    expect(await nube.ultimaSincronizacion(), isNotNull);
    expect(drive.copia!['movimientos.json']!.single['clientId'], 'm1');
    expect(drive.copia!['perfil.json'], hasLength(1));
  });

  test('dispositivo nuevo: detecta el respaldo y lo restaura', () async {
    final a = _dispositivo();
    await a.perfil.guardar(_perfil);
    await _escribir(a, 'categorias.json', [_cat('c1')]);
    await ServicioNube(almacen: a, remoto: drive).activar(ModoFusion.usarDispositivo);

    final b = _dispositivo();
    final nubeB = ServicioNube(almacen: b, remoto: drive);
    expect(await nubeB.hayRespaldoEnNube(), isTrue);
    await nubeB.activar(ModoFusion.usarNube);
    expect(await b.perfil.obtener(), _perfil);
    expect((await _leer(b, 'categorias.json')).single['id'], 'c1');
  });

  test('sin permiso concedido no ofrece restaurar ni pregunta', () async {
    drive
      ..copia = {
        'perfil.json': [_perfil.toJson()],
      }
      ..acceso = false;
    final nube = ServicioNube(almacen: _dispositivo(), remoto: drive);
    expect(await nube.hayRespaldoEnNube(), isFalse);
    expect(() => nube.activar(ModoFusion.usarNube), throwsStateError);
  });

  test('con datos en ambos lados hay que elegir cómo combinar', () async {
    drive.copia = {
      'perfil.json': [_perfil.toJson()],
    };
    final a = _dispositivo();
    await a.perfil.guardar(_perfil);
    final estado = await ServicioNube(almacen: a, remoto: drive).estadoInicial();
    expect(estado.hayQueElegir, isTrue);
  });

  test('una anulación y un borrado viajan al otro dispositivo sin revivir', () async {
    final a = _dispositivo();
    await _escribir(a, 'movimientos.json', [_mov('m1'), _mov('m2')]);
    await _escribir(a, 'categorias.json', [_cat('c1'), _cat('c2')]);
    final nubeA = ServicioNube(almacen: a, remoto: drive);
    await nubeA.activar(ModoFusion.usarDispositivo);

    final b = _dispositivo();
    final nubeB = ServicioNube(almacen: b, remoto: drive);
    await nubeB.activar(ModoFusion.usarNube);

    // En A: se anula m1 y se borra la categoría c2.
    await _escribir(a, 'movimientos.json', [_mov('m1', 'anulado'), _mov('m2')]);
    await _escribir(a, 'categorias.json', [_cat('c1')]);
    expect(await nubeA.sincronizarSiActiva(), isTrue);

    await nubeB.sincronizarAhora();
    final movsB = await _leer(b, 'movimientos.json');
    expect(movsB.firstWhere((m) => m['clientId'] == 'm1')['estado'], 'anulado');
    expect((await _leer(b, 'categorias.json')).map((c) => c['id']), ['c1']);

    // B vuelve a sincronizar: c2 no revive en la copia.
    await nubeB.sincronizarAhora();
    expect(drive.copia!['categorias.json']!.map((c) => c['id']), ['c1']);
  });

  test('sin cambios no vuelve a subir la copia', () async {
    final a = _dispositivo();
    await _escribir(a, 'movimientos.json', [_mov('m1')]);
    final nube = ServicioNube(almacen: a, remoto: drive);
    await nube.activar(ModoFusion.usarDispositivo);
    final subidas = drive.subidas;
    await nube.sincronizarAhora();
    expect(drive.subidas, subidas);
  });

  test('la sincronización de rutina no hace nada si está inactiva o sin permiso, y nunca lanza', () async {
    final a = _dispositivo();
    final nube = ServicioNube(almacen: a, remoto: drive);
    expect(await nube.sincronizarSiActiva(), isFalse);

    await nube.activar(ModoFusion.usarDispositivo);
    drive.acceso = false;
    expect(await nube.sincronizarSiActiva(), isFalse);

    await a.estadoNube.escribir('no es json');
    expect(await nube.sincronizarSiActiva(), isFalse);
  });

  test('pausar conserva la copia; borrarla la quita y desactiva', () async {
    final a = _dispositivo();
    await _escribir(a, 'movimientos.json', [_mov('m1')]);
    final nube = ServicioNube(almacen: a, remoto: drive);
    await nube.activar(ModoFusion.usarDispositivo);

    await nube.desactivar();
    expect(await nube.estaActiva(), isFalse);
    expect(drive.copia, isNotNull);

    await nube.activar(ModoFusion.combinar);
    await nube.borrarCopiaEnNube();
    expect(drive.copia, isNull);
    expect(await nube.estaActiva(), isFalse);
    expect(await nube.ultimaSincronizacion(), isNull);
  });

  test('tras marcarReemplazo, lo eliminado no revive y la copia queda igual al dispositivo', () async {
    final a = _dispositivo();
    await _escribir(a, 'movimientos.json', [_mov('m1'), _mov('m2')]);
    await _escribir(a, 'categorias.json', [_cat('c1'), _cat('c2')]);
    final nube = ServicioNube(almacen: a, remoto: drive);
    await nube.activar(ModoFusion.usarDispositivo);

    expect(await nube.pedirAcceso(), isTrue);
    await nube.marcarReemplazo();
    await _escribir(a, 'movimientos.json', [_mov('m2')]);
    await _escribir(a, 'categorias.json', [_cat('c2')]);
    expect(await nube.sincronizarSiActiva(), isTrue);

    expect(drive.copia!['movimientos.json'], [_mov('m2')]);
    expect(drive.copia!['categorias.json'], [_cat('c2')]);

    // La sincronización normal siguiente tampoco los trae de vuelta.
    await nube.sincronizarSiActiva();
    expect(await _leer(a, 'movimientos.json'), [_mov('m2')]);
    expect(await _leer(a, 'categorias.json'), [_cat('c2')]);
    expect(drive.copia!['movimientos.json'], [_mov('m2')]);
  });

  test('sin red, el reemplazo queda pendiente para la siguiente sincronización', () async {
    final a = _dispositivo();
    await _escribir(a, 'movimientos.json', [_mov('m1'), _mov('m2')]);
    final nube = ServicioNube(almacen: a, remoto: drive);
    await nube.activar(ModoFusion.usarDispositivo);

    await nube.marcarReemplazo();
    await _escribir(a, 'movimientos.json', [_mov('m2')]);
    drive.acceso = false;
    expect(await nube.sincronizarSiActiva(), isFalse);

    drive.acceso = true;
    expect(await nube.sincronizarSiActiva(), isTrue);
    expect(await _leer(a, 'movimientos.json'), [_mov('m2')]);
    expect(drive.copia!['movimientos.json'], [_mov('m2')]);
  });

  test('desactivar olvida un reemplazo pendiente', () async {
    final a = _dispositivo();
    await _escribir(a, 'movimientos.json', [_mov('m1')]);
    final nube = ServicioNube(almacen: a, remoto: drive);
    await nube.activar(ModoFusion.usarDispositivo);
    await nube.marcarReemplazo();
    await nube.desactivar();
    await _escribir(a, 'movimientos.json', const []);
    await nube.activar(ModoFusion.combinar);
    expect(await _leer(a, 'movimientos.json'), [_mov('m1')]);
  });
}
