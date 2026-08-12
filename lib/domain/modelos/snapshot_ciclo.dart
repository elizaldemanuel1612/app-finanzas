import '../../core/money.dart';

/// Un renglón congelado del cierre: presupuesto vs. real de una categoría
/// en el momento exacto del cierre.
///
/// [nombre] y [emoji] se **congelan aquí a propósito** — el snapshot tiene
/// que ser autosuficiente, porque después de cerrar el usuario puede
/// renombrar o borrar esa categoría y el histórico no debe cambiar
/// (spec-app-finanzas-v2.md §2.2).
final class RenglonSnapshot {
  final String categoriaId;
  final String nombre;
  final String emoji;
  final Dinero presupuestoCentavos;
  final Dinero realCentavos;
  final int conteoMovimientos;

  const RenglonSnapshot({
    required this.categoriaId,
    required this.nombre,
    required this.emoji,
    required this.presupuestoCentavos,
    required this.realCentavos,
    required this.conteoMovimientos,
  });

  Map<String, dynamic> toJson() => {
        'categoriaId': categoriaId,
        'nombre': nombre,
        'emoji': emoji,
        'presupuestoCentavos': presupuestoCentavos.centavos,
        'realCentavos': realCentavos.centavos,
        'conteoMovimientos': conteoMovimientos,
      };

  factory RenglonSnapshot.fromJson(Map<String, dynamic> json) => RenglonSnapshot(
        categoriaId: json['categoriaId'] as String,
        nombre: json['nombre'] as String,
        emoji: json['emoji'] as String,
        presupuestoCentavos: Dinero(json['presupuestoCentavos'] as int),
        realCentavos: Dinero(json['realCentavos'] as int),
        conteoMovimientos: json['conteoMovimientos'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is RenglonSnapshot &&
      other.categoriaId == categoriaId &&
      other.nombre == nombre &&
      other.emoji == emoji &&
      other.presupuestoCentavos == presupuestoCentavos &&
      other.realCentavos == realCentavos &&
      other.conteoMovimientos == conteoMovimientos;

  @override
  int get hashCode => Object.hash(
        categoriaId,
        nombre,
        emoji,
        presupuestoCentavos,
        realCentavos,
        conteoMovimientos,
      );
}

/// Snapshot inmutable de un ciclo al momento de cerrarlo — el campo
/// `snapshot` del documento `ciclos/{cicloId}` (paquete-construccion-
/// final.md §4). Una vez creado nunca se recalcula: es la fotografía, no
/// una vista derivada (spec-app-finanzas-v2.md §2.2).
final class SnapshotCiclo {
  final String cicloId;
  final DateTime fechaCierre;
  final Dinero ingresoTotal;
  final Dinero metaApartado;
  final Dinero totalGastado;
  final List<RenglonSnapshot> renglones;

  /// Desglose del ingreso extra congelado en el cierre. Opcionales con
  /// `Dinero.cero()` — al revés que en `alcance.dart`, donde van
  /// `required` — porque un snapshot sin extras es el caso normal y el
  /// único que existe hoy en disco; hay construcciones directas en pruebas
  /// que no vale la pena tocar por un campo que casi siempre es cero.
  final Dinero extraAApartado;
  final Dinero extraAGasto;

  const SnapshotCiclo({
    required this.cicloId,
    required this.fechaCierre,
    required this.ingresoTotal,
    required this.metaApartado,
    required this.totalGastado,
    required this.renglones,
    this.extraAApartado = const Dinero.cero(),
    this.extraAGasto = const Dinero.cero(),
  });

  Dinero get apartado => ingresoTotal - totalGastado;

  /// El ingreso base es siempre lo que sobra de restar los extras al
  /// total — se guarda el total y se **deriva** la base, nunca al revés,
  /// para no tener dos fuentes de verdad del mismo número.
  Dinero get ingresoExtra => extraAApartado + extraAGasto;
  Dinero get ingresoBase => ingresoTotal - ingresoExtra;
  Dinero get metaBase => metaApartado - extraAApartado;
  bool get tuvoIngresoExtra => ingresoExtra.esPositivo;

  Map<String, dynamic> toJson() => {
        'cicloId': cicloId,
        'fechaCierre': fechaCierre.toIso8601String(),
        'ingresoTotalCentavos': ingresoTotal.centavos,
        'metaApartadoCentavos': metaApartado.centavos,
        'totalGastadoCentavos': totalGastado.centavos,
        'renglones': renglones.map((r) => r.toJson()).toList(),
        'extraAApartadoCentavos': extraAApartado.centavos,
        'extraAGastoCentavos': extraAGasto.centavos,
      };

  factory SnapshotCiclo.fromJson(Map<String, dynamic> json) => SnapshotCiclo(
        cicloId: json['cicloId'] as String,
        fechaCierre: DateTime.parse(json['fechaCierre'] as String),
        ingresoTotal: Dinero(json['ingresoTotalCentavos'] as int),
        metaApartado: Dinero(json['metaApartadoCentavos'] as int),
        totalGastado: Dinero(json['totalGastadoCentavos'] as int),
        renglones: (json['renglones'] as List<dynamic>)
            .map((r) => RenglonSnapshot.fromJson(r as Map<String, dynamic>))
            .toList(),
        // Snapshots ya escritos antes de que existiera el ingreso extra no
        // traen estas claves: leen cero, que es exactamente lo que tenían.
        extraAApartado: Dinero(json['extraAApartadoCentavos'] as int? ?? 0),
        extraAGasto: Dinero(json['extraAGastoCentavos'] as int? ?? 0),
      );

  @override
  bool operator ==(Object other) =>
      other is SnapshotCiclo &&
      other.cicloId == cicloId &&
      other.fechaCierre == fechaCierre &&
      other.ingresoTotal == ingresoTotal &&
      other.metaApartado == metaApartado &&
      other.totalGastado == totalGastado &&
      other.extraAApartado == extraAApartado &&
      other.extraAGasto == extraAGasto &&
      _mismosRenglones(other.renglones, renglones);

  @override
  int get hashCode => Object.hash(
        cicloId,
        fechaCierre,
        ingresoTotal,
        metaApartado,
        totalGastado,
        extraAApartado,
        extraAGasto,
        Object.hashAll(renglones),
      );
}

bool _mismosRenglones(List<RenglonSnapshot> a, List<RenglonSnapshot> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
