import '../exportacion/exportar_csv.dart';
import 'csv.dart';

/// Instrucciones para la IA a la que el usuario le pase la plantilla junto
/// con sus gastos: viajan dentro del archivo, antes de los encabezados. La
/// importación ignora estas líneas ([esRenglonDeInstrucciones]), así que no
/// pasa nada si la IA las deja. Sin comillas dobles a propósito: una suelta
/// rompería la lectura del CSV.
const instruccionesParaIA = [
  'INSTRUCCIONES PARA LA IA: convierte los gastos del usuario a este formato para importarlos en la app MAVfin.',
  'ARCHIVO: entrega un archivo .csv (texto plano) en UTF-8, separado por comas. No lo entregues como Excel (.xlsx), PDF ni tabla en el chat.',
  'ENCABEZADOS: conserva exactamente el renglón de encabezados: mismos nombres, mismo orden y las 9 columnas. No agregues columnas. Cada gasto va en un renglón.',
  'VACÍOS: si un dato no se conoce, deja la celda vacía pero conserva sus comas. Nunca inventes datos.',
  'TEXTO CON COMAS: si una descripción o categoría lleva coma, enciérrala entre comillas dobles.',
  'Fecha (obligatoria): usa siempre aaaa-mm-dd, por ejemplo 2026-08-05. Si conoces la hora: aaaa-mm-dd HH:mm.',
  'Monto (obligatorio): número mayor a 0, con punto decimal, sin signo de pesos, sin comas de miles y sin negativos. Ejemplo: 1250.00. No incluyas ingresos ni depósitos.',
  'Categoría: usa siempre el mismo nombre para la misma categoría, escrito igual, sin emoji. Si no puedes deducirla, déjala vacía.',
  'Emoji: pon exactamente un emoji que corresponda al nombre de la categoría, por ejemplo 🛒 para Súper o 🚗 para Auto. Usa el mismo emoji en todos los renglones de esa categoría.',
  'Descripción: texto libre con el comercio o concepto. Puede ir vacía.',
  'Medio de pago: solo se permite Tarjeta o Efectivo, escrito así. Si no se sabe, déjalo vacío.',
  'Estado: solo se permite Activo o Anulado, escrito así. Usa Anulado solo si el gasto se canceló o devolvió; si no, Activo.',
  'Cómo se registró: déjalo vacío.',
  'ID: déjalo vacío.',
  'Borra los dos renglones de ejemplo de abajo. Estas líneas que empiezan con el signo de número se pueden quedar o borrar; la app las ignora.',
];

/// Filas de ejemplo con los mismos encabezados y valores que escribe
/// `exportarMovimientosCsv`. La segunda muestra que lo que llena la app
/// (Cómo se registró, ID) puede ir vacío.
const _filasDeEjemplo = [
  ['2026-08-05 13:30', '450.00', 'Súper', '🛒', 'Compra de la quincena', 'Tarjeta', 'Activo', 'Manual', ''],
  ['2026-08-06', '85.50', 'Salidas', '🍿', 'Café', 'Efectivo', 'Activo', '', ''],
];

/// Plantilla de ejemplo para "Descargar plantilla de ejemplo" (Bloque B):
/// mismos encabezados que [exportarMovimientosCsv] — para que lo que la
/// app exporta se pueda reimportar tal cual, y para que quien nunca ha
/// visto el formato sepa cuáles son las columnas esperadas. Empieza con
/// [instruccionesParaIA]; lo exportado no las lleva.
String generarPlantillaCsvDeEjemplo() {
  final buffer = StringBuffer('﻿');
  for (final instruccion in instruccionesParaIA) {
    buffer.writeln('$marcaDeInstrucciones $instruccion');
  }
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
  ('Categoría', 'Si no existe, se crea. Vacía: se adivina por la descripción; si no se puede, va a "Sin categoría".'),
  ('Emoji', 'De la categoría nueva. Vacío: se elige uno por el nombre.'),
  ('Descripción', 'Texto libre. Vacía: el nombre de la categoría.'),
  ('Medio de pago', 'Tarjeta o Efectivo. Vacío: Tarjeta.'),
  ('Estado', 'Activo o Anulado (Pendiente solo si viene de exportar). Vacío: Activo.'),
  ('Cómo se registró', 'Lo llena la app al exportar. Puedes dejarlo vacío.'),
  ('ID', 'Lo llena la app al exportar; evita duplicados. Déjalo vacío en gastos nuevos.'),
];
