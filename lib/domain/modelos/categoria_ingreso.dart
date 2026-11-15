/// De dónde viene el dinero que entra a una cuenta: Nómina, Rentas,
/// Inversiones… (spec-app-finanzas-v2.md §7.3.4). Aparte de las categorías
/// de gasto (`categoria.dart`): no lleva presupuesto ni tipo. Se archiva
/// ([activa] en `false`), nunca se borra.
final class CategoriaIngreso {
  final String id;
  final String nombre;
  final String emoji;
  final bool activa;

  const CategoriaIngreso({required this.id, required this.nombre, required this.emoji, this.activa = true});

  CategoriaIngreso copyWith({String? nombre, String? emoji, bool? activa}) => CategoriaIngreso(
        id: id,
        nombre: nombre ?? this.nombre,
        emoji: emoji ?? this.emoji,
        activa: activa ?? this.activa,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'emoji': emoji, 'activa': activa};

  factory CategoriaIngreso.fromJson(Map<String, dynamic> json) => CategoriaIngreso(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        emoji: json['emoji'] as String,
        activa: json['activa'] as bool? ?? true,
      );
}

/// Las que se crean la primera vez; el usuario las cambia a su gusto.
const categoriasIngresoSugeridas = [
  CategoriaIngreso(id: 'ing-nomina', nombre: 'Nómina', emoji: '💼'),
  CategoriaIngreso(id: 'ing-rentas', nombre: 'Rentas', emoji: '🏠'),
  CategoriaIngreso(id: 'ing-inversiones', nombre: 'Inversiones', emoji: '📈'),
  CategoriaIngreso(id: 'ing-ventas', nombre: 'Ventas', emoji: '🛍️'),
  CategoriaIngreso(id: 'ing-regalos', nombre: 'Regalos', emoji: '🎁'),
  CategoriaIngreso(id: 'ing-otros', nombre: 'Otros ingresos', emoji: '➕'),
];
