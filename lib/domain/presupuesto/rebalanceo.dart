import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/cambio_auditoria.dart';
import '../modelos/categoria.dart';
import '../pronostico/pronostico_categoria.dart';
import 'categorias.dart';

/// Una categoría con holgura proyectada (addendum-v3-ajuste-y-ux.md §2.5):
/// `Holgura_c = Presupuesto_c − Pronóstico_c`, solo cuando es positiva.
final class CandidataRebalanceo {
  final CategoriaVariable categoria;
  final Dinero holgura;

  const CandidataRebalanceo({required this.categoria, required this.holgura});
}

/// Sugerencia de rebalanceo para una categoría que ya se pasó del
/// presupuesto y no tiene forma de recuperar dentro de ella misma — el
/// Plan de Ajuste (`plan_de_ajuste.dart`) ya no alcanza.
final class Rebalanceo {
  final String categoriaObjetivoId;

  /// Cuánto le falta a la categoría objetivo para cubrir lo que el MPC
  /// proyecta que va a costar el resto del ciclo.
  final Dinero faltante;

  /// Las 3 categorías con más holgura, de mayor a menor (§2.5: "se
  /// ofrecen las 3 mayores").
  final List<CandidataRebalanceo> candidatas;

  const Rebalanceo({
    required this.categoriaObjetivoId,
    required this.faltante,
    required this.candidatas,
  });
}

/// `null` si no aplica: la categoría objetivo todavía no se pasó de su
/// presupuesto ("no hay forma de recuperar dentro de ella" implica que
/// ya se pasó — spec §2.5), o el pronóstico no proyecta faltante alguno.
///
/// No excluye categorías `esNecesaria` de la lista de candidatas: el
/// guardarraíl de "piso digno" (§2.6) protege el *plan de ajuste* (no
/// pedirle a alguien que gaste menos en Súper), no impide que una
/// categoría necesaria que de verdad va a subejercer su presupuesto
/// preste esa holgura — el número ya viene de una proyección real, no
/// de un recorte forzado.
Rebalanceo? calcularRebalanceo({
  required CategoriaVariable categoriaObjetivo,
  required PronosticoCategoria pronosticoObjetivo,
  required List<CategoriaVariable> otrasCategorias,
  required List<PronosticoCategoria> otrosPronosticos,
}) {
  final presupuestoObjetivo = categoriaObjetivo.presupuestoMensualCentavos.centavos;
  if (pronosticoObjetivo.observado.centavos <= presupuestoObjetivo) return null;

  final faltanteCentavos = pronosticoObjetivo.pronosticoP50.centavos - presupuestoObjetivo;
  if (faltanteCentavos <= 0) return null;

  final pronosticoPorId = {for (final p in otrosPronosticos) p.categoriaId: p};
  final candidatas = <CandidataRebalanceo>[];
  for (final c in otrasCategorias) {
    if (c.id == categoriaObjetivo.id) continue;
    final pronostico = pronosticoPorId[c.id];
    if (pronostico == null) continue;
    final holguraCentavos = c.presupuestoMensualCentavos.centavos - pronostico.pronosticoP50.centavos;
    if (holguraCentavos > 0) {
      candidatas.add(CandidataRebalanceo(categoria: c, holgura: Dinero(holguraCentavos)));
    }
  }
  candidatas.sort((a, b) => b.holgura.centavos.compareTo(a.holgura.centavos));

  return Rebalanceo(
    categoriaObjetivoId: categoriaObjetivo.id,
    faltante: Dinero(faltanteCentavos),
    candidatas: candidatas.take(3).toList(),
  );
}

/// Cuánto presupuesto mover desde una categoría origen — el usuario
/// decide el monto, nunca se rebalancea solo (§2.5).
final class MovimientoRebalanceo {
  final String categoriaOrigenId;
  final Dinero monto;

  const MovimientoRebalanceo({required this.categoriaOrigenId, required this.monto});
}

final class ResultadoRebalanceo {
  final CategoriaVariable objetivoActualizada;
  final List<CategoriaVariable> origenesActualizadas;
  final List<CambioAuditoria> auditoria;

  const ResultadoRebalanceo({
    required this.objetivoActualizada,
    required this.origenesActualizadas,
    required this.auditoria,
  });
}

/// Aplica uno o más movimientos de presupuesto: resta de cada origen,
/// suma al objetivo. Regla dura: **solo mueve presupuesto, nunca
/// movimientos ya registrados** — esto no toca ni un [Movimiento]. Todo
/// queda en `auditoria` (§2.5: "todo movimiento queda en la bitácora").
///
/// Falla si algún monto no es positivo o si deja a un origen con
/// presupuesto negativo — nunca se inventa presupuesto de la nada.
Resultado<ResultadoRebalanceo> aplicarRebalanceo({
  required CategoriaVariable objetivo,
  required List<CategoriaVariable> origenes,
  required List<MovimientoRebalanceo> movimientos,
  required DateTime cuando,
  required String dispositivo,
}) {
  final origenesPorId = {for (final c in origenes) c.id: c};
  var totalAMoverCentavos = 0;
  final origenesActualizadas = <CategoriaVariable>[];
  final auditoria = <CambioAuditoria>[];

  for (final mov in movimientos) {
    if (!mov.monto.esPositivo) {
      return Falla('El monto a mover desde ${mov.categoriaOrigenId} debe ser mayor a cero.');
    }
    final origen = origenesPorId[mov.categoriaOrigenId];
    if (origen == null) {
      return Falla('No se encontró la categoría origen ${mov.categoriaOrigenId}.');
    }
    final nuevoPresupuestoOrigen = origen.presupuestoMensualCentavos - mov.monto;
    if (!nuevoPresupuestoOrigen.esPositivo) {
      return Falla(
        '${origen.nombre} no tiene suficiente holgura para mover ${mov.monto.formateado()}.',
      );
    }

    final actualizada = actualizarPresupuestoVariable(
      categoria: origen,
      nuevoPresupuesto: nuevoPresupuestoOrigen,
    );
    if (actualizada case Falla(:final mensaje)) return Falla(mensaje);
    origenesActualizadas.add(actualizada.valorOLanza);

    auditoria.add(CambioAuditoria(
      campo: 'presupuestoMensualCentavos:${origen.id}',
      valorAnterior: origen.presupuestoMensualCentavos.centavos.toString(),
      valorNuevo: nuevoPresupuestoOrigen.centavos.toString(),
      cuando: cuando,
      dispositivo: dispositivo,
    ));

    totalAMoverCentavos += mov.monto.centavos;
  }

  final nuevoPresupuestoObjetivo =
      objetivo.presupuestoMensualCentavos + Dinero(totalAMoverCentavos);
  final objetivoActualizadaResultado = actualizarPresupuestoVariable(
    categoria: objetivo,
    nuevoPresupuesto: nuevoPresupuestoObjetivo,
  );
  if (objetivoActualizadaResultado case Falla(:final mensaje)) return Falla(mensaje);
  final objetivoActualizada = objetivoActualizadaResultado.valorOLanza;

  auditoria.add(CambioAuditoria(
    campo: 'presupuestoMensualCentavos:${objetivo.id}',
    valorAnterior: objetivo.presupuestoMensualCentavos.centavos.toString(),
    valorNuevo: nuevoPresupuestoObjetivo.centavos.toString(),
    cuando: cuando,
    dispositivo: dispositivo,
  ));

  return Exito(ResultadoRebalanceo(
    objetivoActualizada: objetivoActualizada,
    origenesActualizadas: origenesActualizadas,
    auditoria: auditoria,
  ));
}
