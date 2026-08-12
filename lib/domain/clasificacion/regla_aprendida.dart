import 'normalizacion_texto.dart';

/// Una regla de clasificación aprendida de las correcciones del usuario
/// (spec-app-finanzas-v2.md §6.2): "Oxxo" → Súper/Comida, con un contador
/// de cuántas veces se ha confirmado. Es el Nivel 1 de la cascada
/// (§6.1) — instantáneo, gratis, offline, y el único nivel que no
/// necesita umbral de confianza: si el patrón coincide, se aplica.
final class ReglaAprendida {
  /// Ya normalizado (ver [normalizarTexto]) — así se guarda listo para
  /// comparar, sin normalizar en cada clasificación.
  final String patron;
  final String categoriaId;
  final int contador;

  const ReglaAprendida({
    required this.patron,
    required this.categoriaId,
    required this.contador,
  });

  ReglaAprendida copyWith({int? contador}) => ReglaAprendida(
        patron: patron,
        categoriaId: categoriaId,
        contador: contador ?? this.contador,
      );

  Map<String, dynamic> toJson() => {
        'patron': patron,
        'categoriaId': categoriaId,
        'contador': contador,
      };

  factory ReglaAprendida.fromJson(Map<String, dynamic> json) => ReglaAprendida(
        patron: json['patron'] as String,
        categoriaId: json['categoriaId'] as String,
        contador: json['contador'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is ReglaAprendida &&
      other.patron == patron &&
      other.categoriaId == categoriaId &&
      other.contador == contador;

  @override
  int get hashCode => Object.hash(patron, categoriaId, contador);

  @override
  String toString() => 'ReglaAprendida("$patron" → $categoriaId, x$contador)';
}

/// Registra una corrección del usuario (§6.2): si ya existe una regla
/// para ese [patron] con esa [categoriaId], le suma uno al contador; si
/// no, crea una regla nueva. [patron] se normaliza aquí.
List<ReglaAprendida> registrarCorreccion({
  required List<ReglaAprendida> reglasActuales,
  required String patron,
  required String categoriaId,
}) {
  final patronNormalizado = normalizarTexto(patron);
  if (patronNormalizado.isEmpty) return reglasActuales;

  final indice = reglasActuales.indexWhere(
    (r) => r.patron == patronNormalizado && r.categoriaId == categoriaId,
  );

  if (indice == -1) {
    return [
      ...reglasActuales,
      ReglaAprendida(patron: patronNormalizado, categoriaId: categoriaId, contador: 1),
    ];
  }

  final actualizadas = [...reglasActuales];
  actualizadas[indice] = actualizadas[indice].copyWith(contador: actualizadas[indice].contador + 1);
  return actualizadas;
}

/// Borrado en cascada: al eliminar una categoría, las reglas que
/// clasificaban hacia ella quedarían apuntando a nada — se descartan aquí
/// en vez de dejarlas huérfanas.
List<ReglaAprendida> quitarReglasDeCategoria({
  required List<ReglaAprendida> reglas,
  required String categoriaId,
}) =>
    reglas.where((r) => r.categoriaId != categoriaId).toList();
