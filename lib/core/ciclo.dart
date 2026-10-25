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

  /// Días que faltan para que termine el ciclo, comparando por fecha (no
  /// por instante — normaliza [hoy] y [fechaFin] a medianoche antes de
  /// restar). `0` = hoy es el último día. Nunca negativo.
  int diasParaTerminar(DateTime hoy) {
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final f = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    final dias = f.difference(h).inDays;
    return dias < 0 ? 0 : dias;
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

/// Un cambio de día de corte (spec-app-finanzas-v2.md §2.4). El ciclo que
/// estaba en curso al hacer el cambio se vuelve el ciclo de transición:
/// conserva su inicio — y su `id`, así que lo ya registrado sigue ahí — y
/// termina el día anterior a [vigenteDesde], el primer ciclo con
/// [diaCorteNuevo]. Lo anterior a [inicioTransicion] sigue calculándose con
/// [diaCorteAnterior]: el historial nunca se reescribe (reglas #5 y #6).
final class CambioDeCorte {
  final int diaCorteAnterior;
  final int diaCorteNuevo;
  final DateTime inicioTransicion;
  final DateTime vigenteDesde;

  CambioDeCorte({
    required this.diaCorteAnterior,
    required this.diaCorteNuevo,
    required DateTime inicioTransicion,
    required DateTime vigenteDesde,
  })  : inicioTransicion = _soloFecha(inicioTransicion),
        vigenteDesde = _soloFecha(vigenteDesde);

  Map<String, dynamic> toJson() => {
        'diaCorteAnterior': diaCorteAnterior,
        'diaCorteNuevo': diaCorteNuevo,
        'inicioTransicion': _textoFecha(inicioTransicion),
        'vigenteDesde': _textoFecha(vigenteDesde),
      };

  factory CambioDeCorte.fromJson(Map<String, dynamic> json) => CambioDeCorte(
        diaCorteAnterior: json['diaCorteAnterior'] as int,
        diaCorteNuevo: json['diaCorteNuevo'] as int,
        inicioTransicion: DateTime.parse(json['inicioTransicion'] as String),
        vigenteDesde: DateTime.parse(json['vigenteDesde'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is CambioDeCorte &&
      other.diaCorteAnterior == diaCorteAnterior &&
      other.diaCorteNuevo == diaCorteNuevo &&
      other.inicioTransicion == inicioTransicion &&
      other.vigenteDesde == vigenteDesde;

  @override
  int get hashCode => Object.hash(diaCorteAnterior, diaCorteNuevo, inicioTransicion, vigenteDesde);

  @override
  String toString() =>
      'CambioDeCorte($diaCorteAnterior → $diaCorteNuevo, transición desde '
      '${_textoFecha(inicioTransicion)}, rige desde ${_textoFecha(vigenteDesde)})';
}

/// Calcula a qué [Ciclo] pertenece una fecha, dado el día de corte de
/// tarjeta del usuario (1–31, guardado en su perfil) y, si lo cambió, su
/// historial de [cambios] en orden cronológico (spec-app-finanzas-v2.md
/// §2.4). Sin cambios, [diaCorte] rige para todas las fechas.
final class CalculadoraCiclo {
  /// Día de corte vigente hoy (el último del historial, si hay cambios).
  final int diaCorte;
  final List<CambioDeCorte> cambios;

  const CalculadoraCiclo(this.diaCorte, {this.cambios = const []})
      : assert(diaCorte >= 1 && diaCorte <= 31);

  Ciclo calcularPara(DateTime fecha) {
    final dia = _soloFecha(fecha);
    for (var i = cambios.length - 1; i >= 0; i--) {
      final cambio = cambios[i];
      if (!dia.isBefore(cambio.vigenteDesde)) {
        return _cicloNormal(dia, cambio.diaCorteNuevo);
      }
      if (!dia.isBefore(cambio.inicioTransicion)) {
        final v = cambio.vigenteDesde;
        return _ciclo(cambio.inicioTransicion, DateTime(v.year, v.month, v.day - 1));
      }
    }
    return _cicloNormal(dia, cambios.isEmpty ? diaCorte : cambios.first.diaCorteAnterior);
  }

  static Ciclo _cicloNormal(DateTime fecha, int diaCorte) {
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

    return _ciclo(fechaInicio, fechaFin);
  }

  static Ciclo _ciclo(DateTime fechaInicio, DateTime fechaFin) {
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

  /// Día de corte real en un mes dado: 31 en un mes de 30 días es el 30.
  static int diaEfectivo(int anio, int mes, int diaDeseado) =>
      _diaClampeado(anio, mes, diaDeseado);

  static int _diaClampeado(int anio, int mes, int diaDeseado) {
    final diasEnElMes = DateTime(anio, mes + 1, 0).day;
    return diaDeseado > diasEnElMes ? diasEnElMes : diaDeseado;
  }
}

DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

String _textoFecha(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-'
    '${f.day.toString().padLeft(2, '0')}';

/// Mes natural (AAAA-MM) de una fecha. Cada movimiento guarda este eje
/// además de su [Ciclo.id], para poder cambiar de vista sin recalcular
/// (spec-app-finanzas-v2.md §2.3).
String periodoNatural(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}';
