import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/domain/objetivos/progreso_objetivos.dart';
import 'package:test/test.dart';

const _calc = CalculadoraCiclo(1);
final _hoy = DateTime(2026, 11, 14, 10);

Objetivo _obj(String id, int pesos, {DateTime? fecha, String cuenta = 'cetes', bool activo = true}) => Objetivo(
      id: id,
      nombre: id,
      emoji: '🎯',
      monto: Dinero.pesos(pesos),
      cuentaId: cuenta,
      creado: DateTime(2026, 11, 1),
      fechaLimite: fecha,
      activo: activo,
    );

List<ProgresoObjetivo> _progreso(List<Objetivo> objetivos, Map<String, int> saldos, {int? apartado}) =>
    calcularProgresoObjetivos(
      objetivos: objetivos,
      saldoPorCuenta: {for (final e in saldos.entries) e.key: Dinero.pesos(e.value)},
      hoy: _hoy,
      calculadora: _calc,
      apartadoPorCiclo: apartado == null ? null : Dinero.pesos(apartado),
    );

void main() {
  test('el avance es el saldo de su cuenta de ahorro', () {
    final p = _progreso([_obj('viaje', 10000)], {'cetes': 2500}).single;
    expect(p.llevas, const Dinero.pesos(2500));
    expect(p.falta, const Dinero.pesos(7500));
    expect(p.avance, 0.25);
    expect(p.estado, EstadoObjetivo.sinFecha);
    expect(p.ciclosRestantes, isNull);
    expect(p.porCiclo, isNull);
    expect(p.ciclosAlRitmoActual, isNull);
    expect(p.alcanzaATiempo, isNull);
  });

  test('varios en la misma cuenta se llenan en orden; los archivados no cuentan', () {
    final p = _progreso(
      [_obj('archivado', 9999, activo: false), _obj('fondo', 3000), _obj('viaje', 5000), _obj('auto', 1000)],
      {'cetes': 4000},
    );
    expect(p.map((x) => x.objetivo.id), ['fondo', 'viaje', 'auto']);
    expect(p[0].estado, EstadoObjetivo.logrado);
    expect(p[0].llevas, const Dinero.pesos(3000));
    expect(p[0].falta, const Dinero.cero());
    expect(p[0].avance, 1);
    expect(p[1].llevas, const Dinero.pesos(1000));
    expect(p[2].llevas, const Dinero.cero());
  });

  test('saldo negativo o cuenta que no está: lleva cero; monto cero no divide', () {
    expect(_progreso([_obj('a', 100)], {'cetes': -50}).single.llevas, const Dinero.cero());
    expect(_progreso([_obj('a', 100, cuenta: 'otra')], {'cetes': 50}).single.llevas, const Dinero.cero());
    final cero = _progreso([_obj('a', 0)], {'cetes': 50}).single;
    expect(cero.estado, EstadoObjetivo.logrado);
    expect(cero.avance, 0);
  });

  test('con fecha: ciclos que quedan y cuánto por ciclo, hacia arriba', () {
    // Nov, dic, ene, feb, mar = 5 ciclos; faltan 10,000.01 → 2,000.01 (redondeo arriba).
    final o = Objetivo(
      id: 'viaje',
      nombre: 'Viaje',
      emoji: '✈️',
      monto: const Dinero(1000001),
      cuentaId: 'cetes',
      creado: _hoy,
      fechaLimite: DateTime(2027, 3, 20),
    );
    final p = _progreso([o], {'cetes': 0}, apartado: 2500).single;
    expect(p.estado, EstadoObjetivo.enCamino);
    expect(p.ciclosRestantes, 5);
    expect(p.porCiclo, const Dinero(200001));
    expect(p.ciclosAlRitmoActual, 5, reason: '10,000.01 entre 2,500 → 5 ciclos');
    expect(p.alcanzaATiempo, isTrue);

    final lento = _progreso([o], {'cetes': 0}, apartado: 1000).single;
    expect(lento.ciclosAlRitmoActual, 11);
    expect(lento.alcanzaATiempo, isFalse);
    expect(_progreso([o], {'cetes': 0}, apartado: 0).single.ciclosAlRitmoActual, isNull);
  });

  test('la fecha ya pasó sin juntarlo: vencido, sin ritmo por ciclo', () {
    final p = _progreso([_obj('viaje', 100, fecha: DateTime(2026, 11, 13))], {'cetes': 10}, apartado: 30).single;
    expect(p.estado, EstadoObjetivo.vencido);
    expect(p.ciclosRestantes, isNull);
    expect(p.porCiclo, isNull);
    expect(p.ciclosAlRitmoActual, 3);
    expect(p.alcanzaATiempo, isNull);
  });

  test('ciclosHasta cuenta el ciclo que corre y el de la fecha', () {
    expect(ciclosHasta(hoy: _hoy, fecha: DateTime(2026, 11, 14), calculadora: _calc), 1);
    expect(ciclosHasta(hoy: _hoy, fecha: DateTime(2026, 11, 30, 23), calculadora: _calc), 1);
    expect(ciclosHasta(hoy: _hoy, fecha: DateTime(2026, 12, 1), calculadora: _calc), 2);
    expect(ciclosHasta(hoy: _hoy, fecha: DateTime(2026, 11, 1), calculadora: _calc), 0);
  });

  test('viaja en JSON; copyWith puede quitar la fecha', () {
    final o = _obj('viaje', 500, fecha: DateTime(2027, 6, 1));
    final copia = Objetivo.fromJson(o.toJson());
    expect(copia.nombre, 'viaje');
    expect(copia.monto, const Dinero.pesos(500));
    expect(copia.fechaLimite, DateTime(2027, 6, 1));
    expect(copia.cuentaId, 'cetes');
    expect(copia.activo, isTrue);
    expect(Objetivo.fromJson(_obj('x', 1).toJson()).fechaLimite, isNull);

    final editado = o.copyWith(nombre: 'Japón', emoji: '🗾', monto: const Dinero.pesos(900), cuentaId: 'gbm', activo: false);
    expect(editado.id, 'viaje');
    expect(editado.nombre, 'Japón');
    expect(editado.emoji, '🗾');
    expect(editado.monto, const Dinero.pesos(900));
    expect(editado.cuentaId, 'gbm');
    expect(editado.activo, isFalse);
    expect(editado.fechaLimite, DateTime(2027, 6, 1));
    expect(o.copyWith(fechaLimite: () => null).fechaLimite, isNull);
    expect(o.copyWith().nombre, 'viaje');
  });
}
