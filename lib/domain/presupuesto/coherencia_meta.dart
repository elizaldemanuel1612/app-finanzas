import '../../core/money.dart';
import '../modelos/categoria.dart';

/// Si los presupuestos declarados caben en lo que deja disponible la meta
/// de apartado (`ingreso − meta`). Equivalente en dinero de `L.validar` del
/// prototipo interactivo (`app-finanzas-onboarding-INTERACTIVO.html`).
enum EstadoCoherenciaMeta { cabe, exacto, noCabe }

/// Resultado de comparar la meta declarada contra los presupuestos (fijas +
/// variables): cuánto sobra o falta, y qué meta sí respetaría esos
/// presupuestos tal cual están hoy. **No toca `calcularReparto`** (reglas
/// #10/#11 del paquete siguen intactas): esto solo informa a la interfaz,
/// nunca bloquea el guardado de la meta por sí solo.
final class EvaluacionMeta {
  /// Lo que la meta deja disponible para gastar: `ingreso − meta`. Puede
  /// ser negativo si la meta declarada excede el ingreso.
  final Dinero disponibleParaGastar;

  final Dinero totalPresupuestado;

  /// `disponibleParaGastar − totalPresupuestado`. Negativo cuando los
  /// presupuestos no caben ([EstadoCoherenciaMeta.noCabe]).
  final Dinero excedente;

  final EstadoCoherenciaMeta estado;

  /// Meta que resultaría de respetar los presupuestos tal como están
  /// (`ingreso − totalPresupuestado`), con piso cero — la salida "Bajar la
  /// meta a Z%" del aviso ámbar.
  final Dinero metaSiRespetaPresupuestos;

  /// [metaSiRespetaPresupuestos] expresado como porcentaje entero del
  /// ingreso, redondeo medio arriba. `0` si el ingreso es cero.
  final int porcentajeSiRespetaPresupuestos;

  const EvaluacionMeta({
    required this.disponibleParaGastar,
    required this.totalPresupuestado,
    required this.excedente,
    required this.estado,
    required this.metaSiRespetaPresupuestos,
    required this.porcentajeSiRespetaPresupuestos,
  });
}

EvaluacionMeta evaluarMeta({
  required Dinero ingresoBase,
  required Dinero metaBase,
  required List<CategoriaFija> fijas,
  required List<CategoriaVariable> variables,
}) {
  final disponibleParaGastar = ingresoBase - metaBase;
  final totalPresupuestado = Dinero.suma(fijas.map((f) => f.montoFijoCentavos)) +
      Dinero.suma(variables.map((v) => v.presupuestoMensualCentavos));
  final excedente = disponibleParaGastar - totalPresupuestado;

  final estado = excedente.esCero
      ? EstadoCoherenciaMeta.exacto
      : excedente.esNegativo
          ? EstadoCoherenciaMeta.noCabe
          : EstadoCoherenciaMeta.cabe;

  final metaSiRespetaCruda = ingresoBase - totalPresupuestado;
  final metaSiRespetaPresupuestos =
      metaSiRespetaCruda.esNegativo ? const Dinero.cero() : metaSiRespetaCruda;
  final porcentajeSiRespetaPresupuestos = ingresoBase.esCero
      ? 0
      : ((metaSiRespetaPresupuestos.centavos * 100 + ingresoBase.centavos ~/ 2) ~/
          ingresoBase.centavos);

  return EvaluacionMeta(
    disponibleParaGastar: disponibleParaGastar,
    totalPresupuestado: totalPresupuestado,
    excedente: excedente,
    estado: estado,
    metaSiRespetaPresupuestos: metaSiRespetaPresupuestos,
    porcentajeSiRespetaPresupuestos: porcentajeSiRespetaPresupuestos,
  );
}
