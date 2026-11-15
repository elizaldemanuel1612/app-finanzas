import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/clasificacion/cascada_clasificacion.dart';
import 'package:app_finanzas/domain/ia/clasificacion_ia.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:test/test.dart';

CategoriaVariable _var(String id, String nombre, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
      presupuestoMensualCentavos: Dinero.pesos(1000),
    );

void main() {
  final categorias = [_var('super', 'Súper'), _var('auto', 'Auto'), _var('viejo', 'Viejo', activa: false)];

  test('el mensaje lleva solo la nota y las categorías activas', () {
    final m = mensajeClasificacion('  membresía de Costco ', categorias);
    expect(m, contains('"membresía de Costco"'));
    expect(m, contains('- Súper'));
    expect(m, isNot(contains('Viejo')));
    expect(instruccionesClasificacion, contains('JSON'));
  });

  test('entiende la respuesta aunque venga con texto o acentos distintos', () {
    final r = interpretarClasificacion('Claro:\n```json\n{"categoria": "super", "confianza": 0.93}\n```', categorias)!;
    expect(r.categoriaId, 'super');
    expect(r.confianza, 0.93);
    expect(interpretarClasificacion('{"categoria": "Auto", "confianza": 7}', categorias)!.confianza, 1.0);
  });

  test('null si no se entiende, no eligió ninguna o nombró otra', () {
    expect(interpretarClasificacion('no sé', categorias), isNull);
    expect(interpretarClasificacion('{roto}', categorias), isNull);
    expect(interpretarClasificacion('[1]', categorias), isNull);
    expect(interpretarClasificacion('{"categoria": null, "confianza": 0.2}', categorias), isNull);
    expect(interpretarClasificacion('{"categoria": "Mascotas", "confianza": 0.9}', categorias), isNull);
    expect(interpretarClasificacion('{"categoria": "Viejo", "confianza": 0.9}', categorias), isNull);
    expect(interpretarClasificacion('{"categoria": "Auto", "confianza": "alta"}', categorias), isNull);
    expect(interpretarClasificacion('{"x": 1} y [', categorias), isNull);
  });

  test('los umbrales de §6.3 sobre lo que dijo la IA', () {
    final alta = cascadaDesdeIA(const ResultadoIA(categoriaId: 'super', confianza: 0.95));
    expect((alta.categoriaId, alta.requiereConfirmacion, alta.nivel), ('super', false, NivelClasificacion.ia));
    final media = cascadaDesdeIA(const ResultadoIA(categoriaId: 'super', confianza: 0.7));
    expect((media.categoriaId, media.requiereConfirmacion), ('super', true));
    final baja = cascadaDesdeIA(const ResultadoIA(categoriaId: 'super', confianza: 0.3));
    expect((baja.resuelto, baja.marcadoParaRevision), (false, true));
  });
}
