import '../../core/ciclo.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'pronostico_categoria.dart';
import 'punto_monto.dart';

/// Pegamento entre `Movimiento` (lo que persisten los repositorios) y las
/// entradas que espera el MPC (`domain/pronostico/pronostico_categoria.dart`).
/// Vivía duplicado como funciones privadas de
/// `ui/categorias/pantalla_detalle_categoria.dart` — sacarlo a `domain/`
/// es lo que permite que `test/paridad/` ejerza el mismo camino que la UI
/// en vez de reimplementarlo (paquete-construccion-final.md §3.2).
///
/// Ciclos cerrados de [categoriaId] a partir de todos los movimientos —
/// cualquier `cicloId` distinto a [cicloActualId] se trata como histórico
/// cerrado (ver nota de clase de `PantallaDetalleCategoria` sobre "ciclo
/// cerrado" mientras esa noción no exista como estado gestionado).
List<CicloCerradoHistorico> ciclosCerradosDeCategoria({
  required List<Movimiento> todos,
  required String categoriaId,
  required String cicloActualId,
}) {
  final porCiclo = <String, List<Movimiento>>{};
  for (final m in todos) {
    if (m.categoriaId != categoriaId) continue;
    if (m.estado != EstadoMovimiento.activo) continue;
    if (m.cicloId == cicloActualId) continue;
    porCiclo.putIfAbsent(m.cicloId, () => []).add(m);
  }
  final cicloIdsOrdenados = porCiclo.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final id in cicloIdsOrdenados)
      [
        for (final m in porCiclo[id]!) PuntoMonto(m.fecha, m.monto.centavos.toDouble()),
      ],
  ];
}

/// Pronóstico MPC de [categoria] para [ciclo] a partir de todos los
/// movimientos — la misma llamada que arma la tarjeta de "cierre estimado"
/// y alimenta el plan de ajuste y el rebalanceo. [hoy] se inyecta en vez
/// de leer `DateTime.now()` internamente para que sea determinista en
/// pruebas (incluida la semilla de paridad).
PronosticoCategoria pronosticoDeCategoria({
  required Categoria categoria,
  required List<Movimiento> todos,
  required Ciclo ciclo,
  required DateTime hoy,
}) {
  final movimientosCiclo = todos
      .where(
        (m) =>
            m.categoriaId == categoria.id &&
            m.estado == EstadoMovimiento.activo &&
            m.cicloId == ciclo.id,
      )
      .toList();
  return calcularPronosticoCategoria(
    categoria: categoria,
    cicloId: ciclo.id,
    fechaInicioCiclo: ciclo.fechaInicio,
    fechaFinCiclo: ciclo.fechaFin,
    hoy: hoy,
    movimientosCicloActual: [
      for (final m in movimientosCiclo) PuntoMonto(m.fecha, m.monto.centavos.toDouble()),
    ],
    ciclosCerradosRecienteAAntiguo: ciclosCerradosDeCategoria(
      todos: todos,
      categoriaId: categoria.id,
      cicloActualId: ciclo.id,
    ),
  );
}
