import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/ia/proveedor_ia.dart';

/// Un turno de la conversación.
final class MensajeIA {
  final bool delUsuario;
  final String texto;
  const MensajeIA.usuario(this.texto) : delUsuario = true;
  const MensajeIA.asistente(this.texto) : delUsuario = false;
}

/// Lo que salió mal, en palabras para el usuario.
final class ErrorIA implements Exception {
  final String mensaje;

  /// El código HTTP, si la IA contestó con error.
  final int? codigo;
  const ErrorIA(this.mensaje, {this.codigo});

  /// El modelo está saturado o llegó a su límite: con otro modelo puede
  /// salir (los límites de la clave gratis son por modelo).
  bool get saturado => codigo == 429 || (codigo ?? 0) >= 500;
  @override
  String toString() => mensaje;
}

/// Una IA a la que se le puede preguntar (spec §6.5).
abstract interface class ClienteIA {
  Future<String> responder({
    required String sistema,
    required List<MensajeIA> mensajes,
    int maxTokens = 800,
    bool json = false,
  });
}

/// La de API: Gemini, con la clave del usuario. La app le habla directo;
/// nada pasa por servidores propios. ChatGPT y Claude se quitaron el
/// 2026-11-15: su API se cobra aparte de la suscripción (spec §6.5).
abstract base class ClienteApi implements ClienteIA {
  final String clave;
  final String? modelo;
  final http.Client _http;
  ClienteApi(this.clave, {this.modelo, http.Client? cliente}) : _http = cliente ?? http.Client();

  /// Los ids de modelos que la clave puede usar; también sirve para probar
  /// que la clave funciona.
  Future<List<String>> listarModelos();

  ErrorIA _errorDe(http.Response r, ProveedorIA p) {
    final c = r.statusCode;
    return switch (c) {
      400 when r.body.contains('API_KEY') || r.body.contains('API key') =>
        ErrorIA('La clave no es válida. Revísala en ${p.sitioClave}.', codigo: c),
      401 || 403 => ErrorIA('La clave no es válida o no tiene permiso. Revísala en ${p.sitioClave}.', codigo: c),
      402 => ErrorIA('Tu cuenta de la IA no tiene saldo para usarla.', codigo: c),
      429 => ErrorIA('Llegaste al límite de uso gratis de tu IA por ahora. Intenta más tarde.', codigo: c),
      >= 500 => ErrorIA(
          'Los servidores de tu IA están saturados ahorita (con la clave gratis pasa seguido). Intenta en un momento.',
          codigo: c),
      _ => ErrorIA('Tu IA no pudo responder (código $c).', codigo: c),
    };
  }

  Future<Map<String, dynamic>> _enviar(ProveedorIA p, Future<http.Response> Function() peticion) async {
    final http.Response r;
    try {
      r = await peticion().timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw const ErrorIA('Tu IA tardó demasiado en responder. Intenta de nuevo.');
    } catch (_) {
      throw const ErrorIA('No hay conexión con tu IA. Revisa tu internet.');
    }
    if (r.statusCode != 200) throw _errorDe(r, p);
    try {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ErrorIA('No entendí la respuesta de tu IA.');
    }
  }

  String get _modelo => modelo ?? (throw const ErrorIA('Vuelve a conectar tu IA en Ajustes → Complementos de IA.'));
}

final class ClienteGemini extends ClienteApi {
  /// Cuánto esperar antes de reintentar un modelo saturado.
  final Duration espera;
  ClienteGemini(super.clave, {super.modelo, super.cliente, this.espera = const Duration(milliseconds: 1200)});

  /// El modelo de respaldo que funcionó, por clave y modelo elegido, y
  /// cuándo: durante media hora se usa directo en vez del saturado.
  static final _respaldo = <String, (String, DateTime)>{};
  static const _vigenciaRespaldo = Duration(minutes: 30);

  /// Olvida los respaldos recordados (para las pruebas).
  static void olvidarRespaldos() => _respaldo.clear();
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  Map<String, String> get _cabeceras => {'x-goog-api-key': clave, 'content-type': 'application/json'};

  @override
  Future<List<String>> listarModelos() async {
    final datos = await _enviar(ProveedorIA.gemini, () => _http.get(Uri.parse('$_base/models?pageSize=1000'), headers: _cabeceras));
    return [
      for (final m in (datos['models'] as List? ?? const []))
        if (((m as Map)['supportedGenerationMethods'] as List? ?? const []).contains('generateContent')) m['name'] as String,
    ];
  }

  /// Cómo pedirle al modelo que no "piense" antes de contestar: lo que
  /// piensa cuenta contra `maxOutputTokens` y, en respuestas cortas (la
  /// categoría de un gasto), se lo acababa todo y la respuesta salía vacía.
  /// Los 2.5 flash lo apagan con `thinkingBudget: 0`; del 3 en adelante es
  /// `thinkingLevel` (y mandar los dos da error). Otros modelos, nada.
  static Map<String, Object>? configuracionDePensar(String modelo) {
    final id = modelo.toLowerCase();
    if (!id.contains('flash')) return null;
    final version = RegExp(r'gemini-(\d+)(?:\.(\d+))?').firstMatch(id);
    final mayor = int.tryParse(version?.group(1) ?? '');
    if (mayor == null) return null;
    if (mayor >= 3) return {'thinkingLevel': 'minimal'};
    if (mayor == 2 && version?.group(2) == '5') return {'thinkingBudget': 0};
    return null;
  }

  Future<http.Response> _generar(String modelo, String sistema, List<MensajeIA> mensajes, int maxTokens, bool json, Map<String, Object>? pensar) =>
      _http.post(
        Uri.parse('$_base/models/$modelo:generateContent'),
        headers: _cabeceras,
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': sistema},
            ],
          },
          'contents': [
            for (final m in mensajes)
              {
                'role': m.delUsuario ? 'user' : 'model',
                'parts': [
                  {'text': m.texto},
                ],
              },
          ],
          'generationConfig': {
            'maxOutputTokens': maxTokens,
            if (json) 'responseMimeType': 'application/json',
            'thinkingConfig': ?pensar,
          },
        }),
      );

  static String _textoDe(Map<String, dynamic> datos) {
    final partes = ((datos['candidates'] as List?)?.firstOrNull as Map?)?['content']?['parts'] as List?;
    return [
      for (final p in partes ?? const [])
        if ((p as Map)['thought'] != true) p['text'] ?? '',
    ].join().trim();
  }

  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) async {
    final elegido = _modelo;
    final llave = '$clave|$elegido';
    if (_respaldo[llave] case (final otro, final desde) when DateTime.now().difference(desde) < _vigenciaRespaldo) {
      try {
        return await _responderCon(otro, sistema, mensajes, maxTokens, json);
      } on ErrorIA catch (e) {
        if (!e.saturado) rethrow;
        _respaldo.remove(llave);
      }
    }
    ErrorIA ultimo;
    try {
      return await _responderCon(elegido, sistema, mensajes, maxTokens, json);
    } on ErrorIA catch (e) {
      if (!e.saturado) rethrow;
      ultimo = e;
    }
    // Saturado: una vez más tras una pausa y, si no, con otro modelo.
    await Future<void>.delayed(espera);
    try {
      return await _responderCon(elegido, sistema, mensajes, maxTokens, json);
    } on ErrorIA catch (e) {
      if (!e.saturado) rethrow;
      ultimo = e;
    }
    final List<String> respaldos;
    try {
      respaldos = modelosDeRespaldo(ProveedorIA.gemini, await listarModelos(), elegido);
    } on ErrorIA {
      throw ultimo;
    }
    for (final otro in respaldos) {
      try {
        final texto = await _responderCon(otro, sistema, mensajes, maxTokens, json);
        _respaldo[llave] = (otro, DateTime.now());
        return texto;
      } on ErrorIA catch (e) {
        if (!e.saturado) rethrow;
        ultimo = e;
      }
    }
    throw ultimo;
  }

  Future<String> _responderCon(String modelo, String sistema, List<MensajeIA> mensajes, int maxTokens, bool json) async {
    final pensar = configuracionDePensar(modelo);
    // Con espacio de sobra por si el modelo piensa de todos modos.
    const holgura = 4096;
    Map<String, dynamic> datos;
    try {
      datos = await _enviar(ProveedorIA.gemini, () => _generar(modelo, sistema, mensajes, maxTokens, json, pensar));
    } on ErrorIA catch (e) {
      // Un modelo que no acepta esa forma de apagar el pensar contesta 400:
      // se reintenta sin ella.
      if (pensar == null || e.codigo != 400 || e.mensaje.contains('clave')) rethrow;
      datos = await _enviar(ProveedorIA.gemini, () => _generar(modelo, sistema, mensajes, maxTokens + holgura, json, null));
    }
    var texto = _textoDe(datos);
    if (texto.isEmpty) {
      // Se le fue el espacio en pensar: una vez más, con holgura.
      datos = await _enviar(ProveedorIA.gemini, () => _generar(modelo, sistema, mensajes, maxTokens + holgura, json, null));
      texto = _textoDe(datos);
    }
    if (texto.isEmpty) throw const ErrorIA('Tu IA no dio respuesta. Prueba a preguntarlo de otra forma.');
    return texto;
  }
}

/// El cliente de API de [p] con su clave.
ClienteApi clienteDeApi(ProveedorIA p, String clave, {String? modelo, http.Client? cliente}) => switch (p) {
      ProveedorIA.gemini => ClienteGemini(clave, modelo: modelo, cliente: cliente),
      ProveedorIA.apple => throw ArgumentError('Apple no usa clave'),
    };
