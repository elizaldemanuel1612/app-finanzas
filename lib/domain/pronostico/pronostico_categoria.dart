import 'dart:math' as math;

import '../../core/money.dart';
import '../modelos/categoria.dart';
import 'avance_efectivo.dart';
import 'clasificador_atipicos.dart';
import 'estadistica_robusta.dart';
import 'historico_ciclos.dart';
import 'nivel_madurez.dart';
import 'perfil_dia_semana.dart';
import 'punto_monto.dart';
import 'subcaptura.dart';

/// Tipificación automática por frecuencia (modelo-pronostico-ciclo.md §4).
/// [fija] no se infiere — la declara el usuario al crear la categoría
/// (es una [CategoriaFija]); [variableFrecuente] vs [esporadica] sí se
/// deriva del conteo de movimientos por ciclo (umbral: 8).
enum TipoMpc { fija, variableFrecuente, esporadica }

enum ConfianzaMpc { alta, media, baja }

/// Salida del modelo por categoría y por ciclo (§10). El campo
/// [explicacion] es obligatorio a propósito: "un pronóstico que no puede
/// explicarse en una frase no se muestra".
final class PronosticoCategoria {
  final String categoriaId;
  final String cicloId;
  final TipoMpc tipo;
  final Dinero observado;
  final Dinero base;
  final Dinero atipico;
  final Dinero comprometido;

  /// `p_c` — avance efectivo del ciclo (0..1). `1.0` para categorías Tipo A.
  final double avanceEfectivo;

  final Dinero pronosticoP50;
  final Dinero pronosticoP10;
  final Dinero pronosticoP90;
  final ConfianzaMpc confianza;
  final SenalSubcaptura senalSubcaptura;
  final NivelMadurezMpc nivelMadurez;
  final List<String> explicacion;

  const PronosticoCategoria({
    required this.categoriaId,
    required this.cicloId,
    required this.tipo,
    required this.observado,
    required this.base,
    required this.atipico,
    required this.comprometido,
    required this.avanceEfectivo,
    required this.pronosticoP50,
    required this.pronosticoP10,
    required this.pronosticoP90,
    required this.confianza,
    required this.senalSubcaptura,
    required this.nivelMadurez,
    required this.explicacion,
  });
}

/// Un ciclo cerrado, reducido a lo que el MPC necesita de él: sus
/// movimientos de esta categoría. La lista de ciclos debe venir del más
/// reciente cerrado al más antiguo — el orden alimenta directo a
/// `historicoSuavizado`.
typedef CicloCerradoHistorico = List<PuntoMonto>;

/// Calcula el pronóstico de cierre de una categoría para el ciclo actual
/// (modelo-pronostico-ciclo.md, completo).
///
/// **Simplificaciones conscientes de v1** (documentadas también en los
/// módulos donde aplican):
/// - No implementa `v_c(t)` (§3.2); el peso combinado usa solo día de
///   semana.
/// - `Comprometido_c` de categorías Tipo B/C es siempre 0 — no hay
///   modelo de recurrencias dentro de una categoría variable todavía
///   (solo las categorías Tipo A tienen fecha de cobro conocida).
/// - El rango P10/P90 (§6) no viene de cuantiles de error backtesteados
///   (§9, no implementado) — usa un ancho heurístico que se angosta con
///   el nivel de madurez (§7), documentado en [_anchoRangoPorNivel].
PronosticoCategoria calcularPronosticoCategoria({
  required Categoria categoria,
  required String cicloId,
  required DateTime fechaInicioCiclo,
  required DateTime fechaFinCiclo,
  required DateTime hoy,
  required List<PuntoMonto> movimientosCicloActual,
  required List<CicloCerradoHistorico> ciclosCerradosRecienteAAntiguo,
}) {
  if (categoria is CategoriaFija) {
    return _pronosticoTipoA(
      categoria: categoria,
      cicloId: cicloId,
      movimientosCicloActual: movimientosCicloActual,
    );
  }

  final nivel = nivelMadurezMpc(ciclosCerradosRecienteAAntiguo.length);
  final montosCicloActual = movimientosCicloActual.map((p) => p.monto).toList();
  final observadoTotal = montosCicloActual.fold(0.0, (a, b) => a + b);

  final clasificacion = clasificarMontos(montosCicloActual);

  final perfilDiaSemana = perfilEfectivoParaNivel(nivel, ciclosCerradosRecienteAAntiguo);

  final pC = avanceEfectivoCiclo(
    perfilDiaSemana: perfilDiaSemana,
    fechaInicio: fechaInicioCiclo,
    fechaFin: fechaFinCiclo,
    hoy: hoy,
  );

  final movimientosObservadosCount = movimientosCicloActual.length;
  final densidadEsperadaBase = ciclosCerradosRecienteAAntiguo.isEmpty
      ? 0.0
      : ciclosCerradosRecienteAAntiguo.map((c) => c.length).reduce((a, b) => a + b) /
          ciclosCerradosRecienteAAntiguo.length;
  final movimientosEsperadosAFecha = densidadEsperadaBase * pC;
  final senal = calcularSenalSubcaptura(
    movimientosObservados: movimientosObservadosCount,
    movimientosEsperados: movimientosEsperadosAFecha,
  );

  final esFrecuente = ciclosCerradosRecienteAAntiguo.isEmpty
      ? movimientosObservadosCount >= 8
      : densidadEsperadaBase >= 8;

  final double proyeccionCruda;
  final TipoMpc tipo;
  if (esFrecuente) {
    tipo = TipoMpc.variableFrecuente;
    proyeccionCruda = _proyeccionTipoB(
      baseObservada: clasificacion.base,
      atipicosObservados: clasificacion.atipico,
      historico: historicoCentavosWinsorizado(ciclosCerradosRecienteAAntiguo),
      pC: pC,
    );
  } else {
    tipo = TipoMpc.esporadica;
    proyeccionCruda = _proyeccionTipoC(
      observado: observadoTotal,
      ciclosCerrados: ciclosCerradosRecienteAAntiguo,
      pC: pC,
    );
  }

  // §7, nivel "sinHistorial": "Presupuesto como pronóstico" — sin ningún
  // ciclo cerrado, la fórmula de Tipo B/C no tiene con qué apoyarse más
  // que lo observado; se usa el presupuesto declarado tal cual, en vez de
  // una proyección calculada que en el fondo no está prediciendo nada.
  final presupuesto = categoria is CategoriaVariable ? categoria.presupuestoMensualCentavos.centavos.toDouble() : null;
  final proyeccionBase =
      nivel == NivelMadurezMpc.sinHistorial && presupuesto != null ? presupuesto : proyeccionCruda;

  // Cota inferior dura (§6): nunca por debajo de lo ya gastado.
  final p50 = math.max(proyeccionBase, observadoTotal);

  final ancho = _anchoRangoPorNivel(nivel);
  final p10 = math.max(p50 * (1 - ancho), observadoTotal);
  final p90 = p50 * (1 + ancho);

  final confianza = _confianza(nivel, senal);

  return PronosticoCategoria(
    categoriaId: categoria.id,
    cicloId: cicloId,
    tipo: tipo,
    observado: _redondear(observadoTotal),
    base: _redondear(clasificacion.base),
    atipico: _redondear(clasificacion.atipico),
    comprometido: const Dinero.cero(),
    avanceEfectivo: pC,
    pronosticoP50: _redondear(p50),
    pronosticoP10: _redondear(p10),
    pronosticoP90: _redondear(p90),
    confianza: confianza,
    senalSubcaptura: senal,
    nivelMadurez: nivel,
    explicacion: _explicacion(
      categoria: categoria,
      tipo: tipo,
      clasificacion: clasificacion,
      nivel: nivel,
      senal: senal,
    ),
  );
}

PronosticoCategoria _pronosticoTipoA({
  required CategoriaFija categoria,
  required String cicloId,
  required List<PuntoMonto> movimientosCicloActual,
}) {
  final observado = movimientosCicloActual.fold(0.0, (a, b) => a + b.monto);
  final montoFijo = categoria.montoFijoCentavos.centavos.toDouble();
  final yaPagado = observado > 0;

  return PronosticoCategoria(
    categoriaId: categoria.id,
    cicloId: cicloId,
    tipo: TipoMpc.fija,
    observado: _redondear(observado),
    base: categoria.montoFijoCentavos,
    atipico: const Dinero.cero(),
    comprometido: yaPagado ? const Dinero.cero() : categoria.montoFijoCentavos,
    avanceEfectivo: yaPagado ? 1.0 : 0.0,
    pronosticoP50: _redondear(montoFijo),
    pronosticoP10: _redondear(montoFijo),
    pronosticoP90: _redondear(montoFijo),
    confianza: ConfianzaMpc.alta,
    senalSubcaptura: SenalSubcaptura.normal,
    nivelMadurez: NivelMadurezMpc.completo,
    explicacion: [
      yaPagado
          ? '${categoria.nombre} ya se pagó este ciclo: ${categoria.montoFijoCentavos.formateado()}.'
          : '${categoria.nombre} es un monto fijo, todavía no cae: ${categoria.montoFijoCentavos.formateado()}.',
    ],
  );
}

/// `Base_esperada_restante = [Z × (Base_obs ÷ p_c) + (1−Z) × Histórico_c] × (1−p_c)`
/// `Z = p_c ÷ (p_c + 0.35)`
double _proyeccionTipoB({
  required double baseObservada,
  required double atipicosObservados,
  required double historico,
  required double pC,
}) {
  final z = pC <= 0 ? 0.0 : pC / (pC + 0.35);
  final ritmoActual = pC <= 0 ? 0.0 : baseObservada / pC;
  final baseEsperadaRestante = (z * ritmoActual + (1 - z) * historico) * (1 - pC);
  return baseObservada + baseEsperadaRestante + atipicosObservados;
}

/// `λ_c = movimientos promedio por ciclo`, `m_c = mediana del monto`
/// `Proyección_C = Observado + [ λ_c × (1−p_c) × m_c ]`
double _proyeccionTipoC({
  required double observado,
  required List<CicloCerradoHistorico> ciclosCerrados,
  required double pC,
}) {
  if (ciclosCerrados.isEmpty) return observado;
  final lambda =
      ciclosCerrados.map((c) => c.length).reduce((a, b) => a + b) / ciclosCerrados.length;
  final montos = ciclosCerrados.expand((c) => c.map((p) => p.monto)).toList();
  final m = mediana(montos);
  return observado + (lambda * (1 - pC) * m);
}

/// Totales por ciclo cerrado, winsorizados (§5: "mediana de los totales
/// winsorizados por categoría") y ordenados reciente→antiguo, listos para
/// `historicoSuavizado`. Pública porque `plan_de_ajuste.dart` necesita el
/// mismo "gasto habitual" que usa el MPC — nunca dos cálculos distintos
/// de lo mismo.
double historicoCentavosWinsorizado(List<CicloCerradoHistorico> ciclosCerrados) {
  if (ciclosCerrados.isEmpty) return 0;
  final totales = ciclosCerrados.map((c) => c.fold(0.0, (a, p) => a + p.monto)).toList();
  final p95 = percentil(totales, 0.95);
  final winsorizados = totales.map((t) => t > p95 ? p95 : t).toList();
  return historicoSuavizado(winsorizados);
}

/// El perfil de día de semana que el MPC realmente usó para este
/// pronóstico (§7: neutro antes del nivel `conEstacionalidad`, real
/// después) — pública para que `plan_de_ajuste.dart` reparta los días
/// restantes con el mismo perfil, no uno recalculado aparte.
Map<int, double> perfilEfectivoParaNivel(
  NivelMadurezMpc nivel,
  List<CicloCerradoHistorico> ciclosCerradosRecienteAAntiguo,
) {
  if (nivel.index < NivelMadurezMpc.conEstacionalidad.index) {
    return const {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0};
  }
  return calcularPerfilDiaSemana(ciclosCerradosRecienteAAntiguo.expand((c) => c).toList());
}

double _anchoRangoPorNivel(NivelMadurezMpc nivel) => switch (nivel) {
      NivelMadurezMpc.sinHistorial => 0.35,
      NivelMadurezMpc.historicoSimple => 0.35,
      NivelMadurezMpc.atipicosYCredibilidad => 0.22,
      NivelMadurezMpc.conEstacionalidad => 0.14,
      NivelMadurezMpc.completo => 0.08,
    };

ConfianzaMpc _confianza(NivelMadurezMpc nivel, SenalSubcaptura senal) {
  if (senal == SenalSubcaptura.noConfiable) return ConfianzaMpc.baja;
  final base = switch (nivel) {
    NivelMadurezMpc.sinHistorial || NivelMadurezMpc.historicoSimple => ConfianzaMpc.baja,
    NivelMadurezMpc.atipicosYCredibilidad => ConfianzaMpc.media,
    NivelMadurezMpc.conEstacionalidad || NivelMadurezMpc.completo => ConfianzaMpc.alta,
  };
  if (senal == SenalSubcaptura.bandera && base == ConfianzaMpc.alta) return ConfianzaMpc.media;
  return base;
}

List<String> _explicacion({
  required Categoria categoria,
  required TipoMpc tipo,
  required ResultadoClasificacion clasificacion,
  required NivelMadurezMpc nivel,
  required SenalSubcaptura senal,
}) {
  final textos = <String>[];
  final mensajeNivel = mensajeNivelMadurez(nivel);
  if (mensajeNivel.isNotEmpty) textos.add(mensajeNivel);

  if (clasificacion.atipico > 0) {
    textos.add(
      '${categoria.nombre} incluye ${_redondear(clasificacion.atipico).formateado()} '
      'tratado como evento único, no se proyecta a futuro.',
    );
  }

  switch (senal) {
    case SenalSubcaptura.bandera:
      textos.add('Llevas menos movimientos de lo habitual. ¿Falta capturar algo?');
    case SenalSubcaptura.noConfiable:
      textos.add('Muy pocos movimientos capturados — el pronóstico se apoya en tu histórico.');
    case SenalSubcaptura.normal:
      break;
  }

  if (textos.isEmpty) {
    textos.add(tipo == TipoMpc.variableFrecuente
        ? '${categoria.nombre} se proyecta con tu patrón habitual de gasto.'
        : '${categoria.nombre} se proyecta con la frecuencia y el monto típico de tus gastos esporádicos.');
  }

  return textos;
}

Dinero _redondear(double centavos) => Dinero(centavos.round());
