import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../data/ia/clientes_ia.dart';

/// Si se puede usar Apple Intelligence en este dispositivo.
enum EstadoApple {
  disponible('Lista para usarse'),
  apagado('Actívala en Ajustes del iPhone → Apple Intelligence y Siri'),
  descargando('Tu iPhone aún está descargando el modelo; intenta más tarde'),
  noCompatible('Este iPhone no tiene Apple Intelligence'),
  noSoportado('Solo en la app del iPhone, con iOS 26 o posterior');

  final String explicacion;
  const EstadoApple(this.explicacion);
}

/// Puente con `ios/Runner/AccesosRapidos.swift` (`IAApple`): el modelo de
/// Apple que corre en el iPhone (spec §6.5). Fuera del iPhone no existe.
final class IAApple implements ClienteIA {
  const IAApple();

  static const _canal = MethodChannel('app_finanzas/ia_apple');

  static bool get posible => !kIsWeb && Platform.isIOS;

  /// Lo que hay en el modelo de Apple: poco contexto. El asistente manda
  /// solo los temas de la guía que más se parecen a la pregunta.
  static const maxCaracteresInstructivo = 6000;

  static Future<EstadoApple> estado() async {
    if (!posible) return EstadoApple.noSoportado;
    try {
      final nombre = await _canal.invokeMethod<String>('estado');
      return EstadoApple.values.where((e) => e.name == nombre).firstOrNull ?? EstadoApple.noSoportado;
    } catch (_) {
      return EstadoApple.noSoportado;
    }
  }

  @override
  Future<String> responder({
    required String sistema,
    required List<MensajeIA> mensajes,
    int maxTokens = 800,
    bool json = false,
  }) async {
    try {
      final texto = await _canal.invokeMethod<String>('responder', {
        'sistema': json ? '$sistema\nResponde únicamente con el JSON.' : sistema,
        'mensajes': [
          for (final m in mensajes) {'usuario': m.delUsuario, 'texto': m.texto},
        ],
      });
      final limpio = (texto ?? '').trim();
      if (limpio.isEmpty) throw const ErrorIA('Apple Intelligence no dio respuesta. Prueba a preguntarlo de otra forma.');
      return limpio;
    } on PlatformException catch (e) {
      throw ErrorIA('Apple Intelligence no pudo responder: ${e.message ?? e.code}.');
    } on MissingPluginException {
      throw const ErrorIA('Apple Intelligence solo funciona en la app del iPhone.');
    }
  }
}

extension CategoriaDeGastoApple on IAApple {
  /// La categoría de un gasto dicho (spec §5.6.3): el modelo elige solo
  /// entre [opciones] (generación guiada). `null` si no pudo.
  Future<String?> categoriaDeGasto({
    required String instrucciones,
    required String mensaje,
    required List<String> opciones,
  }) async {
    try {
      return await IAApple._canal.invokeMethod<String>('categoriaDeGasto', {
        'instrucciones': instrucciones,
        'mensaje': mensaje,
        'opciones': opciones,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// El cliente de Apple si este dispositivo puede tenerlo.
ClienteIA? clienteAppleSiAplica() => IAApple.posible ? const IAApple() : null;
