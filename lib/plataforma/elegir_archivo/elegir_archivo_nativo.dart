import 'package:file_picker/file_picker.dart';

import '../elegir_archivo.dart';

Future<ArchivoElegido?> elegirArchivo(List<String> extensiones) async {
  final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensiones);
  if (archivo == null) return null;
  return ArchivoElegido(archivo.name, await archivo.readAsBytes());
}
