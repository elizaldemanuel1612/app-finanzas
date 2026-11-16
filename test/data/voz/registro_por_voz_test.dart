import 'dart:convert';

import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/data/voz/registro_por_voz.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/presupuesto/resumen_variables.dart';
import 'package:app_finanzas/domain/voz/frases_voz.dart';
import 'package:test/test.dart';

// Registrar con la voz de punta a punta (spec-app-finanzas-v2.md §5.6.3):
// lo que hace Siri sin abrir la app, sobre los mismos archivos de la app.

final _hoy = DateTime(2026, 11, 15, 9, 30);

Future<AlmacenLocal> _almacen({bool conPerfil = true}) async {
  final a = AlmacenLocal.sobre({for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()});
  if (conPerfil) {
    await a.perfil.guardar(const Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(30000)));
  }
  for (final c in [
    const CategoriaVariable(
      id: 'super',
      nombre: 'Súper/Comida',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(4000),
    ),
    const CategoriaVariable(
      id: 'salidas',
      nombre: 'Salidas',
      emoji: '🍽️',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(500),
    ),
    const CategoriaVariable(
      id: 'cafe',
      nombre: 'Café',
      emoji: '☕',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.cero(),
    ),
    const CategoriaFija(
      id: 'renta',
      nombre: 'Renta',
      emoji: '🏠',
      activa: true,
      esNecesaria: true,
      montoFijoCentavos: Dinero.pesos(9000),
      diaDelCiclo: 1,
    ),
  ]) {
    await a.categorias.guardar(c);
  }
  await a.cuentas.guardar(Cuenta(
    id: 'bbva',
    nombre: 'BBVA',
    emoji: '🟦',
    tipo: TipoCuenta.debito,
    llevaSaldo: true,
    saldoInicial: const Dinero.pesos(5000),
    fechaSaldoInicial: DateTime(2026, 1, 1),
  ));
  return a;
}

RegistroPorVoz _registro(AlmacenLocal a, {CategoriaPorIA? ia}) {
  var n = 0;
  return RegistroPorVoz(almacen: a, ia: ia, reloj: () => _hoy, nuevoClientId: () => 'voz-0000-0000-${(n++).toString().padLeft(4, '0')}');
}

void main() {
  test('sin perfil (sin sesión configurada) lo dice y no guarda', () async {
    final a = await _almacen(conPerfil: false);
    final r = await _registro(a).interpretar('230 en el súper');
    expect(r.estado, EstadoVoz.sinSesion);
    expect(r.mensaje, contains('inicia sesión'));
    expect((await _registro(a).resumen()).estado, EstadoVoz.sinSesion);
    expect((await _registro(a).registrar('{}')).estado, EstadoVoz.sinSesion);
  });

  test('frase completa: confirma, registra con las reglas de la captura y contesta cómo va', () async {
    final a = await _almacen();
    final voz = _registro(a);
    final r = await voz.interpretar('ayer gasté 230 en el súper con la BBVA');
    expect(r.estado, EstadoVoz.listo);
    expect(r.mensaje, r'¿Registro $230 en Súper y Comida con BBVA, ayer?');

    final hecho = await voz.registrar(r.propuesta!);
    expect(hecho.estado, EstadoVoz.registrado);
    expect(hecho.mensaje, r'Listo. Te quedan $3,770 en Súper y Comida.');

    final m = (await a.movimientos.listarTodos()).single;
    expect(m.monto, const Dinero.pesos(230));
    expect(m.categoriaId, 'super');
    expect(m.cuentaId, 'bbva');
    expect(m.medio, MedioPago.tarjeta);
    expect(m.fecha, DateTime(2026, 11, 14, 12));
    expect(m.cicloId, const CalculadoraCiclo(12).calcularPara(DateTime(2026, 11, 14)).id, reason: 'regla #5');
    expect(m.origenCaptura, OrigenCaptura.voz);
    expect(m.estado, EstadoMovimiento.activo);
    expect(m.descripcion, 'Súper');
    expect(m.clasificadoPorIA, isFalse);
    // Aprende como la captura (§6.2).
    expect((await a.reglasAprendidas.listarTodas()).single.categoriaId, 'super');
    // Lo del widget (variables con presupuesto del ciclo en curso).
    expect(hecho.resumen!.gastadoConPresupuesto, const Dinero.pesos(230));
    expect(hecho.resumen!.presupuesto, const Dinero.pesos(4500));
  });

  test('pasarse del presupuesto se dice', () async {
    final voz = _registro(await _almacen());
    final hecho = await voz.registrar((await voz.interpretar('650 en salidas')).propuesta!);
    expect(hecho.mensaje, r'Listo. Te pasaste por $150 en Salidas.');
  });

  test('confirmar dos veces no duplica (mismo clientId, regla #2)', () async {
    final a = await _almacen();
    final voz = _registro(a);
    final r = await voz.interpretar('230 en el súper');
    await voz.registrar(r.propuesta!);
    await voz.registrar(r.propuesta!);
    expect(await a.movimientos.listarTodos(), hasLength(1));
  });

  test('hoy: con la hora de ahora', () async {
    final a = await _almacen();
    final voz = _registro(a);
    await voz.registrar((await voz.interpretar('100 de salidas')).propuesta!);
    expect((await a.movimientos.listarTodos()).single.fecha, _hoy);
  });

  test('sin monto o con dos, lo dice; con varios gastos, pide uno', () async {
    final voz = _registro(await _almacen());
    final sin = await voz.interpretar('fui al súper');
    expect(sin.estado, EstadoVoz.faltaMonto);
    expect(sin.mensaje, contains('No entendí cuánto'));
    final dos = await voz.interpretar('doce tacos de treinta pesos');
    expect(dos.estado, EstadoVoz.faltaMonto);
    expect(dos.mensaje, r'Escuché $12 y $30 y no sé cuál es el total. Dímelo otra vez con el total.');
    final varios = await voz.interpretar('50 de café y 200 de súper');
    expect(varios.estado, EstadoVoz.variosGastos);
  });

  test('sin categoría, pregunta y acepta la que se dice', () async {
    final a = await _almacen();
    final voz = _registro(a);
    final r = await voz.interpretar('350 en la farmacia');
    expect(r.estado, EstadoVoz.faltaCategoria);
    expect(r.mensaje, startsWith('¿En qué categoría va? Por ejemplo:'));

    final otra = await voz.conCategoria(r.propuesta!, 'viajes');
    expect(otra.estado, EstadoVoz.faltaCategoria);
    expect(otra.mensaje, startsWith('No encontré "viajes".'));

    final lista = await voz.conCategoria(otra.propuesta!, 'salidas');
    expect(lista.estado, EstadoVoz.listo);
    expect(lista.mensaje, r'¿Registro $350 en Salidas con BBVA, hoy?');
    final hecho = await voz.registrar(lista.propuesta!);
    expect(hecho.mensaje, r'Listo. Te quedan $150 en Salidas.');
    expect((await a.movimientos.listarTodos()).single.descripcion, 'Farmacia');
  });

  test('la IA completa solo la categoría y queda marcado', () async {
    final a = await _almacen();
    String? frasePedida;
    final voz = _registro(a, ia: (frase, ctx) async {
      frasePedida = frase;
      return 'Salidas';
    });
    final r = await voz.interpretar('350 en unos tacos');
    expect(frasePedida, '350 en unos tacos');
    expect(r.estado, EstadoVoz.listo);
    await voz.registrar(r.propuesta!);
    expect((await a.movimientos.listarTodos()).single.clasificadoPorIA, isTrue);
  });

  test('la IA no se consulta si no hace falta, y si falla se pregunta', () async {
    var llamadas = 0;
    final voz = _registro(await _almacen(), ia: (_, _) async {
      llamadas++;
      throw StateError('sin red');
    });
    expect((await voz.interpretar('230 en el súper')).estado, EstadoVoz.listo);
    expect((await voz.interpretar('fui al súper')).estado, EstadoVoz.faltaMonto);
    expect(llamadas, 0);
    expect((await voz.interpretar('350 en la farmacia')).estado, EstadoVoz.faltaCategoria);
    expect(llamadas, 1);
  });

  test('una categoría sin presupuesto: "llevas"; una fija: "quedó en"', () async {
    final a = await _almacen();
    final voz = _registro(a);
    final cafe = await voz.registrar((await voz.interpretar('45 de café')).propuesta!);
    expect(cafe.mensaje, r'Listo. Llevas $45 en Café.');
    final renta = await voz.registrar((await voz.interpretar('9000 de renta')).propuesta!);
    expect(renta.mensaje, 'Listo, quedó en Renta.');
  });

  test('un ciclo cerrado no se toca desde Siri', () async {
    final a = await _almacen();
    final voz = _registro(a);
    final ciclo = const CalculadoraCiclo(12).calcularPara(DateTime(2026, 11, 10));
    await a.ciclos.guardar(CicloGuardado(
      ciclo: Ciclo(
        id: ciclo.id,
        fechaInicio: ciclo.fechaInicio,
        fechaFin: ciclo.fechaFin,
        etiqueta: ciclo.etiqueta,
        estado: EstadoCiclo.cerrado,
      ),
    ));
    final r = await voz.interpretar('el lunes 200 en el súper');
    expect(r.estado, EstadoVoz.listo);
    final hecho = await voz.registrar(r.propuesta!);
    expect(hecho.estado, EstadoVoz.cicloCerrado);
    expect(hecho.mensaje, contains('reábrelo en la app'));
    expect(await a.movimientos.listarTodos(), isEmpty);
  });

  test('lo que no pasa las reglas del gasto se dice y no se guarda', () async {
    final a = await _almacen();
    final voz = RegistroPorVoz(almacen: a, reloj: () => _hoy, nuevoClientId: () => 'x');
    final hecho = await voz.registrar((await voz.interpretar('100 de salidas')).propuesta!);
    expect(hecho.estado, EstadoVoz.error);
    expect(hecho.mensaje, startsWith('No pude registrarlo:'));
    expect(await a.movimientos.listarTodos(), isEmpty);
  });

  test('una propuesta incompleta o con categoría archivada no se guarda', () async {
    final a = await _almacen();
    final voz = _registro(a);
    final falta = await voz.interpretar('350 en la farmacia');
    expect((await voz.registrar(falta.propuesta!)).estado, EstadoVoz.faltaMonto);
    final lista = await voz.interpretar('100 de salidas');
    await a.categorias.guardar(const CategoriaVariable(
      id: 'salidas',
      nombre: 'Salidas',
      emoji: '🍽️',
      activa: false,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(500),
    ));
    expect((await voz.registrar(lista.propuesta!)).estado, EstadoVoz.faltaCategoria);
    expect(await a.movimientos.listarTodos(), isEmpty);
  });

  test('resumen: lo mismo que Inicio', () async {
    final a = await _almacen();
    final voz = _registro(a);
    await voz.registrar((await voz.interpretar('230 en el súper')).propuesta!);
    await voz.registrar((await voz.interpretar('45 de café')).propuesta!);
    final r = await voz.resumen();
    expect(r.mensaje,
        r'Llevas $230 de $4,500 este ciclo. Te quedan $4,270 y faltan 26 días. Además, $45 en categorías sin presupuesto.');
    expect(r.resumen!.gastadoSinPresupuesto, const Dinero.pesos(45));
  });

  test('frases: fecha lejana, pasarse en el resumen y solo registro', () {
    expect(fechaHablada(DateTime(2026, 10, 3), _hoy), 'el 3 de octubre');
    expect(fechaHablada(DateTime(2026, 11, 10), _hoy), 'el martes 10');
    const pasado = ResumenVariables(
      gastadoConPresupuesto: Dinero.pesos(5200),
      gastadoSinPresupuesto: Dinero.cero(),
      presupuesto: Dinero.pesos(5000),
    );
    expect(resumenHablado(pasado, 1), r'Llevas $5,200 de $5,000 este ciclo. Te pasaste por $200 y falta 1 día.');
    expect(pasado.gastado, const Dinero.pesos(5200));
    const solo = ResumenVariables(
      gastadoConPresupuesto: Dinero.cero(),
      gastadoSinPresupuesto: Dinero.pesos(300),
      presupuesto: Dinero.cero(),
    );
    expect(solo.gastado, const Dinero.pesos(300));
    expect(resumenHablado(solo, 0), r'Llevas $300 este ciclo y hoy cierra tu ciclo.');
  });

  test('la propuesta viaja como texto y conserva el clientId', () async {
    final voz = _registro(await _almacen());
    final r = await voz.interpretar('350 en la farmacia');
    final json = jsonDecode(r.propuesta!) as Map;
    expect(json['clientId'], 'voz-0000-0000-0000');
    final lista = await voz.conCategoria(r.propuesta!, 'Salidas');
    expect((jsonDecode(lista.propuesta!) as Map)['clientId'], 'voz-0000-0000-0000');
    expect(r.toMap()['estado'], 'faltaCategoria');
  });
}
