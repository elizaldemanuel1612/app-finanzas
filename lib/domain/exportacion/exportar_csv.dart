import '../modelos/categoria.dart';
import '../modelos/categoria_ingreso.dart';
import '../modelos/cuenta.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../modelos/movimiento_cuenta.dart';

/// Pública para que `domain/importacion/plantilla_csv.dart` genere la
/// plantilla de ejemplo con los mismos encabezados — lo que la app exporta
/// se puede reimportar tal cual. Las obligatorias van primero; lo demás es
/// opcional al importar (2026-10-29: Emoji, ID y valores en español;
/// 2026-10-31: el plan de cada categoría, spec-app-finanzas-v2.md §7.4).
const encabezadosExportacion = [
  'Fecha',
  'Monto',
  'Categoría',
  'Emoji',
  'Presupuesto',
  'Tipo',
  'Día de cobro',
  'Necesaria',
  'Activa',
  'Descripción',
  'Medio de pago',
  'Cuenta',
  'Estado',
  'Cómo se registró',
  'ID',
  // Al final, para no mover las columnas de antes (2026-11-16, §7.3.1).
  'Meses',
];

/// Cómo se escribe cada valor en el CSV, en palabras que entiende quien
/// lo abre en una hoja de cálculo. La importación lee estas mismas
/// etiquetas (y también los nombres internos de antes, `activo`, `manual`…).
const etiquetaMedio = {
  MedioPago.tarjeta: 'Tarjeta',
  MedioPago.efectivo: 'Efectivo',
};

const etiquetaEstado = {
  EstadoMovimiento.activo: 'Activo',
  EstadoMovimiento.propuesto: 'Pendiente',
  EstadoMovimiento.anulado: 'Anulado',
};

const etiquetaOrigen = {
  OrigenCaptura.manual: 'Manual',
  OrigenCaptura.voz: 'Voz',
  OrigenCaptura.ticket: 'Ticket',
  OrigenCaptura.recurrente: 'Recurrente',
  OrigenCaptura.migracion: 'Importado',
};

/// Exportación de movimientos a CSV (spec-app-finanzas-v2.md §7.4,
/// paquete-construccion-final.md §8: "Exportar/compartir → API de Flutter,
/// igual en ambas"). Dart puro para poder probarse con `dart test` y
/// mantener el 100% de cobertura de `domain/`.
///
/// Exporta todo, también lo anulado y lo pendiente (con su estado), para
/// que reimportar no reviva un gasto que el usuario había quitado. El ID
/// es el `clientId`: reimportar en la misma cuenta no duplica nada.
///
/// RFC 4180: campos con coma, comilla o salto de línea van entre comillas,
/// con las comillas internas duplicadas. Los montos se exportan como texto
/// plano (`1234.56`, sin símbolo ni separador de miles) para que la hoja
/// de cálculo los lea como número, no como texto. Incluye BOM UTF-8 al
/// inicio para que Excel no destroce los acentos del español.
String exportarMovimientosCsv({
  required List<Movimiento> movimientos,
  required List<Categoria> categorias,
  List<Cuenta> cuentas = const [],
}) {
  final cuentaPorId = {for (final c in cuentas) c.id: c};
  final categoriasPorId = {for (final c in categorias) c.id: c};
  final conGastos = {for (final m in movimientos) m.categoriaId};
  final buffer = StringBuffer('\uFEFF');
  buffer.writeln(encabezadosExportacion.map(_celda).join(','));

  for (final m in movimientos) {
    final categoria = categoriasPorId[m.categoriaId];
    final fila = [
      fechaParaCsv(m.fecha),
      _montoPlano(m.monto.centavos),
      ..._columnasDeCategoria(categoria, m.categoriaId),
      _neutralizarFormula(m.descripcion),
      etiquetaMedio[m.medio]!,
      _neutralizarFormula(cuentaPorId[cuentaDe(m)]?.nombre ?? ''),
      etiquetaEstado[m.estado]!,
      etiquetaOrigen[m.origenCaptura]!,
      _neutralizarFormula(m.clientId),
      m.esAMeses ? textoDeMensualidad(m.mensualidad!, m.meses!, diferido: m.diferido) : '',
    ];
    buffer.writeln(fila.map(_celda).join(','));
  }

  // Una categoría sin gastos también es parte del plan: como importar deja
  // solo lo que viene en el archivo, sin este renglón se perdería.
  for (final c in categorias) {
    if (conGastos.contains(c.id)) continue;
    final fila = ['', '', ..._columnasDeCategoria(c, c.id), '', '', '', '', '', '', ''];
    buffer.writeln(fila.map(_celda).join(','));
  }

  return buffer.toString();
}

/// Encabezados del segundo archivo: lo que entra o se mueve entre cuentas
/// sin ser gasto (spec-app-finanzas-v2.md §7.4, 2026-11-16): ingresos,
/// ajustes de saldo y transferencias, con su categoría de ingreso.
const encabezadosMovimientosCuenta = [
  'Fecha',
  'Tipo',
  'Monto',
  'Cuenta',
  'Hacia la cuenta',
  'Categoría de ingreso',
  'Nota',
  'Estado',
  'ID',
];

const etiquetaTipoMovimientoCuenta = {
  TipoMovimientoCuenta.abono: 'Ingreso',
  TipoMovimientoCuenta.ajuste: 'Ajuste de saldo',
  TipoMovimientoCuenta.transferencia: 'Transferencia',
};

/// Ingresos, ajustes y transferencias a CSV, con las mismas reglas que
/// [exportarMovimientosCsv] (BOM, RFC 4180, fórmulas neutralizadas, todo
/// incluido lo anulado). El monto lleva signo solo en un ajuste que baja
/// el saldo; una transferencia sale de "Cuenta" hacia "Hacia la cuenta".
String exportarMovimientosCuentaCsv({
  required List<MovimientoCuenta> movimientos,
  List<Cuenta> cuentas = const [],
  List<CategoriaIngreso> categoriasIngreso = const [],
}) {
  final cuentaPorId = {for (final c in cuentas) c.id: c.nombre};
  final categoriaPorId = {for (final c in categoriasIngreso) c.id: c.nombre};
  final buffer = StringBuffer('\uFEFF');
  buffer.writeln(encabezadosMovimientosCuenta.map(_celda).join(','));
  final ordenados = [...movimientos]..sort((a, b) => a.fecha.compareTo(b.fecha));
  for (final m in ordenados) {
    final fila = [
      fechaParaCsv(m.fecha),
      etiquetaTipoMovimientoCuenta[m.tipo]!,
      _montoPlano(m.tipo == TipoMovimientoCuenta.ajuste ? m.efecto.centavos : m.monto.centavos),
      _neutralizarFormula(cuentaPorId[m.cuentaId] ?? m.cuentaId),
      _neutralizarFormula(m.cuentaDestinoId == null ? '' : cuentaPorId[m.cuentaDestinoId] ?? m.cuentaDestinoId!),
      _neutralizarFormula(m.categoriaIngresoId == null ? '' : categoriaPorId[m.categoriaIngresoId] ?? ''),
      _neutralizarFormula(m.nota),
      m.estado == EstadoMovimientoCuenta.anulado ? 'Anulado' : 'Activo',
      _neutralizarFormula(m.clientId),
    ];
    buffer.writeln(fila.map(_celda).join(','));
  }
  return buffer.toString();
}

List<String> _columnasDeCategoria(Categoria? categoria, String idSiNoExiste) => switch (categoria) {
      null => [_neutralizarFormula(idSiNoExiste), '', '', '', '', '', ''],
      CategoriaFija c => [
          _neutralizarFormula(c.nombre),
          _neutralizarFormula(c.emoji),
          _montoPlano(c.montoFijoCentavos.centavos),
          'Fija',
          '${c.diaDelCiclo}',
          _siNo(c.esNecesaria),
          _siNo(c.activa),
        ],
      CategoriaVariable c => [
          _neutralizarFormula(c.nombre),
          _neutralizarFormula(c.emoji),
          _montoPlano(c.presupuestoMensualCentavos.centavos),
          'Variable',
          '',
          _siNo(c.esNecesaria),
          _siNo(c.activa),
        ],
    };

String _siNo(bool valor) => valor ? 'Sí' : 'No';

/// "2 de 12": la columna Meses (spec §7.3.1). Si el primer pago se difirió
/// ("empieza a pagar en 3 meses"), "1 de 12, diferido 3". La importación
/// la lee con [leerMensualidad].
String textoDeMensualidad(int mensualidad, int meses, {int? diferido}) =>
    '$mensualidad de $meses${diferido == null || diferido == 0 ? '' : ', diferido $diferido'}';

/// Lo inverso de [textoDeMensualidad]: (mensualidad, meses, diferido —0 si
/// no—); `null` si no se entiende o no tiene sentido (la mensualidad pasa
/// del plazo, el plazo de 2 a 48 —de 1 si es diferido— o el diferido pasa
/// de 12).
(int, int, int)? leerMensualidad(String texto) {
  final m = RegExp(r'^\s*(\d+)\s*(?:de|/)\s*(\d+)\s*(?:,\s*diferido\s*(\d+)(?:\s*mes(?:es)?)?\s*)?$')
      .firstMatch(texto.toLowerCase());
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  final de = int.parse(m.group(2)!);
  final diferido = m.group(3) == null ? 0 : int.parse(m.group(3)!);
  if (diferido > 12) return null;
  if (n < 1 || n > de || de < (diferido > 0 ? 1 : 2) || de > 48) return null;
  return (n, de, diferido);
}

/// `aaaa-mm-dd`, y la hora (`aaaa-mm-dd HH:mm`) solo si la tiene: así la
/// hoja de cálculo la reconoce como fecha y el orden del día se conserva.
String fechaParaCsv(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final dia = '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)}';
  if (fecha.hour == 0 && fecha.minute == 0) return dia;
  return '$dia ${dos(fecha.hour)}:${dos(fecha.minute)}';
}

String _montoPlano(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final pesos = abs ~/ 100;
  final resto = (abs % 100).toString().padLeft(2, '0');
  return '${negativo ? '-' : ''}$pesos.$resto';
}

/// Inyección de fórmulas en CSV (OWASP): categoría y descripción son texto
/// libre del usuario. Si el valor llega a una hoja de cálculo empezando con
/// `=`, `+`, `-`, `@` o tab, Excel/Sheets lo puede interpretar como fórmula
/// en vez de texto — un movimiento llamado `=HYPERLINK(...)` o `@SUM(...)`
/// se ejecutaría al abrir el CSV. Anteponer una comilla simple lo fuerza a
/// texto. No se aplica a `_montoPlano` (los negativos empiezan con `-` a
/// propósito, para que la hoja los lea como número) ni a los campos que
/// vienen de etiquetas propias (medio, estado, cómo se registró). La
/// importación quita esa comilla al leer (`quitarNeutralizacion`).
const _caracteresDeFormula = {'=', '+', '-', '@', '\t', '\r'};

String _neutralizarFormula(String valor) {
  if (valor.isEmpty || !_caracteresDeFormula.contains(valor[0])) return valor;
  return "'$valor";
}

/// Inverso de la neutralización: `'=algo` vuelve a `=algo` al importar.
String quitarNeutralizacion(String valor) {
  if (valor.length > 1 && valor[0] == "'" && _caracteresDeFormula.contains(valor[1])) {
    return valor.substring(1);
  }
  return valor;
}

String _celda(String valor) {
  final necesitaComillas =
      valor.contains(',') || valor.contains('"') || valor.contains('\n') || valor.contains('\r');
  if (!necesitaComillas) return valor;
  return '"${valor.replaceAll('"', '""')}"';
}
