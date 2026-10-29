import '../exportacion/exportar_csv.dart';

/// Filas de ejemplo con los mismos encabezados y valores que escribe
/// `exportarMovimientosCsv`. La segunda muestra lo mínimo: las columnas
/// opcionales pueden ir vacías.
const _filasDeEjemplo = [
  ['2026-08-05 13:30', '450.00', 'Súper', '🛒', 'Compra de la quincena', 'Tarjeta', 'Activo', 'Manual', ''],
  ['2026-08-06', '85.50', 'Salidas', '', 'Café', 'Efectivo', '', '', ''],
];

/// Plantilla de ejemplo para "Descargar plantilla de ejemplo" (Bloque B):
/// mismos encabezados que [exportarMovimientosCsv] — para que lo que la
/// app exporta se pueda reimportar tal cual, y para que quien nunca ha
/// visto el formato sepa cuáles son las columnas esperadas.
String generarPlantillaCsvDeEjemplo() {
  final buffer = StringBuffer('﻿');
  buffer.writeln(encabezadosExportacion.join(','));
  for (final fila in _filasDeEjemplo) {
    buffer.writeln(fila.join(','));
  }
  return buffer.toString();
}

/// Qué va en cada columna, para la pantalla de importar y para pasárselo a
/// una IA junto con la plantilla. Mismo orden que [encabezadosExportacion].
const ayudaColumnasCsv = [
  ('Fecha', 'Obligatoria. 2026-08-05, 05/08/2026 o con hora: 2026-08-05 13:30.'),
  ('Monto', 'Obligatorio. Mayor a 0, sin signo: 450.00 o \$1,250.'),
  ('Categoría', 'Si no existe, se crea. Vacía: "Importado".'),
  ('Emoji', 'De la categoría nueva. Vacío: se elige uno por el nombre.'),
  ('Descripción', 'Texto libre. Vacía: el nombre de la categoría.'),
  ('Medio de pago', 'Tarjeta o Efectivo. Vacío: Tarjeta.'),
  ('Estado', 'Activo o Anulado (Pendiente solo si viene de exportar). Vacío: Activo.'),
  ('Cómo se registró', 'Lo llena la app al exportar. Puedes dejarlo vacío.'),
  ('ID', 'Lo llena la app al exportar; evita duplicados. Déjalo vacío en gastos nuevos.'),
];
