import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';

/// Un total por categoría y ciclo declarado en el Excel de origen — lo que
/// hay que cuadrar contra lo que la app calcula de los movimientos
/// importados (spec-app-finanzas-v2.md §8.1, paso 2–3).
final class TotalDeclarado {
  final String categoriaId;
  final String cicloId;
  final Dinero totalCentavos;

  const TotalDeclarado({
    required this.categoriaId,
    required this.cicloId,
    required this.totalCentavos,
  });
}

/// Una discrepancia entre lo declarado en el Excel y lo que la app calculó.
/// La migración nunca continúa mientras existan renglones aquí (spec-app-
/// finanzas-v2.md §8.1, paso 4: "si no cuadra al centavo, se detiene").
final class DiferenciaReconciliacion {
  final String categoriaId;
  final String cicloId;
  final Dinero totalDeclarado;
  final Dinero totalCalculado;

  const DiferenciaReconciliacion({
    required this.categoriaId,
    required this.cicloId,
    required this.totalDeclarado,
    required this.totalCalculado,
  });

  Dinero get diferencia => totalCalculado - totalDeclarado;

  @override
  String toString() => '$categoriaId/$cicloId: Excel dice '
      '${totalDeclarado.formateado()}, la app calculó '
      '${totalCalculado.formateado()} (diferencia ${diferencia.formateado()})';
}

String _clave(String categoriaId, String cicloId) => '$categoriaId|$cicloId';

/// Suma los movimientos activos importados, agrupados por categoría y
/// ciclo, y los compara contra [totalesDeclarados]. Regresa una diferencia
/// por cada combinación categoría/ciclo que no cuadre al centavo — lista
/// vacía significa que todo cuadró.
///
/// Los movimientos `anulados` no cuentan (no deberían existir recién
/// importados, pero si los hay, no son parte de lo que el Excel declaró
/// como gasto real).
List<DiferenciaReconciliacion> encontrarDiferencias({
  required List<Movimiento> movimientosImportados,
  required List<TotalDeclarado> totalesDeclarados,
}) {
  final calculado = <String, Dinero>{};
  for (final m in movimientosImportados) {
    if (m.estado == EstadoMovimiento.anulado) continue;
    final clave = _clave(m.categoriaId, m.cicloId);
    calculado[clave] = (calculado[clave] ?? const Dinero.cero()) + m.monto;
  }

  final diferencias = <DiferenciaReconciliacion>[];
  final clavesVistas = <String>{};

  for (final declarado in totalesDeclarados) {
    final clave = _clave(declarado.categoriaId, declarado.cicloId);
    clavesVistas.add(clave);
    final total = calculado[clave] ?? const Dinero.cero();
    if (total != declarado.totalCentavos) {
      diferencias.add(DiferenciaReconciliacion(
        categoriaId: declarado.categoriaId,
        cicloId: declarado.cicloId,
        totalDeclarado: declarado.totalCentavos,
        totalCalculado: total,
      ));
    }
  }

  // Categoría/ciclo con movimientos importados pero sin total declarado en
  // el Excel: también es una discrepancia — algo se importó que el Excel
  // no reconoce.
  for (final entrada in calculado.entries) {
    if (clavesVistas.contains(entrada.key)) continue;
    final partes = entrada.key.split('|');
    diferencias.add(DiferenciaReconciliacion(
      categoriaId: partes[0],
      cicloId: partes[1],
      totalDeclarado: const Dinero.cero(),
      totalCalculado: entrada.value,
    ));
  }

  return diferencias;
}

/// Compuerta de la migración (spec-app-finanzas-v2.md §8.1, paso 4): si
/// [encontrarDiferencias] regresa algo, la migración se detiene.
Resultado<void> validarReconciliacion({
  required List<Movimiento> movimientosImportados,
  required List<TotalDeclarado> totalesDeclarados,
}) {
  final diferencias = encontrarDiferencias(
    movimientosImportados: movimientosImportados,
    totalesDeclarados: totalesDeclarados,
  );
  if (diferencias.isEmpty) return const Exito(null);

  final detalle = diferencias.map((d) => d.toString()).join(' · ');
  return Falla(
    'La migración no cuadra al centavo en ${diferencias.length} '
    'renglón(es): $detalle',
  );
}
