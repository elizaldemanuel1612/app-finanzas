import 'package:app_finanzas/ui/ayuda/contenido_guia.dart';
import 'package:app_finanzas/ui/ayuda/instructivo_ia.dart';
import 'package:test/test.dart';

// spec §6.5: el asistente contesta solo con la guía por temas.

void main() {
  test('completo: las reglas y todos los temas de la guía', () {
    final texto = instructivoDelAsistente();
    expect(texto, contains('SOLO con base en la GUÍA'));
    expect(texto, contains('asesoría financiera'));
    for (final seccion in guiaDeLaApp) {
      for (final tema in seccion.temas) {
        expect(texto, contains('## ${tema.titulo}'));
      }
    }
    expect(texto, contains('### Corte y fecha de pago'));
    expect(texto, contains('- **Débito:**'));
  });

  test('acotado: cabe en el tamaño y trae primero lo que se parece a la pregunta', () {
    final completo = instructivoDelAsistente().length;
    final corto = instructivoDelAsistente(pregunta: '¿Dónde pongo el día de corte de mi tarjeta de crédito?', maxCaracteres: 4000);
    expect(corto.length, lessThanOrEqualTo(4000 + 20));
    expect(corto.length, lessThan(completo));
    expect(corto, contains('## Cuentas y tarjetas'));
    // Sin espacio para temas, quedan solo las reglas.
    expect(instructivoDelAsistente(pregunta: 'x', maxCaracteres: 10), isNot(contains('## ')));
  });

  test('con datos: van antes de la guía, cambian la regla y cuentan para el tamaño', () {
    final sin = instructivoDelAsistente(pregunta: '¿cuánto llevo?');
    expect(sin, contains('No ves los datos'));
    expect(sin, isNot(contains('DATOS (calculados por la app)')));

    final con = instructivoDelAsistente(pregunta: '¿cuánto llevo?', datos: 'Total gastado en el ciclo (todo): \$4,860.');
    expect(con, isNot(contains('No ves los datos')));
    expect(con, contains('Son los únicos números que conoces'));
    expect(con.indexOf('DATOS (calculados por la app)'), lessThan(con.indexOf('GUÍA:')));
    expect(con, contains(r'$4,860'));
    expect(con, contains('No des asesoría financiera'));

    final corto = instructivoDelAsistente(pregunta: '¿cuánto llevo?', maxCaracteres: 6000, datos: 'x' * 1500);
    expect(corto.length, lessThanOrEqualTo(6000 + 20));
    expect(corto, contains('x' * 1500));
  });
}
