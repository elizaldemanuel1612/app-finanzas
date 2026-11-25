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
///
/// Solo los **anteriores**: un ciclo posterior al actual (las mensualidades
/// que aún no llegan de una compra a meses, spec §7.3.1) no es historia.
/// Los ciclos sin gasto en la categoría entran vacíos (ver [_cerrados]).
List<CicloCerradoHistorico> ciclosCerradosDeCategoria({
  required List<Movimiento> todos,
  required String categoriaId,
  required String cicloActualId,
}) =>
    [
      for (final (_, movimientos) in _cerrados(todos, categoriaId, cicloActualId))
        [for (final m in movimientos) PuntoMonto(m.fecha, m.monto.centavos.toDouble())],
    ];

/// Los ciclos anteriores a [cicloActualId] desde el primero con gasto
/// activo en la categoría, del más reciente al más antiguo. El id `AAAA-MM`
/// ordena como texto.
///
/// Un ciclo en el que se registró algo pero nada de esta categoría entra
/// **vacío** (2026-11-24, modelo-pronostico-ciclo.md §5): saltarlo hacía
/// creer que la categoría gasta en todos los ciclos lo que gastó en los
/// pocos en que sí gastó, e inflaba el cierre de las esporádicas. Los
/// ciclos sin ningún registro (antes de usar la app, o un hueco) no cuentan.
List<(String cicloId, List<Movimiento>)> _cerrados(List<Movimiento> todos, String categoriaId, String cicloActualId) {
  final porCiclo = <String, List<Movimiento>>{};
  final conRegistros = <String>{};
  for (final m in todos) {
    if (m.estado != EstadoMovimiento.activo) continue;
    if (m.cicloId.compareTo(cicloActualId) >= 0) continue;
    conRegistros.add(m.cicloId);
    if (m.categoriaId == categoriaId) porCiclo.putIfAbsent(m.cicloId, () => []).add(m);
  }
  if (porCiclo.isEmpty) return const [];
  final primero = porCiclo.keys.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final ids = [for (final id in conRegistros) if (id.compareTo(primero) >= 0) id]..sort((a, b) => b.compareTo(a));
  return [for (final id in ids) (id, porCiclo[id] ?? const <Movimiento>[])];
}

/// Dónde empezó el ciclo [cicloId] (`AAAA-MM`: el año y mes de su inicio),
/// suponiendo el mismo día de inicio que [actual] — acotado al último día
/// en meses cortos (modelo-pronostico-ciclo.md §3.2). Tras un cambio de día
/// de corte los ciclos viejos quedan desfasados unos días; se acepta. Un id
/// que no tenga esa forma regresa `null`.
DateTime? inicioEstimadoDeCiclo(String cicloId, Ciclo actual) {
  final partes = cicloId.split('-');
  if (partes.length != 2) return null;
  final anio = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  if (anio == null || mes == null || mes < 1 || mes > 12) return null;
  final ultimoDia = DateTime(anio, mes + 1, 0).day;
  final dia = actual.fechaInicio.day;
  return DateTime(anio, mes, dia > ultimoDia ? ultimoDia : dia);
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
  final cerrados = _cerrados(todos, categoria.id, ciclo.id);
  final inicios = [for (final (id, _) in cerrados) inicioEstimadoDeCiclo(id, ciclo)];
  return calcularPronosticoCategoria(
    categoria: categoria,
    cicloId: ciclo.id,
    fechaInicioCiclo: ciclo.fechaInicio,
    fechaFinCiclo: ciclo.fechaFin,
    hoy: hoy,
    movimientosCicloActual: [
      for (final m in movimientosCiclo) PuntoMonto(m.fecha, m.monto.centavos.toDouble()),
    ],
    ciclosCerradosRecienteAAntiguo: [
      for (final (_, movimientos) in cerrados)
        [for (final m in movimientos) PuntoMonto(m.fecha, m.monto.centavos.toDouble())],
    ],
    // Con un id que no se sabe leer no hay posición: avance de calendario.
    iniciosCiclosCerradosRecienteAAntiguo: inicios.contains(null) ? null : inicios.cast<DateTime>(),
  );
}
