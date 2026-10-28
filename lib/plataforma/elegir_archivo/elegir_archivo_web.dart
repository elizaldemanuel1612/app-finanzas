import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../elegir_archivo.dart';

/// `<input type="file">` que se queda en la página hasta que llega
/// `change` (eligió) o `cancel` (cerró el selector). Sin heurística de
/// foco: en iPhone el archivo puede tardar segundos en llegar.
Future<ArchivoElegido?> elegirArchivo(List<String> extensiones) {
  final completer = Completer<ArchivoElegido?>();
  final entrada = web.HTMLInputElement()
    ..type = 'file'
    ..accept = [for (final e in extensiones) '.$e', if (extensiones.contains('csv')) 'text/csv'].join(',')
    ..style.display = 'none';

  void terminar(ArchivoElegido? resultado) {
    entrada.remove();
    if (!completer.isCompleted) completer.complete(resultado);
  }

  entrada.addEventListener(
    'change',
    (web.Event _) {
      final archivo = entrada.files?.item(0);
      if (archivo == null) {
        terminar(null);
        return;
      }
      archivo.arrayBuffer().toDart.then(
            (buffer) => terminar(ArchivoElegido(archivo.name, buffer.toDart.asUint8List())),
            onError: (Object e) {
              entrada.remove();
              if (!completer.isCompleted) completer.completeError(e);
            },
          );
    }.toJS,
  );
  entrada.addEventListener('cancel', ((web.Event _) => terminar(null)).toJS);

  web.document.body!.append(entrada);
  entrada.click();
  return completer.future;
}
