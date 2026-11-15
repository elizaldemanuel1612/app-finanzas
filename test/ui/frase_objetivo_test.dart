import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/domain/objetivos/progreso_objetivos.dart';
import 'package:app_finanzas/ui/objetivos/pantalla_objetivos.dart';
import 'package:flutter_test/flutter_test.dart';

// La frase de un objetivo con fecha habla del reparto por días
// (spec-app-finanzas-v2.md §7.3.3): con corte el 12 y fecha el 16 dic, este
// ciclo pide casi todo y el siguiente solo sus 5 días.
String _frase(DateTime fecha, {int apartado = 30000}) => fraseDeObjetivo(calcularProgresoObjetivos(
      objetivos: [
        Objetivo(
          id: 'viaje',
          nombre: 'Viaje',
          emoji: '✈️',
          monto: const Dinero.pesos(20000),
          cuentaId: 'cetes',
          creado: DateTime(2026, 11, 1),
          fechaLimite: fecha,
        ),
      ],
      saldoPorCuenta: const {},
      hoy: DateTime(2026, 11, 15, 14),
      calculadora: const CalculadoraCiclo(12),
      apartadoPorCiclo: Dinero.pesos(apartado),
    ).single);

void main() {
  test('un solo ciclo', () {
    expect(_frase(DateTime(2026, 12, 5)),
        r'Para el 5 dic: aparta $20,000 en este ciclo. Con lo que apartas hoy, llegas a tiempo.');
  });

  test('la fecha cae a pocos días del corte', () {
    expect(_frase(DateTime(2026, 12, 16)),
        r'Para el 16 dic: aparta $16,875 en este ciclo y $3,125 en el siguiente. '
        'Con lo que apartas hoy, llegas a tiempo.');
  });

  test('varios ciclos, en otro año y sin alcanzar', () {
    expect(
      _frase(DateTime(2027, 3, 16), apartado: 3000),
      startsWith(r'Para el 16 mar 2027: aparta $'),
    );
    expect(_frase(DateTime(2027, 3, 16), apartado: 3000),
        contains('en cada uno de los 4 siguientes. Con lo que apartas hoy llegarías en 7 ciclos.'));
  });
}
