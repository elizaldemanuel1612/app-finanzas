import 'dart:math';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import 'alcance.dart';
import 'historial_ciclos.dart';

/// Estado de un [PuntoEvolucion] en la gráfica «Cuánto has apartado por
/// ciclo» (app-finanzas-fijos-cierre-v6.html §6).
enum EstadoPunto { cerrado, enCurso, sinCierre }

/// Un punto ya resuelto de la gráfica de trazabilidad — incluida la altura
/// de la barra — para que el widget no calcule nada, solo pinte
/// (addendum-v3-ajuste-y-ux.md §5: las fallas de revisión fueron de
/// coherencia aritmética entre texto y datos).
final class PuntoEvolucion {
  final String cicloId;
  final String etiqueta;
  final EstadoPunto estado;

  /// `null` solo en [EstadoPunto.sinCierre]: sin snapshot no hay ingreso ni
  /// meta contra qué medir.
  final MetricasApartado? metricas;
  final Dinero? meta;
  final bool tuvoIngresoExtra;

  /// Altura de la barra sobre el carril, ya escalada a `[0, 1]`.
  final double alturaRelativa;

  const PuntoEvolucion({
    required this.cicloId,
    required this.etiqueta,
    required this.estado,
    required this.metricas,
    required this.meta,
    required this.tuvoIngresoExtra,
    required this.alturaRelativa,
  });
}

/// Resultado de [calcularEvolucionCiclos]: los puntos de la gráfica más los
/// agregados de la tarjeta ("Acumulado en N ciclos", "Promedio de ahorro
/// por mes").
final class EvolucionCiclos {
  /// Ascendente por `fechaInicio` (izq → der), máximo `maximoPuntos`.
  final List<PuntoEvolucion> puntos;

  /// Σ `metricas.apartado` de puntos [EstadoPunto.cerrado] únicamente.
  final Dinero acumulado;

  /// La N de "Acumulado en N ciclos" — cuántos puntos cerrados hay.
  final int ciclosAcumulados;

  /// `acumulado / ciclosAcumulados`, truncado a centavos. `null` si no hay
  /// ningún cerrado. En monto, no en % — igual que la barra, para no
  /// mezclar dos escalas distintas en la misma tarjeta (ver el docstring
  /// de [calcularEvolucionCiclos]).
  final Dinero? promedioAhorroPorMes;

  /// Meta del ciclo en curso, o la del último cerrado si no hay ciclo en
  /// curso. `null` si tampoco hay cerrados.
  final Dinero? metaReferencia;

  /// Dónde va la línea de meta sobre el carril, `[0, 1]`.
  final double alturaMeta;

  const EvolucionCiclos({
    required this.puntos,
    required this.acumulado,
    required this.ciclosAcumulados,
    required this.promedioAhorroPorMes,
    required this.metaReferencia,
    required this.alturaMeta,
  });

  bool get hayDatos => ciclosAcumulados > 0;
}

/// Insumos del ciclo abierto — los mismos cinco valores que pide
/// [calcularMetricasApartado], calculados en vivo porque el ciclo en curso
/// todavía no tiene snapshot.
final class InsumosCicloEnCurso {
  final Ciclo ciclo;
  final Dinero ingresoTotal;
  final Dinero totalGastado;
  final Dinero meta;
  final Dinero extraAApartado;
  final Dinero extraAGasto;

  const InsumosCicloEnCurso({
    required this.ciclo,
    required this.ingresoTotal,
    required this.totalGastado,
    required this.meta,
    required this.extraAApartado,
    required this.extraAGasto,
  });
}

class _PuntoBase {
  final Ciclo ciclo;
  final EstadoPunto estado;
  final MetricasApartado? metricas;
  final Dinero? meta;
  final bool tuvoIngresoExtra;

  const _PuntoBase({
    required this.ciclo,
    required this.estado,
    required this.metricas,
    required this.meta,
    required this.tuvoIngresoExtra,
  });
}

/// Calcula la gráfica «Cuánto has apartado por ciclo» y sus agregados a
/// partir de lo que ya devuelve `calcularHistorialCiclos` — no hace falta
/// ningún dato nuevo.
///
/// **Escala por monto ahorrado, no por alcance:** el mockup original
/// (app-finanzas-fijos-cierre-v6.html §6) escalaba cada barra por
/// `alcance` (`apartado / meta`). Eso se rompe en cuanto dos ciclos tienen
/// metas distintas — un ciclo con meta chica y un ahorro modesto puede
/// marcar 600%+ de alcance y salir más alto en la gráfica que otro que en
/// pesos reales ahorró mucho más. Aquí cada barra se escala linealmente
/// contra el monto más alto entre lo ahorrado por cualquier ciclo visible
/// y la meta de referencia, así que "más alto" siempre significa "más
/// dinero apartado", sin importar cuál era la meta de cada quien. Lo
/// negativo (se gastó más de lo que entró) se dibuja en cero — no hay
/// forma de pintar una barra bajo el carril con este layout.
///
/// **Divergencia deliberada del mockup:** el mockup suma el ciclo en curso
/// al "Acumulado en 3 ciclos" y al "Promedio 93%". Aquí no: al día 3 de un
/// ciclo el ingreso ya entró y casi no se ha gastado, así que el alcance en
/// curso ronda el 250% y arrastraría el promedio a un número sin sentido.
/// El ciclo en curso se dibuja pero no se agrega — la barra sigue siendo
/// verdad (ese dinero hoy está sin gastar) y la nota al pie lo explica.
EvolucionCiclos calcularEvolucionCiclos({
  required List<CicloResumen> historial,
  required InsumosCicloEnCurso? enCurso,
  int maximoPuntos = 6,
}) {
  final base = <_PuntoBase>[
    for (final r in historial)
      _PuntoBase(
        ciclo: r.ciclo,
        estado: r.snapshot != null ? EstadoPunto.cerrado : EstadoPunto.sinCierre,
        metricas: r.snapshot == null
            ? null
            : calcularMetricasApartado(
                ingresoTotal: r.snapshot!.ingresoTotal,
                totalGastado: r.snapshot!.totalGastado,
                meta: r.snapshot!.metaApartado,
                extraAApartado: r.snapshot!.extraAApartado,
                extraAGasto: r.snapshot!.extraAGasto,
              ),
        meta: r.snapshot?.metaApartado,
        tuvoIngresoExtra: r.tuvoIngresoExtra,
      ),
    if (enCurso != null)
      _PuntoBase(
        ciclo: enCurso.ciclo,
        estado: EstadoPunto.enCurso,
        metricas: calcularMetricasApartado(
          ingresoTotal: enCurso.ingresoTotal,
          totalGastado: enCurso.totalGastado,
          meta: enCurso.meta,
          extraAApartado: enCurso.extraAApartado,
          extraAGasto: enCurso.extraAGasto,
        ),
        meta: enCurso.meta,
        tuvoIngresoExtra: (enCurso.extraAApartado + enCurso.extraAGasto).esPositivo,
      ),
  ]..sort((a, b) => a.ciclo.fechaInicio.compareTo(b.ciclo.fechaInicio));

  final recortados =
      base.length > maximoPuntos ? base.sublist(base.length - maximoPuntos) : base;

  final cerradosBase = recortados.where((p) => p.estado == EstadoPunto.cerrado);
  final metaReferencia =
      enCurso?.meta ?? (cerradosBase.isEmpty ? null : cerradosBase.last.meta);

  // maxMonto incluye la meta de referencia además de lo ahorrado: así la
  // línea de meta nunca se sale del carril (queda en 1.0 cuando la meta es
  // el monto más alto de todos), igual que antes evitaba cortarse contra
  // el techo con el alcance.
  final montosPositivos = recortados
      .map((p) => p.metricas?.apartado)
      .whereType<Dinero>()
      .where((a) => a.esPositivo)
      .map((a) => a.centavos);
  final maxMonto = [
    if (montosPositivos.isNotEmpty) montosPositivos.reduce(max),
    if (metaReferencia != null && metaReferencia.esPositivo) metaReferencia.centavos,
  ].fold(0, max);

  double alturaPorMonto(Dinero monto) =>
      maxMonto == 0 ? 0.0 : (monto.centavos / maxMonto).clamp(0.0, 1.0);

  final alturaMeta = metaReferencia == null ? 0.0 : alturaPorMonto(metaReferencia);

  final puntos = [
    for (final p in recortados)
      PuntoEvolucion(
        cicloId: p.ciclo.id,
        etiqueta: p.ciclo.etiqueta,
        estado: p.estado,
        metricas: p.metricas,
        meta: p.meta,
        tuvoIngresoExtra: p.tuvoIngresoExtra,
        alturaRelativa: p.estado == EstadoPunto.sinCierre
            ? alturaMeta
            : alturaPorMonto(p.metricas!.apartado),
      ),
  ];

  final cerrados = puntos.where((p) => p.estado == EstadoPunto.cerrado).toList();
  final acumulado = Dinero.suma(cerrados.map((p) => p.metricas!.apartado));
  final promedioAhorroPorMes =
      cerrados.isEmpty ? null : Dinero(acumulado.centavos ~/ cerrados.length);

  return EvolucionCiclos(
    puntos: puntos,
    acumulado: acumulado,
    ciclosAcumulados: cerrados.length,
    promedioAhorroPorMes: promedioAhorroPorMes,
    metaReferencia: metaReferencia,
    alturaMeta: alturaMeta,
  );
}

/// Frase interpretativa de la tarjeta violeta (regla no negociable #23:
/// ningún pronóstico se muestra sin una frase que lo explique; regla #24:
/// cero jerga técnica). `null` si no hay al menos dos ciclos cerrados con
/// los que comparar — con uno solo no hay "mejoraste" ni "empeoraste" que
/// tenga sentido decir.
String? fraseEvolucion(EvolucionCiclos evolucion) {
  final cerrados = evolucion.puntos.where((p) => p.estado == EstadoPunto.cerrado).toList();
  if (cerrados.length < 2) return null;

  final ultimo = cerrados.last;
  final previo = cerrados[cerrados.length - 2];
  final alcanceUltimo = ultimo.metricas?.alcance;
  final alcancePrevio = previo.metricas?.alcance;
  if (alcanceUltimo == null || alcancePrevio == null) return null;

  if (alcanceUltimo >= 1.0 && alcancePrevio >= 1.0) {
    return 'Dos ciclos seguidos en meta.';
  }
  if (alcanceUltimo > alcancePrevio) {
    final puntos = ((alcanceUltimo - alcancePrevio) * 100).round();
    return 'Mejoraste $puntos puntos respecto a ${previo.etiqueta}.';
  }
  if (alcanceUltimo < alcancePrevio) {
    return '${ultimo.etiqueta} costó más que ${previo.etiqueta}.';
  }
  return null;
}
