import '../../core/money.dart';

/// Escalones del selector de meta (`app-finanzas-onboarding-INTERACTIVO
/// .html`, slider 0–70 en pasos de 5) sobre los que se sugiere — no
/// cualquier porcentaje, solo estos.
const _escalones = [5, 10, 15, 20, 30, 40];

/// Por qué se sugirió el porcentaje — el texto lo arma la interfaz, esto
/// solo distingue la rama.
enum MotivoSugerencia {
  /// Arranque en frío: todavía no hay categorías fijas declaradas, así que
  /// no hay margen que calcular.
  arranqueEnFrio,

  /// Con fijas declaradas: el escalón más alto que cabe en la mitad del
  /// margen libre.
  margenLibre,

  /// Con fijas declaradas pero el margen libre es tan estrecho (o
  /// negativo) que ni el escalón más bajo cabe en la mitad.
  margenEstrecho,
}

final class SugerenciaMeta {
  final int porcentaje;
  final MotivoSugerencia motivo;

  const SugerenciaMeta({required this.porcentaje, required this.motivo});

  @override
  String toString() => 'SugerenciaMeta($porcentaje%, ${motivo.name})';
}

/// Sugiere un porcentaje de apartado para quien no sabe por dónde empezar
/// (addendum-v3-ajuste-y-ux.md, principio de simplicidad y motivación).
///
/// Sin fijas declaradas todavía, sugiere el escalón más conservador (10%,
/// "donde casi nadie falla") — no hay margen que calcular en arranque en
/// frío. Con fijas, sugiere el escalón más alto que quepa en la **mitad**
/// del margen libre (`ingreso − fijas`), dejando la otra mitad como
/// colchón para las variables en vez de comprometer todo lo que sobra de
/// una vez. Con el ejemplo del mockup (ingreso $87,000, fijas $15,700) el
/// margen libre es $71,300, la mitad $35,650, y el escalón más alto que
/// cabe es 40% (=$34,800) — el mismo que dibuja `onboarding-v5 §4`.
SugerenciaMeta sugerirPorcentaje({
  required Dinero ingresoBase,
  required Dinero totalFijas,
}) {
  if (totalFijas.esCero) {
    return const SugerenciaMeta(porcentaje: 10, motivo: MotivoSugerencia.arranqueEnFrio);
  }

  final margenLibre = ingresoBase - totalFijas;
  final techo = Dinero(margenLibre.centavos ~/ 2);

  for (final escalon in _escalones.reversed) {
    final montoEscalon = Dinero((ingresoBase.centavos * escalon + 50) ~/ 100);
    if (montoEscalon <= techo) {
      return SugerenciaMeta(porcentaje: escalon, motivo: MotivoSugerencia.margenLibre);
    }
  }

  return const SugerenciaMeta(porcentaje: 5, motivo: MotivoSugerencia.margenEstrecho);
}
