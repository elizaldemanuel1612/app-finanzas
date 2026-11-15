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
}
