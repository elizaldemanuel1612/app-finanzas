import 'result.dart';

/// Estado de un [Ciclo]. Un ciclo cerrado no se recalcula: los históricos
/// nunca cambian retroactivamente (spec-app-finanzas-v2.md §2.2).
enum EstadoCiclo { abierto, cerrado }

const _mesesAbrev = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic', //
];

/// Ciclo de tarjeta: un periodo de `diaCorte` a `diaCorte - 1` del mes
/// siguiente (paquete-construccion-final.md §4, spec-app-finanzas-v2.md
/// §2.1). Se le asigna a cada movimiento **una sola vez**, al crearse
/// (regla no negociable #5) — este tipo modela el ciclo en sí; quién lo
/// asigna y cuándo es responsabilidad de la capa de datos.
final class Ciclo {
  /// Identificador estable, ej. "2026-07". Se deriva de [fechaInicio].
  final String id;
  final DateTime fechaInicio;

  /// Último día del ciclo, inclusive.
  final DateTime fechaFin;
  final String etiqueta;
  final EstadoCiclo estado;

  const Ciclo({
    required this.id,
    required this.fechaInicio,
    required this.fechaFin,
    required this.etiqueta,
    required this.estado,
  });

  bool contiene(DateTime fecha) {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    return !dia.isBefore(fechaInicio) && !dia.isAfter(fechaFin);
  }

  /// Cierra el ciclo. Falla si ya estaba cerrado — cerrar dos veces suele
  /// ser un error de quien llama, no un estado válido a ignorar en silencio.
  Resultado<Ciclo> cerrar() {
    if (estado == EstadoCiclo.cerrado) {
      return Falla('El ciclo $id ya está cerrado.');
    }
    return Exito(_conEstado(EstadoCiclo.cerrado));
  }

  /// Reabre el ciclo de forma explícita (regla no negociable #6: modificar
  /// un ciclo cerrado exige esto, nunca ocurre implícito).
  Resultado<Ciclo> reabrir() {
    if (estado == EstadoCiclo.abierto) {
      return Falla('El ciclo $id ya está abierto.');
    }
    return Exito(_conEstado(EstadoCiclo.abierto));
  }

  Ciclo _conEstado(EstadoCiclo nuevo) => Ciclo(
        id: id,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        etiqueta: etiqueta,
        estado: nuevo,
      );

  @override
  bool operator ==(Object other) =>
      other is Ciclo &&
      other.id == id &&
      other.fechaInicio == fechaInicio &&
      other.fechaFin == fechaFin &&
      other.estado == estado;

  @override
  int get hashCode => Object.hash(id, fechaInicio, fechaFin, estado);

  @override
  String toString() =>
      'Ciclo($id, $fechaInicio – $fechaFin, ${estado.name})';
}

/// Calcula a qué [Ciclo] pertenece una fecha, dado el día de corte de
/// tarjeta del usuario (1–31, guardado en su perfil).
final class CalculadoraCiclo {
  final int diaCorte;

  const CalculadoraCiclo(this.diaCorte) : assert(diaCorte >= 1 && diaCorte <= 31);

  Ciclo calcularPara(DateTime fecha) {
    final diaDelMesActual = _diaClampeado(fecha.year, fecha.month, diaCorte);
    final inicioEsteMes = DateTime(fecha.year, fecha.month, diaDelMesActual);

    final DateTime fechaInicio;
    if (!fecha.isBefore(inicioEsteMes)) {
      fechaInicio = inicioEsteMes;
    } else {
      final mesAnteriorAno = fecha.month == 1 ? fecha.year - 1 : fecha.year;
      final mesAnterior = fecha.month == 1 ? 12 : fecha.month - 1;
      final dia = _diaClampeado(mesAnteriorAno, mesAnterior, diaCorte);
      fechaInicio = DateTime(mesAnteriorAno, mesAnterior, dia);
    }

    final mesSigAno =
        fechaInicio.month == 12 ? fechaInicio.year + 1 : fechaInicio.year;
    final mesSig = fechaInicio.month == 12 ? 1 : fechaInicio.month + 1;
    final diaFin = _diaClampeado(mesSigAno, mesSig, diaCorte);
    final fechaFin =
        DateTime(mesSigAno, mesSig, diaFin).subtract(const Duration(days: 1));

    final id = '${fechaInicio.year.toString().padLeft(4, '0')}-'
        '${fechaInicio.month.toString().padLeft(2, '0')}';

    return Ciclo(
      id: id,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      etiqueta: _mesesAbrev[fechaInicio.month - 1],
      estado: EstadoCiclo.abierto,
    );
  }

  static int _diaClampeado(int anio, int mes, int diaDeseado) {
    final diasEnElMes = DateTime(anio, mes + 1, 0).day;
    return diaDeseado > diasEnElMes ? diasEnElMes : diaDeseado;
  }
}

/// Mes natural (AAAA-MM) de una fecha. Cada movimiento guarda este eje
/// además de su [Ciclo.id], para poder cambiar de vista sin recalcular
/// (spec-app-finanzas-v2.md §2.3).
String periodoNatural(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}';
