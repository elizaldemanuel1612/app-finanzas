import '../../core/ciclo.dart';
import '../modelos/ciclo_guardado.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';

/// Un ciclo que se puede elegir en Gastos para ver sus movimientos
/// (2026-11-14): su estado real (cerrado solo si así se guardó) y cuánto
/// se gastó en él.
final class CicloConsultable {
  final Ciclo ciclo;
  final int cuantos;
  final int totalCentavos;

  const CicloConsultable({required this.ciclo, required this.cuantos, required this.totalCentavos});

  bool get cerrado => ciclo.estado == EstadoCiclo.cerrado;
}

/// El ciclo en curso y todos los que tienen al menos un gasto activo, del
/// más reciente al más viejo. El estado viene de lo guardado (un ciclo
/// sin [CicloGuardado] nunca se cerró, `ciclo_guardado.dart`); las fechas,
/// de lo guardado o, si no, de la [calculadora] con la fecha de uno de sus
/// gastos — el `cicloId` se asignó con esa misma fecha (regla #5).
List<CicloConsultable> ciclosParaConsultar({
  required Ciclo enCurso,
  required List<Movimiento> movimientos,
  required List<CicloGuardado> guardados,
  required CalculadoraCiclo calculadora,
}) {
  final guardadoPorId = {for (final g in guardados) g.ciclo.id: g.ciclo};
  final ciclos = <String, Ciclo>{enCurso.id: guardadoPorId[enCurso.id] ?? enCurso};
  final cuantos = <String, int>{};
  final totales = <String, int>{};
  for (final m in movimientos) {
    if (m.estado != EstadoMovimiento.activo) continue;
    cuantos[m.cicloId] = (cuantos[m.cicloId] ?? 0) + 1;
    totales[m.cicloId] = (totales[m.cicloId] ?? 0) + m.monto.centavos;
    ciclos.putIfAbsent(m.cicloId, () => guardadoPorId[m.cicloId] ?? calculadora.calcularPara(m.fecha));
  }
  final lista = [
    for (final c in ciclos.values)
      CicloConsultable(ciclo: c, cuantos: cuantos[c.id] ?? 0, totalCentavos: totales[c.id] ?? 0),
  ]..sort((a, b) => b.ciclo.fechaInicio.compareTo(a.ciclo.fechaInicio));
  return lista;
}
