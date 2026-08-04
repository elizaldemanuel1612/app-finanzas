import 'package:app_finanzas/domain/clasificacion/cascada_clasificacion.dart';
import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:test/test.dart';

void main() {
  group('Nivel 1 — reglas del usuario', () {
    test('coincide con una regla y aplica sin pedir confirmación', () {
      final r = clasificar(
        texto: 'Compra en Oxxo Insurgentes',
        reglasUsuario: const [ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 3)],
        historialComercios: const {},
      );
      expect(r.nivel, NivelClasificacion.reglaUsuario);
      expect(r.categoriaId, 'super');
      expect(r.confianza, 1.0);
      expect(r.requiereConfirmacion, isFalse);
      expect(r.marcadoParaRevision, isFalse);
    });

    test('entre dos reglas que coinciden, gana la más específica (patrón más largo)', () {
      final r = clasificar(
        texto: 'Farmacia Guadalajara Centro',
        reglasUsuario: const [
          ReglaAprendida(patron: 'farmacia', categoriaId: 'salud', contador: 1),
          ReglaAprendida(patron: 'farmacia guadalajara', categoriaId: 'salud-especifica', contador: 1),
        ],
        historialComercios: const {},
      );
      expect(r.categoriaId, 'salud-especifica');
    });

    test('nivel 1 tiene prioridad sobre nivel 2 aunque ambos coincidan', () {
      final r = clasificar(
        texto: 'Oxxo Insurgentes',
        reglasUsuario: const [ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 1)],
        historialComercios: const {'oxxo insurgentes': 'otra-categoria'},
      );
      expect(r.nivel, NivelClasificacion.reglaUsuario);
      expect(r.categoriaId, 'super');
    });
  });

  group('Nivel 2 — historial de comercios', () {
    test('sin reglas de usuario, resuelve por historial', () {
      final r = clasificar(
        texto: 'Compra en Farmacia Guadalajara',
        reglasUsuario: const [],
        historialComercios: const {'farmacia guadalajara': 'salud'},
      );
      expect(r.nivel, NivelClasificacion.historial);
      expect(r.categoriaId, 'salud');
      expect(r.requiereConfirmacion, isFalse);
    });
  });

  group('Nivel 3 — IA, con umbrales de confianza (§6.3)', () {
    test('confianza >= 0.90 se aplica automático', () {
      final r = clasificar(
        texto: 'algo nunca visto',
        reglasUsuario: const [],
        historialComercios: const {},
        clasificadorIA: (_) => const ResultadoIA(categoriaId: 'salidas', confianza: 0.95),
      );
      expect(r.nivel, NivelClasificacion.ia);
      expect(r.categoriaId, 'salidas');
      expect(r.requiereConfirmacion, isFalse);
      expect(r.marcadoParaRevision, isFalse);
    });

    test('confianza entre 0.60 y 0.89 pide confirmación', () {
      final r = clasificar(
        texto: 'algo ambiguo',
        reglasUsuario: const [],
        historialComercios: const {},
        clasificadorIA: (_) => const ResultadoIA(categoriaId: 'otros', confianza: 0.75),
      );
      expect(r.categoriaId, 'otros');
      expect(r.requiereConfirmacion, isTrue);
      expect(r.marcadoParaRevision, isFalse);
    });

    test('confianza < 0.60 va a revisión, sin categoría asignada', () {
      final r = clasificar(
        texto: 'algo rarísimo',
        reglasUsuario: const [],
        historialComercios: const {},
        clasificadorIA: (_) => const ResultadoIA(categoriaId: 'otros', confianza: 0.3),
      );
      expect(r.categoriaId, isNull);
      expect(r.marcadoParaRevision, isTrue);
      expect(r.requiereConfirmacion, isFalse);
    });

    test('límites exactos de los umbrales', () {
      ResultadoCascada conConfianza(double c) => clasificar(
            texto: 'x',
            reglasUsuario: const [],
            historialComercios: const {},
            clasificadorIA: (_) => ResultadoIA(categoriaId: 'cat', confianza: c),
          );
      expect(conConfianza(0.90).requiereConfirmacion, isFalse);
      expect(conConfianza(0.89).requiereConfirmacion, isTrue);
      expect(conConfianza(0.60).marcadoParaRevision, isFalse);
      expect(conConfianza(0.59).marcadoParaRevision, isTrue);
    });

    test('IA nunca se llama si nivel 1 o 2 ya resolvieron', () {
      var llamadaIA = false;
      final r = clasificar(
        texto: 'Oxxo',
        reglasUsuario: const [ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 1)],
        historialComercios: const {},
        clasificadorIA: (_) {
          llamadaIA = true;
          return const ResultadoIA(categoriaId: 'otra', confianza: 0.99);
        },
      );
      expect(llamadaIA, isFalse);
      expect(r.categoriaId, 'super');
    });
  });

  group('sin resolver', () {
    test('sin reglas, sin historial y sin IA, va a revisión', () {
      final r = clasificar(texto: 'algo desconocido', reglasUsuario: const [], historialComercios: const {});
      expect(r.nivel, NivelClasificacion.sinResolver);
      expect(r.categoriaId, isNull);
      expect(r.marcadoParaRevision, isTrue);
    });

    test('la IA tampoco supo (regresa null) — también va a revisión', () {
      final r = clasificar(
        texto: 'algo desconocido',
        reglasUsuario: const [],
        historialComercios: const {},
        clasificadorIA: (_) => null,
      );
      expect(r.nivel, NivelClasificacion.sinResolver);
      expect(r.marcadoParaRevision, isTrue);
    });

    test('texto vacío nunca resuelve, aunque haya reglas', () {
      final r = clasificar(
        texto: '   ',
        reglasUsuario: const [ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 1)],
        historialComercios: const {},
      );
      expect(r.categoriaId, isNull);
      expect(r.marcadoParaRevision, isTrue);
    });
  });

  test('resuelto es true solo cuando hay categoriaId', () {
    final sinResolver = clasificar(texto: 'x', reglasUsuario: const [], historialComercios: const {});
    expect(sinResolver.resuelto, isFalse);

    final resuelto = clasificar(
      texto: 'oxxo',
      reglasUsuario: const [ReglaAprendida(patron: 'oxxo', categoriaId: 'super', contador: 1)],
      historialComercios: const {},
    );
    expect(resuelto.resuelto, isTrue);
  });
}
