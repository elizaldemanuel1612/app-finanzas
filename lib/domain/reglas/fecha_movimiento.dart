import '../../core/ciclo.dart';
import '../../core/result.dart';
import '../modelos/movimiento.dart';

/// Un gasto no puede ocurrir en el futuro. Compara por día calendario, no
/// por instante: capturar hoy a las 23:00 cuando "ahora" son las 10:00 es
/// válido. El calendario de captura ya vuelve esto inalcanzable
/// (`lastDate: hoy`); esta función es el respaldo comprobable.
Resultado<void> validarFechaCaptura(DateTime fecha, {required DateTime ahora}) {
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  if (dia.isAfter(hoy)) {
    return const Falla('La fecha de un gasto no puede ser futura.');
  }
  return const Exito(null);
}

/// Regla no negociable #5 aplicada a la edición: cambiar la fecha de un
/// movimiento sigue siendo una edición mientras no salte de ciclo. Si
/// [nuevaFecha] cae en otro ciclo, no es una edición sino otro movimiento y
/// se rechaza. En el caso válido recalcula [Movimiento.periodoNatural]
/// (regla #7: los dos ejes) y conserva el `cicloId` intacto — dentro de un
/// mismo ciclo el periodo natural sí puede cambiar (ej. ciclo 12 jul–11 ago:
/// mover un gasto del 20 jul al 5 ago mantiene `cicloId` "2026-07" pero pasa
/// de periodoNatural "2026-07" a "2026-08").
Resultado<Movimiento> editarFechaMovimiento({
  required Movimiento movimiento,
  required DateTime nuevaFecha,
  required CalculadoraCiclo calculadoraCiclo,
}) {
  final cicloPropuesto = calculadoraCiclo.calcularPara(nuevaFecha).id;
  if (cicloPropuesto != movimiento.cicloId) {
    return Falla(
      'Esa fecha pertenece al ciclo $cicloPropuesto, pero este movimiento es '
      'del ciclo ${movimiento.cicloId}. Bórralo y vuelve a capturarlo con la '
      'fecha correcta.',
    );
  }
  return Exito(movimiento.copyWith(
    fecha: nuevaFecha,
    periodoNatural: periodoNatural(nuevaFecha),
  ));
}
