import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../modelos/ciclo_guardado.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/ingreso_extra.dart';
import '../modelos/movimiento.dart';
import '../modelos/snapshot_ciclo.dart';
import 'ingresos_ciclo.dart';

/// Resumen de un ciclo pasado para la lista de "Ciclos anteriores": trae
/// el [Ciclo] completo (persistido o reconstruido) y cuánto se gastó, sin
/// cargar todo el detalle de renglones — eso lo resuelve
/// `PantallaCierreCiclo` al abrir el ciclo.
final class CicloResumen {
  final Ciclo ciclo;

  /// La fotografía congelada del cierre, si existe. `null` si el ciclo se
  /// reconstruyó al vuelo desde movimientos sin cierre formal. Se guarda el
  /// snapshot completo (no solo un `bool`) para que `calcularEvolucionCiclos`
  /// pueda sacar de aquí mismo los cinco valores que pide
  /// `calcularMetricasApartado`, sin volver a tocar repositorios.
  final SnapshotCiclo? snapshot;
  final Dinero totalGastado;

  /// Cuánto ingreso extra tuvo el ciclo — un [Dinero] y no un `bool`:
  /// pintar "+$15,000" en la lista es mejor que una palomita (regla no
  /// negociable #14: "los ciclos con ingreso extra van marcados").
  final Dinero ingresoExtra;

  const CicloResumen({
    required this.ciclo,
    required this.snapshot,
    required this.totalGastado,
    this.ingresoExtra = const Dinero.cero(),
  });

  bool get tieneSnapshot => snapshot != null;
  bool get tuvoIngresoExtra => ingresoExtra.esPositivo;

  @override
  bool operator ==(Object other) =>
      other is CicloResumen &&
      other.ciclo == ciclo &&
      other.snapshot == snapshot &&
      other.totalGastado == totalGastado &&
      other.ingresoExtra == ingresoExtra;

  @override
  int get hashCode => Object.hash(ciclo, snapshot, totalGastado, ingresoExtra);
}

/// Reconcilia lo persistido en `CicloRepositorio` con lo que solo dejó
/// rastro en `MovimientoRepositorio` para armar la lista de ciclos
/// pasados (excluye [cicloActualId]).
///
/// `CicloRepositorio.listarTodos()` solo trae los ciclos que pasaron por
/// el flujo de cierre — uno que venció sin que el usuario lo cerrara no
/// tiene ningún registro ahí, aunque sus movimientos sigan intactos. Por
/// eso hacen falta las dos fuentes: se reconstruye el resto al vuelo.
///
/// Pura: recibe los datos ya cargados, no toca repositorios.
///
/// **Limitación conocida:** si `diaCorte` del perfil cambiara alguna vez
/// (hoy no hay UI para editarlo después del onboarding), la
/// reconstrucción de ciclos viejos usaría el `diaCorte` de hoy contra
/// fechas antiguas y podría desplazar los límites. No se resuelve aquí.
List<CicloResumen> calcularHistorialCiclos({
  required List<CicloGuardado> ciclosGuardados,
  required List<Movimiento> todosLosMovimientos,
  required List<IngresoExtra> todosLosIngresosExtra,
  required CalculadoraCiclo calculadoraCiclo,
  required String cicloActualId,
}) {
  final guardadosPorId = {for (final g in ciclosGuardados) g.ciclo.id: g};

  final movimientosPorCiclo = <String, List<Movimiento>>{};
  for (final m in todosLosMovimientos) {
    movimientosPorCiclo.putIfAbsent(m.cicloId, () => []).add(m);
  }

  final idsCandidatos = <String>{
    ...guardadosPorId.keys,
    ...movimientosPorCiclo.keys,
  }..remove(cicloActualId);

  final resumenes = <CicloResumen>[];
  for (final id in idsCandidatos) {
    final guardado = guardadosPorId[id];
    final movimientosDelCiclo = movimientosPorCiclo[id] ?? const <Movimiento>[];
    final snapshot = guardado?.snapshot;

    final CicloResumen resumen;
    if (snapshot != null) {
      // Cierre formal: la fotografía congelada gana siempre, nunca se
      // recalcula (misma regla que sigue PantallaCierreCiclo).
      resumen = CicloResumen(
        ciclo: guardado!.ciclo,
        snapshot: snapshot,
        totalGastado: snapshot.totalGastado,
        ingresoExtra: snapshot.ingresoExtra,
      );
    } else {
      final ciclo = movimientosDelCiclo.isNotEmpty
          ? calculadoraCiclo.calcularPara(movimientosDelCiclo.first.fecha)
          : guardado!.ciclo;
      final total = Dinero.suma(
        movimientosDelCiclo
            .where((m) => m.estado == EstadoMovimiento.activo)
            .map((m) => m.monto),
      );
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.cero(),
        cicloId: ciclo.id,
        extras: todosLosIngresosExtra,
      );
      resumen = CicloResumen(
        ciclo: ciclo,
        snapshot: null,
        totalGastado: total,
        ingresoExtra: ingresos.extraTotal,
      );
    }
    resumenes.add(resumen);
  }

  resumenes.sort((a, b) => b.ciclo.fechaInicio.compareTo(a.ciclo.fechaInicio));
  return resumenes;
}
