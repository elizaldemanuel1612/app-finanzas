import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';
import '../modelos/ciclo_guardado.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../modelos/snapshot_ciclo.dart';
import '../rollups/calcular_rollups.dart';
import 'ingresos_ciclo.dart';

/// Calcula el [SnapshotCiclo] que se congelaría si [ciclo] se cerrara
/// ahora, sin persistir nada todavía — [cerrarCiclo] hace eso con el
/// resultado de esta función.
///
/// Los renglones salen de reusar [calcularRollups] y mapear cada `Rollup`
/// agregando nombre y emoji: cero lógica de suma duplicada, y hereda
/// gratis el filtrado de anulados y propuestos (regla no negociable #3 y
/// #18).
///
/// [ingresos] trae el desglose base/extra ya sumado por
/// `calcularIngresosDelCiclo`; [metaBase] es lo que sale de
/// `calcularReparto(...).sinAsignar` — la meta antes de que el extra a
/// apartado la suba. El snapshot congela `metaApartado = metaBase +
/// ingresos.extraAApartado` (`calcularMetaDelCiclo`), nunca al revés.
///
/// Falla en dos casos:
/// - El ciclo ya está cerrado (delegado en [Ciclo.cerrar], que ya lo
///   valida).
/// - La suma de los renglones no cuadra con la suma de los movimientos
///   activos del ciclo. `calcularRollups` itera sobre `categorias`, así
///   que un movimiento cuyo `categoriaId` ya no exista se caería del total
///   **en silencio** — exactamente el descuadre que el criterio de
///   aceptación de la fase prohíbe. Hay que atraparlo antes de congelar,
///   no después (mismo espíritu que reconciliacion_nocturna.dart).
Resultado<SnapshotCiclo> calcularSnapshotCierre({
  required Ciclo ciclo,
  required List<Movimiento> movimientos,
  required List<Categoria> categorias,
  required IngresosDelCiclo ingresos,
  required Dinero metaBase,
  required DateTime fechaCierre,
}) {
  final puedeCerrarse = ciclo.cerrar();
  if (puedeCerrarse case Falla(:final mensaje)) return Falla(mensaje);

  final rollups = calcularRollups(
    movimientos: movimientos,
    categorias: categorias,
    cicloId: ciclo.id,
    ahora: fechaCierre,
  );
  final categoriasPorId = {for (final c in categorias) c.id: c};

  final renglones = [
    for (final rollup in rollups)
      RenglonSnapshot(
        categoriaId: rollup.categoriaId,
        nombre: categoriasPorId[rollup.categoriaId]!.nombre,
        emoji: categoriasPorId[rollup.categoriaId]!.emoji,
        presupuestoCentavos: rollup.presupuestoCentavos ?? const Dinero.cero(),
        realCentavos: rollup.totalCentavos,
        conteoMovimientos: rollup.conteoMovimientos,
      ),
  ];

  final totalRenglones = Dinero.suma(renglones.map((r) => r.realCentavos));
  final totalMovimientosActivos = Dinero.suma(
    movimientos
        .where((m) => m.cicloId == ciclo.id && m.estado == EstadoMovimiento.activo)
        .map((m) => m.monto),
  );

  if (totalRenglones != totalMovimientosActivos) {
    return Falla(
      'El cierre del ciclo ${ciclo.id} no cuadra: los renglones suman '
      '${totalRenglones.formateado()} pero los movimientos activos del '
      'ciclo suman ${totalMovimientosActivos.formateado()}. Revisa si hay '
      'un movimiento con una categoría que ya no existe.',
    );
  }

  final metaApartado = calcularMetaDelCiclo(metaBase: metaBase, ingresos: ingresos);

  return Exito(SnapshotCiclo(
    cicloId: ciclo.id,
    fechaCierre: fechaCierre,
    ingresoTotal: ingresos.total,
    metaApartado: metaApartado,
    totalGastado: totalRenglones,
    renglones: renglones,
    extraAApartado: ingresos.extraAApartado,
    extraAGasto: ingresos.extraAGasto,
  ));
}

/// Cierra [ciclo] con el [snapshot] ya calculado por [calcularSnapshotCierre]
/// y regresa el par listo para persistir.
Resultado<CicloGuardado> cerrarCiclo({
  required Ciclo ciclo,
  required SnapshotCiclo snapshot,
}) {
  final resultado = ciclo.cerrar();
  return switch (resultado) {
    Falla(:final mensaje) => Falla(mensaje),
    Exito(:final valor) => Exito(CicloGuardado(ciclo: valor, snapshot: snapshot)),
  };
}

/// Reabre explícitamente un ciclo cerrado (regla no negociable #6). El
/// snapshot anterior se **conserva** — no se borra al reabrir, así queda
/// rastro de que hubo una reapertura en vez de perderse. Si el ciclo se
/// vuelve a cerrar después, [cerrarCiclo] recalcula y sobrescribe.
Resultado<CicloGuardado> reabrirCiclo(CicloGuardado guardado) {
  final resultado = guardado.ciclo.reabrir();
  return switch (resultado) {
    Falla(:final mensaje) => Falla(mensaje),
    Exito(:final valor) =>
      Exito(CicloGuardado(ciclo: valor, snapshot: guardado.snapshot)),
  };
}
