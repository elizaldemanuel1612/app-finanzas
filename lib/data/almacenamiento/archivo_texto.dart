/// Un "archivo" de texto donde la app guarda un JSON. En el teléfono es un
/// archivo real (`ArchivoTextoDisco`); en la web, una entrada del
/// almacenamiento del navegador (`ArchivoTextoNavegador`). Los
/// repositorios solo conocen esta interfaz, así que funcionan igual en las
/// tres plataformas (spec-app-finanzas-v2.md §4.2.2).
///
/// Sin `dart:io`: este archivo se importa también en la web.
abstract interface class ArchivoTexto {
  /// `null` si todavía no existe.
  Future<String?> leer();

  /// Reemplaza el contenido completo, de forma atómica.
  Future<void> escribir(String contenido);

  /// No es error si no existía.
  Future<void> borrar();
}

/// Para pruebas y para la memoria temporal: vive solo mientras corre la app.
final class ArchivoTextoMemoria implements ArchivoTexto {
  String? contenido;

  ArchivoTextoMemoria([this.contenido]);

  @override
  Future<String?> leer() async => contenido;

  @override
  Future<void> escribir(String contenido) async => this.contenido = contenido;

  @override
  Future<void> borrar() async => contenido = null;
}
