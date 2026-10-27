import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tema.dart';

/// Claro, oscuro o lo que diga el teléfono (2026-10-26). Es una preferencia
/// del dispositivo, no de la cuenta: no viaja en el respaldo y aplica desde
/// la pantalla de inicio de sesión.
enum Apariencia {
  sistema('Automático', 'Igual que tu teléfono', ThemeMode.system),
  claro('Claro', 'Fondo marfil', ThemeMode.light),
  oscuro('Oscuro', 'Fondo azul noche', ThemeMode.dark);

  final String etiqueta;
  final String detalle;
  final ThemeMode modo;

  const Apariencia(this.etiqueta, this.detalle, this.modo);
}

abstract final class AparienciaApp {
  static const _clave = 'apariencia';
  static final actual = ValueNotifier<Apariencia>(Apariencia.sistema);

  /// Antes de `runApp`, para que el primer cuadro ya salga en su modo.
  static Future<void> cargar() async {
    try {
      final guardada = await SharedPreferencesAsync().getString(_clave);
      actual.value = Apariencia.values.firstWhere(
        (a) => a.name == guardada,
        orElse: () => Apariencia.sistema,
      );
    } catch (_) {
      // Sin almacenamiento disponible: se queda en automático.
    }
  }

  static Future<void> elegir(Apariencia apariencia) async {
    actual.value = apariencia;
    try {
      await SharedPreferencesAsync().setString(_clave, apariencia.name);
    } catch (_) {}
  }
}

/// Va en `MaterialApp.builder`: deja en [ColoresApp] la paleta del tema ya
/// resuelto (claro, oscuro o el del sistema) y, si cambió, reconstruye todo
/// el árbol una vez. Hace falta porque `ColoresApp` son getters globales,
/// no una dependencia de `Theme.of`: sin esto, lo que no dependa del tema
/// se quedaría con los colores anteriores. El estado (pantallas abiertas,
/// lo capturado) se conserva: se marcan los elementos, no se recrean.
class SincronizarPaleta extends StatelessWidget {
  final Widget child;

  const SincronizarPaleta({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    if (ColoresApp.usar(oscuro ? Paleta.oscura : Paleta.clara)) {
      final raiz = context as Element;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        void marcar(Element e) {
          e.markNeedsBuild();
          e.visitChildren(marcar);
        }

        if (raiz.mounted) raiz.visitChildren(marcar);
      });
    }
    // Hora y batería claras sobre fondo oscuro (y al revés) en las
    // pantallas sin barra superior, como Inicio.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child,
    );
  }
}
