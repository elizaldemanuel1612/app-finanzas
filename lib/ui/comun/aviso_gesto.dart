import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los gestos que no se ven a simple vista. Cada uno explica qué hizo la
/// primera vez que se usa, por si el usuario no leyó la guía (2026-10-31).
enum GestoApp {
  duplicarGasto(
    'Gasto duplicado con la fecha de hoy. Eso hace deslizar a la derecha; '
    'si no querías, deslízalo a la izquierda para eliminarlo.',
  ),
  eliminarGasto(
    'Deslizar a la izquierda elimina el gasto, siempre preguntando antes. '
    'Deslizar a la derecha lo duplica.',
  ),
  eliminarCategoria('Deslizar una categoría a la izquierda sirve para eliminarla, siempre preguntando antes.'),
  recargar('Deslizar hacia abajo actualiza la pantalla.');

  final String explicacion;

  const GestoApp(this.explicacion);
}

/// Lo ya mostrado en esta sesión, por si no hay almacenamiento disponible.
final _yaMostrados = <GestoApp>{};

@visibleForTesting
void reiniciarAvisosDeGesto() => _yaMostrados.clear();

/// Muestra la explicación de [gesto] si es la primera vez en este
/// dispositivo, y dice si la mostró. Se guarda como la apariencia: es una
/// preferencia del dispositivo, no viaja en el respaldo.
Future<bool> avisarGestoPrimeraVez(BuildContext context, GestoApp gesto) async {
  if (!_yaMostrados.add(gesto)) return false;
  final clave = 'aviso_gesto_${gesto.name}';
  try {
    final preferencias = SharedPreferencesAsync();
    if (await preferencias.getBool(clave) == true) return false;
    await preferencias.setBool(clave, true);
  } catch (_) {
    // Sin almacenamiento: al menos no se repite en esta sesión.
  }
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(gesto.explicacion), duration: const Duration(seconds: 6)),
  );
  return true;
}
