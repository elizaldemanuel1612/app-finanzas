import 'normalizacion_texto.dart';
import 'regla_aprendida.dart';

/// En qué nivel de la cascada (spec-app-finanzas-v2.md §6.1) se resolvió
/// — o no se resolvió — la clasificación.
enum NivelClasificacion {
  /// Nivel 1: coincidió con una regla que el usuario ya confirmó antes.
  reglaUsuario,

  /// Nivel 2: coincidió con un comercio ya clasificado en el historial.
  historial,

  /// Nivel 3: la resolvió la IA (solo si 1 y 2 no resolvieron nada).
  ia,

  /// Ningún nivel resolvió nada — va a revisión manual.
  sinResolver,
}

/// Respuesta de un clasificador de IA (Nivel 3): categoría sugerida y
/// qué tan segura está el modelo. `null` en vez de esta clase significa
/// "tampoco supo".
final class ResultadoIA {
  final String categoriaId;
  final double confianza;

  const ResultadoIA({required this.categoriaId, required this.confianza});
}

/// Firma de un clasificador de IA externo — inyectado, nunca invocado
/// directamente por el dominio. Hoy no hay ningún modelo de IA conectado
/// (§6.4 ya contempla que la app funcione perfecto solo con Niveles 1 y
/// 2); quien llame a [clasificar] simplemente no pasa uno, y el Nivel 3
/// nunca se activa — no es un caso de error, es el estado normal hasta
/// que exista un backend de IA.
typedef ClasificadorIA = ResultadoIA? Function(String texto);

/// Resultado final de la cascada, con todo lo que la UI necesita para
/// decidir qué mostrar (§6.3): aplicar de una vez, pedir confirmación, o
/// mandar a revisión.
final class ResultadoCascada {
  final String? categoriaId;
  final double confianza;
  final NivelClasificacion nivel;

  /// `0.60 – 0.89` de confianza de IA: se sugiere pero no se aplica sola.
  final bool requiereConfirmacion;

  /// `< 0.60` de confianza de IA, o ningún nivel resolvió nada: va a
  /// "Otros" y se marca para revisión — nunca se guarda una categoría en
  /// la que el sistema no confía (regla no negociable, spec §0.4).
  final bool marcadoParaRevision;

  const ResultadoCascada({
    required this.categoriaId,
    required this.confianza,
    required this.nivel,
    required this.requiereConfirmacion,
    required this.marcadoParaRevision,
  });

  bool get resuelto => categoriaId != null;
}

const _umbralAuto = 0.90;
const _umbralConfirmar = 0.60;

/// Cascada de 3 niveles (§6.1) para sugerir la categoría de un gasto a
/// partir de su descripción o el comercio detectado en un ticket.
/// Reglas del usuario → historial de comercios → IA, en ese orden, y se
/// detiene en el primero que resuelva algo.
ResultadoCascada clasificar({
  required String texto,
  required List<ReglaAprendida> reglasUsuario,
  required Map<String, String> historialComercios,
  ClasificadorIA? clasificadorIA,
}) {
  final normalizado = normalizarTexto(texto);
  if (normalizado.isEmpty) {
    return const ResultadoCascada(
      categoriaId: null,
      confianza: 0,
      nivel: NivelClasificacion.sinResolver,
      requiereConfirmacion: false,
      marcadoParaRevision: true,
    );
  }

  final porRegla = _mejorCoincidenciaRegla(normalizado, reglasUsuario);
  if (porRegla != null) {
    return ResultadoCascada(
      categoriaId: porRegla.categoriaId,
      confianza: 1.0,
      nivel: NivelClasificacion.reglaUsuario,
      requiereConfirmacion: false,
      marcadoParaRevision: false,
    );
  }

  final porHistorial = _mejorCoincidenciaHistorial(normalizado, historialComercios);
  if (porHistorial != null) {
    return ResultadoCascada(
      categoriaId: porHistorial,
      confianza: 1.0,
      nivel: NivelClasificacion.historial,
      requiereConfirmacion: false,
      marcadoParaRevision: false,
    );
  }

  final porIA = clasificadorIA?.call(texto);
  if (porIA != null) {
    if (porIA.confianza >= _umbralAuto) {
      return ResultadoCascada(
        categoriaId: porIA.categoriaId,
        confianza: porIA.confianza,
        nivel: NivelClasificacion.ia,
        requiereConfirmacion: false,
        marcadoParaRevision: false,
      );
    }
    if (porIA.confianza >= _umbralConfirmar) {
      return ResultadoCascada(
        categoriaId: porIA.categoriaId,
        confianza: porIA.confianza,
        nivel: NivelClasificacion.ia,
        requiereConfirmacion: true,
        marcadoParaRevision: false,
      );
    }
    return ResultadoCascada(
      categoriaId: null,
      confianza: porIA.confianza,
      nivel: NivelClasificacion.ia,
      requiereConfirmacion: false,
      marcadoParaRevision: true,
    );
  }

  return const ResultadoCascada(
    categoriaId: null,
    confianza: 0,
    nivel: NivelClasificacion.sinResolver,
    requiereConfirmacion: false,
    marcadoParaRevision: true,
  );
}

/// La regla que coincide (patrón contenido en el texto o viceversa) más
/// específica (patrón más largo) gana; empates se resuelven por el
/// contador más alto — la regla que el usuario ha confirmado más veces.
ReglaAprendida? _mejorCoincidenciaRegla(String textoNormalizado, List<ReglaAprendida> reglas) {
  ReglaAprendida? mejor;
  for (final regla in reglas) {
    if (regla.patron.isEmpty) continue;
    final coincide =
        textoNormalizado.contains(regla.patron) || regla.patron.contains(textoNormalizado);
    if (!coincide) continue;
    if (mejor == null ||
        regla.patron.length > mejor.patron.length ||
        (regla.patron.length == mejor.patron.length && regla.contador > mejor.contador)) {
      mejor = regla;
    }
  }
  return mejor;
}

String? _mejorCoincidenciaHistorial(String textoNormalizado, Map<String, String> historial) {
  String? mejorComercio;
  for (final comercio in historial.keys) {
    if (comercio.isEmpty) continue;
    final coincide = textoNormalizado.contains(comercio) || comercio.contains(textoNormalizado);
    if (!coincide) continue;
    if (mejorComercio == null || comercio.length > mejorComercio.length) {
      mejorComercio = comercio;
    }
  }
  return mejorComercio == null ? null : historial[mejorComercio];
}
