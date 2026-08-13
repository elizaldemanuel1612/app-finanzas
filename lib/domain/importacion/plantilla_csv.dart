import '../exportacion/exportar_csv.dart';

/// Fila de ejemplo: fecha ISO 8601, monto sin símbolo ni separador de
/// miles (mismo formato que escribe `exportarMovimientosCsv`), medio como
/// lo reconoce `previsualizarImportacion`. "Estado" y "Origen de captura"
/// se dejan igual que en una fila exportada aunque la importación no los
/// lea — son parte de los mismos encabezados, no de lo que se detecta.
const _filaDeEjemplo = [
  '2026-08-05',
  'Súper',
  'Compra de la quincena',
  '450.00',
  'tarjeta',
  'activo',
  'manual',
];

/// Plantilla de ejemplo para "Descargar plantilla de ejemplo" (Bloque B):
/// mismos encabezados que [exportarMovimientosCsv] — para que lo que la
/// app exporta se pueda reimportar tal cual, y para que quien nunca ha
/// visto el formato sepa cuáles son las columnas esperadas.
String generarPlantillaCsvDeEjemplo() {
  final buffer = StringBuffer('﻿');
  buffer.writeln(encabezadosExportacion.join(','));
  buffer.writeln(_filaDeEjemplo.join(','));
  return buffer.toString();
}
