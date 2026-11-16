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
  ///
  /// [alCambiarDatos]: Siri registró un gasto sin abrir la app (§5.6.3) y
  /// lo que está en pantalla debe recargarse.
  static Future<void> escuchar(void Function(AccesoRapido) alAbrir, {void Function()? alCambiarDatos}) async {
    if (!_disponible) return;
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'datosCambiaron') {
        alCambiarDatos?.call();
        return;
      }
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
  /// Lo que muestra el widget (2026-11-15, como el héroe de Inicio): lo
  /// gastado en variables del ciclo y de cuánto.
  static Future<void> publicarGastado(Dinero gastado, Dinero presupuesto, DateTime hoy) async {
    if (!_disponible) return;
    try {
      await _canal.invokeMethod<void>('actualizarWidget', datosDelWidget(gastado, presupuesto, hoy));
    } on PlatformException {
      // El widget se queda con lo último que tenía.
    } on MissingPluginException {
      // Ídem.
    }
  }

  /// Lo que guarda el widget; también lo manda Siri al registrar (§5.6.3).
  static Map<String, String> datosDelWidget(Dinero gastado, Dinero presupuesto, DateTime hoy) => {
        // La clave se llama así desde que mostraba "Hoy puedes gastar".
        'quedaHoyTexto': gastado.formateado(),
        // Sin presupuestos (spec §7.3.6) solo va lo gastado.
        'deTexto': presupuesto.esPositivo ? 'de ${presupuesto.formateado()}' : '',
        'fecha': '${hoy.year.toString().padLeft(4, '0')}-'
            '${hoy.month.toString().padLeft(2, '0')}-'
            '${hoy.day.toString().padLeft(2, '0')}',
      };

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
