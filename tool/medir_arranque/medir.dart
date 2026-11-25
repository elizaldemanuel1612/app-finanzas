// ignore_for_file: avoid_print
// Mide lo que hace Inicio al abrir, con un historial grande sintético.
// dart run tool/medir_arranque/medir.dart [movimientos]
import 'dart:convert';
import 'dart:math';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/pronostico/pronostico_del_ciclo.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/nube/respaldo_remoto.dart';
import 'package:app_finanzas/data/nube/servicio_nube.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/sincronizacion/fusion.dart';

Future<void> main(List<String> args) async {
  final n = args.isEmpty ? 6000 : int.parse(args.first);
  final r = Random(1);
  final categorias = <Categoria>[
    for (var i = 0; i < 22; i++)
      CategoriaVariable(id: 'v$i', nombre: 'V$i', emoji: 'x', activa: true, esNecesaria: false, presupuestoMensualCentavos: Dinero(300000)),
    for (var i = 0; i < 8; i++)
      CategoriaFija(id: 'f$i', nombre: 'F$i', emoji: 'x', activa: true, esNecesaria: true, montoFijoCentavos: Dinero(100000), diaDelCiclo: 5),
  ];
  final calc = CalculadoraCiclo(1);
  final hoy = DateTime(2026, 11, 25);
  final movs = <Movimiento>[];
  for (var i = 0; i < n; i++) {
    final f = hoy.subtract(Duration(days: r.nextInt(365 * 3)));
    final c = categorias[r.nextInt(categorias.length)];
    movs.add(Movimiento(
      clientId: 'c$i', id: 'c$i', fecha: f, cicloId: calc.calcularPara(f).id,
      periodoNatural: '${f.year}-${f.month}', monto: Dinero(1000 + r.nextInt(200000)),
      categoriaId: c.id, medio: MedioPago.tarjeta, descripcion: 'Comercio ${r.nextInt(200)}',
      estado: EstadoMovimiento.activo, origenCaptura: OrigenCaptura.manual,
    ));
  }
  final json = jsonEncode([for (final m in movs) m.toJson()]);
  print('$n movimientos, JSON ${(json.length / 1024).round()} KB');

  final s = Stopwatch()..start();
  for (var k = 0; k < 5; k++) {
    (jsonDecode(json) as List).cast<Map<String, dynamic>>().map(Movimiento.fromJson).toList();
  }
  print('leer+decodificar: ${s.elapsedMilliseconds ~/ 5} ms');

  final ciclo = calc.calcularPara(hoy);
  s.reset();
  for (var k = 0; k < 3; k++) {
    estadosDeVariables(categorias: categorias, movimientos: movs, ciclo: ciclo, hoy: hoy);
  }
  print('estadosDeVariables (MPC): ${s.elapsedMilliseconds ~/ 3} ms');
  await medirSincronizacion(json);
}

Future<void> medirSincronizacion(String json) async {
  final archivos = {for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()};
  await archivos['movimientos.json']!.escribir(json);
  final almacen = AlmacenLocal.sobre(archivos);
  final nube = ServicioNube(almacen: almacen, remoto: RespaldoEnMemoria());
  await nube.activar(ModoFusion.combinar);
  final s = Stopwatch()..start();
  for (var k = 0; k < 3; k++) {
    print('  cambió algo: ${await nube.sincronizarSiActiva()}');
  }
  print('sincronizar sin cambios: ${s.elapsedMilliseconds ~/ 3} ms');
  final estado = await almacen.estadoNube.leer();
  print('nube.json (estado): ${(estado!.length / 1024).round()} KB');
}
