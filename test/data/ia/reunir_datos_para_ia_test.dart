import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/ia/configuracion_ia.dart';
import 'package:app_finanzas/data/ia/reunir_datos_para_ia.dart';
import 'package:app_finanzas/data/ia/servicio_ia.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/domain/ia/datos_para_ia.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

// spec §6.5, uso 4: lo que el asistente sabe sale de los mismos archivos y
// cálculos que Inicio y Patrimonio.

final _hoy = DateTime(2026, 11, 15, 10);

AlmacenLocal _vacio() => AlmacenLocal.sobre({for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()});

Future<void> _gasto(AlmacenLocal a, String id, String categoria, int pesos, DateTime fecha, {String? cuenta}) async {
  final m = crearMovimiento(
    clientId: 'gasto-de-prueba-$id',
    fecha: fecha,
    calculadoraCiclo: const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(30000)).calculadoraCiclo,
    monto: Dinero.pesos(pesos),
    categoriaId: categoria,
    medio: MedioPago.tarjeta,
    descripcion: 'x',
    origenCaptura: OrigenCaptura.manual,
  ).valorOLanza;
  await a.movimientos.guardar(m.copyWith(cuentaId: cuenta));
}

void main() {
  test('sin perfil no hay datos', () async {
    expect(await reunirDatosParaIA(_vacio(), _hoy), isNull);
  });

  test('reúne ciclo, categorías, ciclo pasado, cuentas, patrimonio y objetivos', () async {
    final a = _vacio();
    await a.perfil.guardar(const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(30000)));
    await a.categorias.guardar(const CategoriaVariable(
      id: 'super',
      nombre: 'Súper',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(4000),
    ));
    await a.categorias.guardar(const CategoriaFija(
      id: 'renta',
      nombre: 'Renta',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(9000),
      diaDelCiclo: 1,
    ));
    await a.cuentas.guardar(Cuenta(
      id: 'bbva',
      nombre: 'BBVA',
      emoji: '🟦',
      tipo: TipoCuenta.debito,
      llevaSaldo: true,
      saldoInicial: const Dinero.pesos(5000),
      fechaSaldoInicial: DateTime(2026, 11, 1),
    ));
    await a.cuentas.guardar(Cuenta(
      id: 'cetes',
      nombre: 'Cetes',
      emoji: '🌱',
      tipo: TipoCuenta.ahorro,
      llevaSaldo: true,
      saldoInicial: const Dinero.pesos(3000),
      fechaSaldoInicial: DateTime(2026, 11, 1),
    ));
    await a.objetivos.guardar(Objetivo(
      id: 'viaje',
      nombre: 'Viaje',
      emoji: '✈️',
      monto: const Dinero.pesos(20000),
      cuentaId: 'cetes',
      creado: DateTime(2026, 11, 1),
    ));
    await _gasto(a, '1', 'super', 230, DateTime(2026, 11, 14), cuenta: 'bbva');
    await _gasto(a, '2', 'super', 1000, DateTime(2026, 11, 5), cuenta: 'bbva'); // ciclo pasado

    final d = (await reunirDatosParaIA(a, _hoy))!;
    expect(d.ciclo.id, const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.cero()).calculadoraCiclo.calcularPara(_hoy).id);
    expect(d.ingreso, const Dinero.pesos(30000));
    expect(d.categorias, [
      (nombre: 'Súper', gastado: const Dinero.pesos(230), presupuesto: const Dinero.pesos(4000), fija: false),
      (nombre: 'Renta', gastado: const Dinero.cero(), presupuesto: const Dinero.pesos(9000), fija: true),
    ]);
    expect(d.gastadoCicloPasado, const Dinero.pesos(1000));
    expect(d.cuentas, contains((nombre: 'BBVA', saldo: const Dinero.pesos(3770), debe: false)));
    expect(d.patrimonio, const Dinero.pesos(6770));
    expect(d.objetivos, [(nombre: 'Viaje', meta: const Dinero.pesos(20000), llevas: const Dinero.pesos(3000))]);

    final texto = textoParaIA(d);
    expect(texto, contains(r'- Súper: gastado $230 de $4,000, le quedan $3,770'));
    expect(texto, contains(r'- Viaje: lleva $3,000 de $20,000'));
  });

  test('el servicio solo entrega los números si el usuario lo permitió, y nunca truena', () async {
    var pedidos = 0;
    final s = ServicioIA(AlmacenConfiguracionIA(ArchivoTextoMemoria()), datosDelUsuario: () async {
      pedidos++;
      return 'DATOS';
    });
    expect(await s.datosParaAsistente(), isNull);
    expect(pedidos, 0);
    await s.verMisNumeros(true);
    expect(await s.datosParaAsistente(), 'DATOS');
    expect((await s.configuracion()).toJson()['verMisNumeros'], isTrue);
    await s.verMisNumeros(false);
    expect(await s.datosParaAsistente(), isNull);

    final falla = ServicioIA(AlmacenConfiguracionIA(ArchivoTextoMemoria()), datosDelUsuario: () async => throw StateError('x'));
    await falla.verMisNumeros(true);
    expect(await falla.datosParaAsistente(), isNull);
    final sin = ServicioIA(AlmacenConfiguracionIA(ArchivoTextoMemoria()));
    await sin.verMisNumeros(true);
    expect(await sin.datosParaAsistente(), isNull);
  });
}
