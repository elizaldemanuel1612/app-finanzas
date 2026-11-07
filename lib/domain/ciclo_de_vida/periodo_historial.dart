import 'historial_ciclos.dart';

/// Qué parte del historial ver en Ciclos anteriores (2026-11-06): con años
/// de historia, la lista completa se vuelve larga. Por omisión, los últimos
/// 12 ciclos; también un año calendario (por el año en que **empieza** el
/// ciclo, igual que su nombre "Sep 2026") o todo.
sealed class PeriodoHistorial {
  const PeriodoHistorial();
}

final class UltimosCiclos extends PeriodoHistorial {
  final int cuantos;

  const UltimosCiclos([this.cuantos = 12]);

  @override
  bool operator ==(Object other) => other is UltimosCiclos && other.cuantos == cuantos;

  @override
  int get hashCode => cuantos.hashCode;
}

final class AnioCalendario extends PeriodoHistorial {
  final int anio;

  const AnioCalendario(this.anio);

  @override
  bool operator ==(Object other) => other is AnioCalendario && other.anio == anio;

  @override
  int get hashCode => anio.hashCode;
}

final class TodoElHistorial extends PeriodoHistorial {
  const TodoElHistorial();

  @override
  bool operator ==(Object other) => other is TodoElHistorial;

  @override
  int get hashCode => 0;
}

/// Los años con al menos un ciclo, del más reciente al más viejo.
List<int> aniosDelHistorial(List<CicloResumen> historial) {
  final anios = {for (final r in historial) r.ciclo.fechaInicio.year}.toList()..sort((a, b) => b.compareTo(a));
  return anios;
}

/// [historial] viene del más reciente al más viejo
/// (`calcularHistorialCiclos`); se respeta ese orden.
List<CicloResumen> filtrarHistorial(List<CicloResumen> historial, PeriodoHistorial periodo) => switch (periodo) {
      UltimosCiclos(:final cuantos) => historial.take(cuantos).toList(),
      AnioCalendario(:final anio) => [
          for (final r in historial)
            if (r.ciclo.fechaInicio.year == anio) r,
        ],
      TodoElHistorial() => List.of(historial),
    };
