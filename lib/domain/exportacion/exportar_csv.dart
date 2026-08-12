import '../modelos/categoria.dart';
import '../modelos/movimiento.dart';

const _encabezados = [
  'Fecha',
  'Categoría',
  'Descripción',
  'Monto',
  'Medio de pago',
  'Estado',
  'Origen de captura',
];

/// Exportación de movimientos a CSV (spec-app-finanzas-v2.md §7.4,
/// paquete-construccion-final.md §8: "Exportar/compartir → API de Flutter,
/// igual en ambas"). Dart puro para poder probarse con `dart test` y
/// mantener el 100% de cobertura de `domain/`.
///
/// RFC 4180: campos con coma, comilla o salto de línea van entre comillas,
/// con las comillas internas duplicadas. Los montos se exportan como texto
/// plano (`1234.56`, sin símbolo ni separador de miles) para que la hoja
/// de cálculo los lea como número, no como texto. Incluye BOM UTF-8 al
/// inicio para que Excel no destroce los acentos del español.
String exportarMovimientosCsv({
  required List<Movimiento> movimientos,
  required List<Categoria> categorias,
}) {
  final categoriasPorId = {for (final c in categorias) c.id: c};
  final buffer = StringBuffer('﻿');
  buffer.writeln(_encabezados.map(_celda).join(','));

  for (final m in movimientos) {
    final categoria = categoriasPorId[m.categoriaId];
    final fila = [
      m.fecha.toIso8601String(),
      _neutralizarFormula(categoria?.nombre ?? m.categoriaId),
      _neutralizarFormula(m.descripcion),
      _montoPlano(m.monto.centavos),
      m.medio.name,
      m.estado.name,
      m.origenCaptura.name,
    ];
    buffer.writeln(fila.map(_celda).join(','));
  }

  return buffer.toString();
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
/// vienen de enums propios (`medio`, `estado`, `origenCaptura`).
const _caracteresDeFormula = {'=', '+', '-', '@', '\t', '\r'};

String _neutralizarFormula(String valor) {
  if (valor.isEmpty || !_caracteresDeFormula.contains(valor[0])) return valor;
  return "'$valor";
}

String _celda(String valor) {
  final necesitaComillas =
      valor.contains(',') || valor.contains('"') || valor.contains('\n') || valor.contains('\r');
  if (!necesitaComillas) return valor;
  return '"${valor.replaceAll('"', '""')}"';
}
