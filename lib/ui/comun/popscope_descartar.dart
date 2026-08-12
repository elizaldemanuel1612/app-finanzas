import 'package:flutter/material.dart';

import 'tema.dart';

/// `PopScope` reutilizable para pantallas de captura con estado sin
/// guardar (Fase 6, Bloque 4.4 — renglón del §3 "Botón atrás", en cero
/// hasta esta fase). Envuelve el `Scaffold` de la pantalla e intercepta
/// el gesto de salir — back físico, gesto de swipe en iOS, botón de la
/// AppBar — mostrando el mismo diálogo de confirmación en todas las
/// pantallas de captura, en vez de reimplementarlo 6 veces.
///
/// [hayCambiosSinGuardar] es una función y no un valor porque se evalúa
/// en el momento del gesto de salida, no al construir el widget — el
/// estado de la pantalla cambia con cada tecleo.
class PopScopeDescartar extends StatelessWidget {
  final bool Function() hayCambiosSinGuardar;
  final Widget child;

  const PopScopeDescartar({
    super.key,
    required this.hayCambiosSinGuardar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hayCambiosSinGuardar(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final descartar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Descartar lo capturado?'),
            content: const Text(
              'Vas a perder lo que llevas escrito si sales ahora.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir editando'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ColoresApp.coralTexto,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (descartar == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
