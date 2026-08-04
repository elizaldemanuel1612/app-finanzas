import '../../core/money.dart';

/// El tipo de categoría **lo declara el usuario** al crearla, nunca se
/// infiere del nombre (regla no negociable #8) — lo que es fijo para una
/// persona (renta) es variable para otra. Por eso [Categoria] es una
/// jerarquía sellada en vez de un campo `tipo` con datos opcionales sueltos:
/// el compilador impide construir una fija sin su monto y día, o una
/// variable sin su presupuesto.
sealed class Categoria {
  final String id;
  final String nombre;
  final String emoji;
  final bool activa;

  /// Piso del plan de ajuste (addendum-v3 §2.6): nunca se sugiere gastar
  /// por debajo de un mínimo digno en categorías necesarias.
  final bool esNecesaria;

  const Categoria({
    required this.id,
    required this.nombre,
    required this.emoji,
    required this.activa,
    required this.esNecesaria,
  });

  /// Nombres de campo iguales a los del documento `categorias/{catId}`
  /// (paquete-construccion-final.md §4). `tipo` es el discriminador que
  /// [Categoria.fromJson] usa para reconstruir la subclase correcta.
  Map<String, dynamic> toJson();

  static Categoria fromJson(Map<String, dynamic> json) =>
      switch (json['tipo'] as String) {
        'fija' => CategoriaFija(
            id: json['id'] as String,
            nombre: json['nombre'] as String,
            emoji: json['emoji'] as String,
            activa: json['activa'] as bool,
            esNecesaria: json['esNecesaria'] as bool,
            montoFijoCentavos: Dinero(json['montoFijoCentavos'] as int),
            diaDelCiclo: json['diaDelCiclo'] as int,
          ),
        'variable' => CategoriaVariable(
            id: json['id'] as String,
            nombre: json['nombre'] as String,
            emoji: json['emoji'] as String,
            activa: json['activa'] as bool,
            esNecesaria: json['esNecesaria'] as bool,
            presupuestoMensualCentavos:
                Dinero(json['presupuestoMensualCentavos'] as int),
          ),
        final otro => throw FormatException('Tipo de categoría desconocido: $otro'),
      };
}

/// No se pronostica, no entra al plan de ajuste, no se rebalancea (reglas
/// no negociables #9, #10). Se suma el monto conocido en su fecha.
final class CategoriaFija extends Categoria {
  final Dinero montoFijoCentavos;

  /// Día del ciclo en que se genera/paga (1–31).
  final int diaDelCiclo;

  const CategoriaFija({
    required super.id,
    required super.nombre,
    required super.emoji,
    required super.activa,
    required super.esNecesaria,
    required this.montoFijoCentavos,
    required this.diaDelCiclo,
  }) : assert(diaDelCiclo >= 1 && diaDelCiclo <= 31);

  @override
  Map<String, dynamic> toJson() => {
        'tipo': 'fija',
        'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'activa': activa,
        'esNecesaria': esNecesaria,
        'montoFijoCentavos': montoFijoCentavos.centavos,
        'diaDelCiclo': diaDelCiclo,
      };

  @override
  bool operator ==(Object other) =>
      other is CategoriaFija &&
      other.id == id &&
      other.montoFijoCentavos == montoFijoCentavos &&
      other.diaDelCiclo == diaDelCiclo;

  @override
  int get hashCode => Object.hash(id, montoFijoCentavos, diaDelCiclo);
}

/// Se pronostica con el motor MPC (domain/pronostico/, fuera del alcance de
/// la Fase 0). Entra al plan de ajuste y al rebalanceo.
final class CategoriaVariable extends Categoria {
  final Dinero presupuestoMensualCentavos;

  const CategoriaVariable({
    required super.id,
    required super.nombre,
    required super.emoji,
    required super.activa,
    required super.esNecesaria,
    required this.presupuestoMensualCentavos,
  });

  @override
  Map<String, dynamic> toJson() => {
        'tipo': 'variable',
        'id': id,
        'nombre': nombre,
        'emoji': emoji,
        'activa': activa,
        'esNecesaria': esNecesaria,
        'presupuestoMensualCentavos': presupuestoMensualCentavos.centavos,
      };

  @override
  bool operator ==(Object other) =>
      other is CategoriaVariable &&
      other.id == id &&
      other.presupuestoMensualCentavos == presupuestoMensualCentavos;

  @override
  int get hashCode => Object.hash(id, presupuestoMensualCentavos);
}
