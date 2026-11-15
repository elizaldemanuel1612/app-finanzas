import '../../core/money.dart';
import '../clasificacion/normalizacion_texto.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';

// Gastos que se repiten (spec-app-finanzas-v2.md §5.7, "Lo que se repite",
// 2026-11-15): suscripciones y pagos periódicos detectados por descripción
// y monto. Solo informa.

enum FrecuenciaRecurrente {
  semanal('Cada semana', 52, 6, 8),
  quincenal('Cada quincena', 26, 13, 17),
  mensual('Cada mes', 12, 26, 35),
  anual('Cada año', 1, 350, 380);

  final String etiqueta;

  /// Cuántas veces al año.
  final int vecesAlAnio;
  final int diasMin;
  final int diasMax;

  const FrecuenciaRecurrente(this.etiqueta, this.vecesAlAnio, this.diasMin, this.diasMax);

  static FrecuenciaRecurrente? deIntervalo(double dias) {
    for (final f in values) {
      if (dias >= f.diasMin && dias <= f.diasMax) return f;
    }
    return null;
  }
}

final class GastoRecurrente {
  /// La descripción del pago más reciente, como se escribió.
  final String nombre;
  final String categoriaId;
  final FrecuenciaRecurrente frecuencia;

  /// El último monto pagado (si subió de precio, el nuevo).
  final Dinero monto;
  final DateTime ultimo;
  final DateTime proximo;
  final int veces;

  const GastoRecurrente({
    required this.nombre,
    required this.categoriaId,
    required this.frecuencia,
    required this.monto,
    required this.ultimo,
    required this.proximo,
    required this.veces,
  });

  Dinero get alAnio => Dinero(monto.centavos * frecuencia.vecesAlAnio);
}

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

int _diasEntre(DateTime a, DateTime b) => (b.difference(a).inHours / 24).round();

double _mediana(List<num> valores) {
  final orden = [...valores]..sort();
  final mitad = orden.length ~/ 2;
  return orden.length.isOdd ? orden[mitad].toDouble() : (orden[mitad - 1] + orden[mitad]) / 2;
}

/// El próximo pago: el mismo día del mes (o del año) siguiente para
/// mensual y anual —en meses cortos, el último—; para semanal y quincenal,
/// el último más la mediana de días.
DateTime _siguiente(DateTime ultimo, FrecuenciaRecurrente frecuencia, double mediana) {
  DateTime enDia(int anio, int mes) {
    final fin = DateTime(anio, mes + 1, 0).day;
    return DateTime(anio, mes, ultimo.day < fin ? ultimo.day : fin);
  }

  return switch (frecuencia) {
    FrecuenciaRecurrente.mensual => enDia(ultimo.year, ultimo.month + 1),
    FrecuenciaRecurrente.anual => enDia(ultimo.year + 1, ultimo.month),
    _ => ultimo.add(Duration(days: mediana.round())),
  };
}

/// Clave para juntar descripciones: sin acentos, mayúsculas ni signos.
String _clave(String descripcion) =>
    normalizarTexto(descripcion).replaceAll(RegExp(r'[^a-zñ0-9]+'), ' ').trim();

/// Los gastos que se repiten y siguen vigentes a [hoy], del que más cuesta
/// al año al que menos.
List<GastoRecurrente> detectarRecurrentes(List<Movimiento> movimientos, {required DateTime hoy}) {
  final grupos = <String, List<Movimiento>>{};
  for (final m in movimientos) {
    if (m.estado != EstadoMovimiento.activo) continue;
    final clave = _clave(m.descripcion);
    if (clave.isEmpty) continue;
    (grupos[clave] ??= []).add(m);
  }

  final resultado = <GastoRecurrente>[];
  for (final grupo in grupos.values) {
    grupo.sort((a, b) => a.fecha.compareTo(b.fecha));
    // Un pago por día: dos el mismo día no hacen frecuencia.
    final porDia = <DateTime, Movimiento>{};
    for (final m in grupo) {
      porDia[_dia(m.fecha)] = m;
    }
    final pagos = porDia.values.toList();
    if (pagos.length < 2) continue;

    final intervalos = [for (var i = 1; i < pagos.length; i++) _diasEntre(_dia(pagos[i - 1].fecha), _dia(pagos[i].fecha))];
    final mediana = _mediana(intervalos);
    final frecuencia = FrecuenciaRecurrente.deIntervalo(mediana);
    if (frecuencia == null) continue;
    if (pagos.length < (frecuencia == FrecuenciaRecurrente.anual ? 2 : 3)) continue;
    if (intervalos.any((d) => d < mediana * 0.7 || d > mediana * 1.3)) continue;

    final montoMediano = _mediana([for (final m in pagos) m.monto.centavos]);
    final parecidos = pagos.where((m) => (m.monto.centavos - montoMediano).abs() <= montoMediano * 0.25).length;
    if (parecidos * 4 < pagos.length * 3) continue;

    final ultimo = pagos.last;
    final diaUltimo = _dia(ultimo.fecha);
    // Vigente: el último pago no se quedó muy atrás.
    if (_diasEntre(diaUltimo, _dia(hoy)) > mediana * 1.5) continue;

    resultado.add(GastoRecurrente(
      nombre: ultimo.descripcion.trim(),
      categoriaId: ultimo.categoriaId,
      frecuencia: frecuencia,
      monto: ultimo.monto,
      ultimo: diaUltimo,
      proximo: _siguiente(diaUltimo, frecuencia, mediana),
      veces: pagos.length,
    ));
  }
  return resultado..sort((a, b) => b.alAnio.centavos.compareTo(a.alAnio.centavos));
}

/// Cuánto suman al año.
Dinero totalAlAnio(List<GastoRecurrente> recurrentes) =>
    Dinero(recurrentes.fold<int>(0, (s, r) => s + r.alAnio.centavos));
