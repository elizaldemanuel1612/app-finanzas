import 'package:app_finanzas/domain/voz/seleccion_locale.dart';
import 'package:test/test.dart';

void main() {
  test('prefiere es_MX aunque no sea el primero en la lista', () {
    expect(
      seleccionarLocaleDictado(['en_US', 'es_ES', 'es_MX', 'fr_FR']),
      'es_MX',
    );
  });

  test('reconoce el guion como separador (es-MX)', () {
    expect(seleccionarLocaleDictado(['es-ES', 'es-MX']), 'es-MX');
  });

  test('sin es_MX, prefiere es_419 sobre cualquier otro es', () {
    expect(seleccionarLocaleDictado(['es_ES', 'es_419', 'es_AR']), 'es_419');
  });

  test('sin es_MX ni es_419, usa el primer "es" que encuentre', () {
    expect(seleccionarLocaleDictado(['en_US', 'es_ES', 'es_AR']), 'es_ES');
  });

  test('sin ningún locale en español, regresa null', () {
    expect(seleccionarLocaleDictado(['en_US', 'fr_FR']), isNull);
  });

  test('lista vacía regresa null', () {
    expect(seleccionarLocaleDictado(const []), isNull);
  });

  test('no distingue mayúsculas/minúsculas', () {
    expect(seleccionarLocaleDictado(['ES_MX']), 'ES_MX');
  });
}
