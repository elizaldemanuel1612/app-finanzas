import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/cambio_de_corte.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:test/test.dart';

const _perfil12 = Perfil(diaCorte: 12, ingresoBaseMensual: Dinero.pesos(35000));

void main() {
  group('CalculadoraCiclo con historial de cortes', () {
    // Corte 12 → 1, transición del 12 oct al 31 oct, rige desde el 1 nov.
    final cambio = CambioDeCorte(
      diaCorteAnterior: 12,
      diaCorteNuevo: 1,
      inicioTransicion: DateTime(2026, 10, 12),
      vigenteDesde: DateTime(2026, 11, 1),
    );
    final calc = CalculadoraCiclo(1, cambios: [cambio]);

    test('antes de la transición rige el corte anterior (historial intacto)', () {
      final c = calc.calcularPara(DateTime(2026, 10, 5));
      expect(c.id, '2026-09');
      expect(c.fechaInicio, DateTime(2026, 9, 12));
      expect(c.fechaFin, DateTime(2026, 10, 11));
    });

    test('la transición conserva el inicio y el id del ciclo en curso', () {
      final c = calc.calcularPara(DateTime(2026, 10, 25, 18, 30));
      expect(c.id, '2026-10');
      expect(c.fechaInicio, DateTime(2026, 10, 12));
      expect(c.fechaFin, DateTime(2026, 10, 31));
      expect(calc.calcularPara(DateTime(2026, 10, 31)).id, '2026-10');
    });

    test('desde vigenteDesde rige el corte nuevo', () {
      final c = calc.calcularPara(DateTime(2026, 11, 1));
      expect(c.id, '2026-11');
      expect(c.fechaInicio, DateTime(2026, 11, 1));
      expect(c.fechaFin, DateTime(2026, 11, 30));
      expect(calc.calcularPara(DateTime(2027, 2, 14)).fechaInicio, DateTime(2027, 2, 1));
    });

    test('dos cambios encadenados', () {
      final segundo = CambioDeCorte(
        diaCorteAnterior: 1,
        diaCorteNuevo: 20,
        inicioTransicion: DateTime(2027, 1, 1),
        vigenteDesde: DateTime(2027, 2, 20),
      );
      final calc2 = CalculadoraCiclo(20, cambios: [cambio, segundo]);
      expect(calc2.calcularPara(DateTime(2026, 9, 20)).fechaInicio, DateTime(2026, 9, 12));
      expect(calc2.calcularPara(DateTime(2026, 10, 20)).fechaFin, DateTime(2026, 10, 31));
      expect(calc2.calcularPara(DateTime(2026, 12, 20)).fechaInicio, DateTime(2026, 12, 1));
      final t = calc2.calcularPara(DateTime(2027, 2, 10));
      expect((t.fechaInicio, t.fechaFin), (DateTime(2027, 1, 1), DateTime(2027, 2, 19)));
      expect(calc2.calcularPara(DateTime(2027, 3, 1)).fechaInicio, DateTime(2027, 2, 20));
    });

    test('CambioDeCorte ida y vuelta por JSON', () {
      expect(CambioDeCorte.fromJson(cambio.toJson()), cambio);
      expect(cambio.toJson()['vigenteDesde'], '2026-11-01');
      expect(cambio.hashCode, CambioDeCorte.fromJson(cambio.toJson()).hashCode);
      expect(cambio.toString(), contains('12 → 1'));
    });
  });

  group('proponerCambioDeCorte', () {
    test('de 12 a 1 a media transición: corta (20 días) o larga (50 días)', () {
      final p = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 1, hoy: DateTime(2026, 10, 25));
      expect(p.diaVigente, 12);
      expect(p.cicloActual.fechaInicio, DateTime(2026, 10, 12));
      expect(p.opciones, hasLength(2));
      final corta = p.opciones[0];
      final larga = p.opciones[1];
      expect((corta.inicio, corta.fin, corta.vigenteDesde),
          (DateTime(2026, 10, 12), DateTime(2026, 10, 31), DateTime(2026, 11, 1)));
      expect(corta.dias, 20);
      expect(larga.vigenteDesde, DateTime(2026, 12, 1));
      expect(larga.dias, 50);
      expect(corta.recomendada, isTrue, reason: '|20−30| < |50−30|');
      expect(larga.recomendada, isFalse);
      expect(p.esMismoDia, isFalse);
      expect(p.habiaPendiente, isFalse);
    });

    test('nunca ofrece un ciclo nuevo en el mismo mes del inicio (ids sin choque)', () {
      // Corte 1 → 28 el 5 de oct: el 28 de oct chocaría con el id 2026-10.
      const perfil1 = Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000));
      final p = proponerCambioDeCorte(perfil: perfil1, diaNuevo: 28, hoy: DateTime(2026, 10, 5));
      expect(p.opciones.map((o) => o.vigenteDesde),
          [DateTime(2026, 11, 28), DateTime(2026, 12, 28)]);
      expect(p.opciones.first.dias, 58);
      expect(p.opciones.first.recomendada, isTrue);
    });

    test('el primer corte nuevo siempre es después de hoy', () {
      // Hoy 2 de nov, ciclo en curso 12 oct–11 nov, nuevo día 1: el 1 de
      // nov ya pasó, así que la primera opción es el 1 de dic.
      final p = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 1, hoy: DateTime(2026, 11, 2));
      expect(p.opciones.first.vigenteDesde, DateTime(2026, 12, 1));
      expect(p.opciones.first.dias, 50);
      expect(p.opciones.last.vigenteDesde, DateTime(2027, 1, 1));
    });

    test('día 31 se ajusta al último día de meses cortos', () {
      final p = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 31, hoy: DateTime(2026, 10, 25));
      expect(p.opciones.first.vigenteDesde, DateTime(2026, 11, 30));
      expect(p.opciones.last.vigenteDesde, DateTime(2026, 12, 31));
    });

    test('mismo día: sin opciones', () {
      final p = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 12, hoy: DateTime(2026, 10, 25));
      expect(p.esMismoDia, isTrue);
      expect(p.opciones, isEmpty);
    });
  });

  group('aplicarCambioDeCorte', () {
    test('guarda el día nuevo y el cambio en el historial', () {
      final p = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 1, hoy: DateTime(2026, 10, 25));
      final nuevo = aplicarCambioDeCorte(perfil: _perfil12, propuesta: p, opcion: p.opciones.first);
      expect(nuevo.diaCorte, 1);
      expect(nuevo.cambiosDeCorte.single.diaCorteAnterior, 12);
      expect(nuevo.calculadoraCiclo.calcularPara(DateTime(2026, 10, 25)).fechaFin, DateTime(2026, 10, 31));
      expect(cambioPendiente(nuevo, DateTime(2026, 10, 25)), isNotNull);
      expect(cambioPendiente(nuevo, DateTime(2026, 11, 1)), isNull);
      expect(cambioPendiente(_perfil12, DateTime(2026, 10, 25)), isNull);
    });

    test('un segundo cambio antes de que rija reemplaza al pendiente', () {
      final hoy = DateTime(2026, 10, 25);
      final p1 = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 1, hoy: hoy);
      final con1 = aplicarCambioDeCorte(perfil: _perfil12, propuesta: p1, opcion: p1.opciones.first);

      final p2 = proponerCambioDeCorte(perfil: con1, diaNuevo: 20, hoy: hoy);
      expect(p2.habiaPendiente, isTrue);
      expect(p2.diaVigente, 12, reason: 'se compara contra el corte que rige, no el pendiente');
      expect(p2.cicloActual.fechaFin, DateTime(2026, 11, 11), reason: 'ciclo sin el cambio pendiente');
      final con2 = aplicarCambioDeCorte(perfil: con1, propuesta: p2, opcion: p2.opciones.first);
      expect(con2.cambiosDeCorte, hasLength(1));
      expect(con2.cambiosDeCorte.single.diaCorteNuevo, 20);
      expect(con2.cambiosDeCorte.single.vigenteDesde, DateTime(2026, 11, 20));
    });

    test('regresar al día original cancela el cambio pendiente', () {
      final hoy = DateTime(2026, 10, 25);
      final p1 = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 1, hoy: hoy);
      final con1 = aplicarCambioDeCorte(perfil: _perfil12, propuesta: p1, opcion: p1.opciones.first);
      final p2 = proponerCambioDeCorte(perfil: con1, diaNuevo: 12, hoy: hoy);
      expect(p2.esMismoDia, isTrue);
      final cancelado = aplicarCambioDeCorte(perfil: con1, propuesta: p2);
      expect(cancelado, _perfil12);
    });
  });

  group('Perfil con historial de cortes', () {
    test('JSON ida y vuelta; perfiles viejos sin el campo se leen igual', () {
      final p = proponerCambioDeCorte(perfil: _perfil12, diaNuevo: 1, hoy: DateTime(2026, 10, 25));
      final perfil = aplicarCambioDeCorte(perfil: _perfil12, propuesta: p, opcion: p.opciones.last);
      expect(Perfil.fromJson(perfil.toJson()), perfil);
      expect(Perfil.fromJson(perfil.toJson()).hashCode, perfil.hashCode);
      expect(_perfil12.toJson().containsKey('cambiosDeCorte'), isFalse);
      expect(Perfil.fromJson(_perfil12.toJson()).cambiosDeCorte, isEmpty);
      expect(perfil == _perfil12.copyWith(diaCorte: 1), isFalse, reason: 'el historial cuenta');
    });
  });
}
