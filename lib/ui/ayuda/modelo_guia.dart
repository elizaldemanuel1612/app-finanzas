/// Modelo de la guía por temas (Ajustes → "Cómo funciona la app").
///
/// Este archivo **no importa Flutter** a propósito, aunque viva en
/// `lib/ui/`: la guía es presentación, no reglas de negocio, así que no
/// pertenece a `domain/` (que exige 100% de cobertura y prohíbe Flutter,
/// ver `test/domain/arquitectura_test.dart`) — pero mantenerlo en Dart
/// puro permite que `test/ayuda/contenido_guia_test.dart` valide el
/// contenido con `dart test`, sin necesitar un dispositivo ni
/// `flutter_test`.
library;

/// Un grupo de temas afines en el índice de la guía (p. ej. "Lo básico").
final class SeccionGuia {
  final String titulo;
  final List<TemaGuia> temas;

  const SeccionGuia({required this.titulo, required this.temas});
}

/// Un tema individual de la guía — una pantalla completa en
/// `PantallaTemaGuia`.
final class TemaGuia {
  final String id;
  final String emoji;
  final String titulo;
  final String resumen;
  final List<BloqueGuia> bloques;

  const TemaGuia({
    required this.id,
    required this.emoji,
    required this.titulo,
    required this.resumen,
    required this.bloques,
  });
}

/// Los tipos de contenido que puede traer un tema. Sellado a propósito:
/// `BloqueGuiaWidget` (en `bloques_guia.dart`) hace un `switch` exhaustivo
/// sobre estos casos, así que el compilador obliga a añadir un renderer
/// cada vez que se agrega un tipo de bloque nuevo aquí.
sealed class BloqueGuia {
  const BloqueGuia();
}

/// Texto corrido. Soporta `**negrita**` en el render.
final class Parrafo extends BloqueGuia {
  final String texto;
  const Parrafo(this.texto);
}

/// Subtítulo dentro de un tema, para partirlo en secciones cortas.
final class Subtitulo extends BloqueGuia {
  final String texto;
  const Subtitulo(this.texto);
}

/// Lista de puntos sin orden.
final class Vinetas extends BloqueGuia {
  final List<String> puntos;
  const Vinetas(this.puntos);
}

/// Lista de pasos, numerada.
final class Pasos extends BloqueGuia {
  final List<String> pasos;
  const Pasos(this.pasos);
}

/// El callout `NotaDestacada` (`lib/ui/comun/nota_destacada.dart`).
final class Nota extends BloqueGuia {
  final String etiqueta;
  final String texto;
  final TonoNota tono;
  const Nota({required this.etiqueta, required this.texto, this.tono = TonoNota.info});
}

/// Un ejemplo vivo (una `BarraRitmo` real, una miniatura de renglón…).
///
/// Es un `enum`, no un `Widget Function(BuildContext)`: así el catálogo se
/// mantiene `const` de punta a punta, `dart test` puede probar que cada
/// valor se usa al menos una vez, y `BloqueGuiaWidget` hace un `switch`
/// exhaustivo que obliga a dibujar cada ejemplo nuevo.
enum EjemploGuia {
  barraVasBien,
  barraExcedido,
  barraProyeccion,
  tarjetaAtencion,
  chipsDeFecha,
  deslizarMovimiento,
}

final class Ejemplo extends BloqueGuia {
  final EjemploGuia cual;
  final String? pie;
  const Ejemplo(this.cual, {this.pie});
}

/// Tono de [Nota] / `NotaDestacada`: define el color de borde y de
/// etiqueta, nunca el color del texto del cuerpo.
enum TonoNota { info, ojo, tip }
