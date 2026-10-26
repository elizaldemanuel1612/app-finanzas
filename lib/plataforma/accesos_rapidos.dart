import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../core/money.dart';

/// Desde dónde se pidió abrir la app (spec-app-finanzas-v2.md §5.6):
/// el botón "Gasto" del widget abre la captura; "Dictar" y el atajo de voz
/// abren la captura con el dictado ya escuchando.
enum AccesoRapido { gasto, dictar }

/// Puente con el código nativo de iOS (`ios/Runner/AccesosRapidos.swift`)
/// para el widget de inicio y el atajo de Siri — el único código que se
/// escribe dos veces por plataforma (paquete-construccion-final.md §3).
///
/// En Android todavía no hay contraparte (Glance + App Actions están
/// pendientes, ver docs/tiendas/checklist-publicacion.md), así que fuera de
/// iOS todo esto es un no-op y la app se comporta igual que antes.
class AccesosRapidos {
  AccesosRapidos._();

  static const _canal = MethodChannel('app_finanzas/accesos_rapidos');

  static bool get _disponible => !kIsWeb && Platform.isIOS;

  /// Empieza a recibir accesos rápidos. Si la app se abrió en frío desde el
  /// widget o desde Siri, la acción quedó guardada del lado nativo y se
  /// entrega aquí de inmediato.
  static Future<void> escuchar(void Function(AccesoRapido) alAbrir) async {
    if (!_disponible) return;
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method != 'abrir') return;
      final acceso = _desdeTexto(llamada.arguments as String?);
      if (acceso != null) alAbrir(acceso);
    });
    try {
      final pendiente = await _canal.invokeMethod<String>('accionPendiente');
      final acceso = _desdeTexto(pendiente);
      if (acceso != null) alAbrir(acceso);
    } on PlatformException {
      // Sin puente nativo no hay accesos rápidos; la app sigue igual.
    } on MissingPluginException {
      // Ídem.
    }
  }

  /// Desde aquí, lo que llegue se guarda del lado nativo como pendiente
  /// hasta que alguien vuelva a [escuchar] (p. ej., tras cerrar sesión).
  static void dejarDeEscuchar() {
    if (!_disponible) return;
    _canal.setMethodCallHandler(null);
    _canal.invokeMethod<void>('dejarDeEscuchar').catchError((_) {});
  }

  /// Publica al widget cuánto queda hoy. El widget solo muestra lo que se
  /// le manda — nunca calcula por su cuenta (§5.6). Si el App Group no está
  /// disponible (firma con Apple ID gratuito) el lado nativo lo ignora.
  static Future<void> publicarDisponibleHoy(Dinero disponible, DateTime hoy) async {
    if (!_disponible) return;
    final fecha = '${hoy.year.toString().padLeft(4, '0')}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';
    try {
      await _canal.invokeMethod<void>('actualizarWidget', {
        'quedaHoyTexto': disponible.formateado(),
        'fecha': fecha,
      });
    } on PlatformException {
      // El widget se queda con lo último que tenía.
    } on MissingPluginException {
      // Ídem.
    }
  }

  /// Borra lo que el widget muestra (al cerrar sesión o eliminar la
  /// cuenta): el widget vuelve a "Abre la app".
  static Future<void> limpiarWidget() async {
    if (!_disponible) return;
    try {
      await _canal.invokeMethod<void>('limpiarWidget');
    } on PlatformException {
      // Nada que limpiar.
    } on MissingPluginException {
      // Ídem.
    }
  }

  static AccesoRapido? _desdeTexto(String? texto) => switch (texto) {
        'gasto' => AccesoRapido.gasto,
        'dictar' => AccesoRapido.dictar,
        _ => null,
      };
}
