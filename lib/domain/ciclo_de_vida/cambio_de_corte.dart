import '../../core/ciclo.dart';
import '../modelos/perfil.dart';

/// Una forma de pasar al día de corte nuevo (spec-app-finanzas-v2.md §2.4):
/// el ciclo en curso se vuelve de transición, de [inicio] a [fin], y el
/// primer ciclo con el corte nuevo empieza en [vigenteDesde].
final class OpcionTransicion {
  final DateTime inicio;
  final DateTime fin;
  final DateTime vigenteDesde;

  /// La de duración más cercana a 30 días (en empate, la más corta).
  final bool recomendada;

  const OpcionTransicion({
    required this.inicio,
    required this.fin,
    required this.vigenteDesde,
    required this.recomendada,
  });

  /// Días del ciclo de transición, contando inicio y fin. Con fechas UTC
  /// para que un cambio de horario no le reste un día.
  int get dias =>
      DateTime.utc(fin.year, fin.month, fin.day)
          .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
          .inDays +
      1;
}

/// Lo que la pantalla le enseña al usuario antes de cambiar el corte.
final class PropuestaCambioDeCorte {
  /// Día de corte que rige hoy (si había un cambio pendiente, el de antes
  /// de ese cambio: el pendiente se reemplaza, no se encadena).
  final int diaVigente;
  final int diaNuevo;

  /// El ciclo en curso tal como queda sin ningún cambio pendiente.
  final Ciclo cicloActual;

  /// Vacío cuando [diaNuevo] es el mismo que [diaVigente]: no hay nada que
  /// hacer, salvo cancelar un cambio pendiente si lo había.
  final List<OpcionTransicion> opciones;

  /// Había un cambio que todavía no entraba en vigor.
  final bool habiaPendiente;

  /// Historial sin el cambio pendiente: la base sobre la que se aplica.
  final List<CambioDeCorte> _historialBase;

  const PropuestaCambioDeCorte._(
    this._historialBase, {
    required this.diaVigente,
    required this.diaNuevo,
    required this.cicloActual,
    required this.opciones,
    required this.habiaPendiente,
  });

  bool get esMismoDia => diaNuevo == diaVigente;
}

/// Arma las opciones de transición para pasar a [diaNuevo] sin tocar el
/// historial (spec-app-finanzas-v2.md §2.4):
///
/// - El ciclo en curso se vuelve el de transición: conserva su inicio y su
///   `id`, así que lo ya registrado sigue ahí.
/// - Se ofrecen las dos primeras fechas con el día nuevo que caen después
///   de hoy (la transición siempre incluye hoy) y en un mes posterior al
///   inicio del ciclo en curso (los `id` AAAA-MM nunca se repiten).
/// - Si había un cambio pendiente (aún no rige), se reemplaza.
PropuestaCambioDeCorte proponerCambioDeCorte({
  required Perfil perfil,
  required int diaNuevo,
  required DateTime hoy,
}) {
  assert(diaNuevo >= 1 && diaNuevo <= 31);
  final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);

  final cambios = perfil.cambiosDeCorte;
  final hayPendiente = cambios.isNotEmpty && cambios.last.vigenteDesde.isAfter(hoyDia);
  final base = hayPendiente ? cambios.sublist(0, cambios.length - 1) : cambios;
  final diaVigente = hayPendiente ? cambios.last.diaCorteAnterior : perfil.diaCorte;
  final cicloActual = CalculadoraCiclo(diaVigente, cambios: base).calcularPara(hoyDia);

  final opciones = <OpcionTransicion>[];
  if (diaNuevo != diaVigente) {
    final inicio = cicloActual.fechaInicio;
    final candidatas = <DateTime>[];
    var anio = inicio.year;
    var mes = inicio.month;
    while (candidatas.length < 2) {
      mes += 1;
      if (mes == 13) {
        mes = 1;
        anio += 1;
      }
      final fecha = DateTime(anio, mes, CalculadoraCiclo.diaEfectivo(anio, mes, diaNuevo));
      if (fecha.isAfter(hoyDia)) candidatas.add(fecha);
    }

    final sinMarca = [
      for (final v in candidatas)
        OpcionTransicion(
          inicio: inicio,
          fin: DateTime(v.year, v.month, v.day - 1),
          vigenteDesde: v,
          recomendada: false,
        ),
    ];
    var mejor = 0;
    for (var i = 1; i < sinMarca.length; i++) {
      if ((sinMarca[i].dias - 30).abs() < (sinMarca[mejor].dias - 30).abs()) mejor = i;
    }
    for (var i = 0; i < sinMarca.length; i++) {
      final o = sinMarca[i];
      opciones.add(OpcionTransicion(
        inicio: o.inicio,
        fin: o.fin,
        vigenteDesde: o.vigenteDesde,
        recomendada: i == mejor,
      ));
    }
  }

  return PropuestaCambioDeCorte._(
    base,
    diaVigente: diaVigente,
    diaNuevo: diaNuevo,
    cicloActual: cicloActual,
    opciones: opciones,
    habiaPendiente: hayPendiente,
  );
}

/// El perfil con el corte nuevo, usando la [opcion] que eligió el usuario.
/// Sin [opcion] (el día nuevo es el que ya regía) solo se cancela el
/// cambio pendiente, si había uno.
Perfil aplicarCambioDeCorte({
  required Perfil perfil,
  required PropuestaCambioDeCorte propuesta,
  OpcionTransicion? opcion,
}) {
  if (opcion == null) {
    return perfil.copyWith(diaCorte: propuesta.diaVigente, cambiosDeCorte: propuesta._historialBase);
  }
  return perfil.copyWith(
    diaCorte: propuesta.diaNuevo,
    cambiosDeCorte: [
      ...propuesta._historialBase,
      CambioDeCorte(
        diaCorteAnterior: propuesta.diaVigente,
        diaCorteNuevo: propuesta.diaNuevo,
        inicioTransicion: opcion.inicio,
        vigenteDesde: opcion.vigenteDesde,
      ),
    ],
  );
}

/// El cambio que todavía no entra en vigor, si hay uno — para avisarle al
/// usuario en Ajustes que su ciclo actual es de transición.
CambioDeCorte? cambioPendiente(Perfil perfil, DateTime hoy) {
  final cambios = perfil.cambiosDeCorte;
  if (cambios.isEmpty) return null;
  final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
  return cambios.last.vigenteDesde.isAfter(hoyDia) ? cambios.last : null;
}
