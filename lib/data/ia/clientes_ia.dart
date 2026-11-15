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
  const ErrorIA(this.mensaje);
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

/// Las de API: Gemini, ChatGPT y Claude, con la clave del usuario. La app
/// les habla directo; nada pasa por servidores propios.
abstract base class ClienteApi implements ClienteIA {
  final String clave;
  final String? modelo;
  final http.Client _http;
  ClienteApi(this.clave, {this.modelo, http.Client? cliente}) : _http = cliente ?? http.Client();

  /// Los ids de modelos que la clave puede usar; también sirve para probar
  /// que la clave funciona.
  Future<List<String>> listarModelos();

  ErrorIA _errorDe(http.Response r, ProveedorIA p) => switch (r.statusCode) {
        400 when r.body.contains('API_KEY') || r.body.contains('API key') => ErrorIA('La clave no es válida. Revísala en ${p.sitioClave}.'),
        401 || 403 => ErrorIA('La clave no es válida o no tiene permiso. Revísala en ${p.sitioClave}.'),
        402 => const ErrorIA('Tu cuenta de la IA no tiene saldo para usarla.'),
        429 => const ErrorIA('Tu IA dice que llegaste a tu límite de uso por ahora. Intenta más tarde.'),
        >= 500 => const ErrorIA('Tu IA no está respondiendo ahorita. Intenta en un momento.'),
        _ => ErrorIA('Tu IA no pudo responder (código ${r.statusCode}).'),
      };

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
  ClienteGemini(super.clave, {super.modelo, super.cliente});
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

  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) async {
    final datos = await _enviar(
      ProveedorIA.gemini,
      () => _http.post(
        Uri.parse('$_base/models/$_modelo:generateContent'),
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
          },
        }),
      ),
    );
    final partes = ((datos['candidates'] as List?)?.firstOrNull as Map?)?['content']?['parts'] as List?;
    final texto = [for (final p in partes ?? const []) (p as Map)['text'] ?? ''].join().trim();
    if (texto.isEmpty) throw const ErrorIA('Tu IA no dio respuesta. Prueba a preguntarlo de otra forma.');
    return texto;
  }
}

final class ClienteOpenAI extends ClienteApi {
  ClienteOpenAI(super.clave, {super.modelo, super.cliente});
  static const _base = 'https://api.openai.com/v1';
  Map<String, String> get _cabeceras => {'authorization': 'Bearer $clave', 'content-type': 'application/json'};

  @override
  Future<List<String>> listarModelos() async {
    final datos = await _enviar(ProveedorIA.chatgpt, () => _http.get(Uri.parse('$_base/models'), headers: _cabeceras));
    return [for (final m in (datos['data'] as List? ?? const [])) (m as Map)['id'] as String];
  }

  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) async {
    final datos = await _enviar(
      ProveedorIA.chatgpt,
      () => _http.post(
        Uri.parse('$_base/chat/completions'),
        headers: _cabeceras,
        body: jsonEncode({
          'model': _modelo,
          'messages': [
            {'role': 'system', 'content': sistema},
            for (final m in mensajes) {'role': m.delUsuario ? 'user' : 'assistant', 'content': m.texto},
          ],
          // Los modelos que razonan gastan parte en pensar: holgura extra.
          'max_completion_tokens': maxTokens * 4,
          if (json) 'response_format': {'type': 'json_object'},
        }),
      ),
    );
    final texto = ((((datos['choices'] as List?)?.firstOrNull as Map?)?['message'] as Map?)?['content'] as String? ?? '').trim();
    if (texto.isEmpty) throw const ErrorIA('Tu IA no dio respuesta. Prueba a preguntarlo de otra forma.');
    return texto;
  }
}

final class ClienteClaude extends ClienteApi {
  ClienteClaude(super.clave, {super.modelo, super.cliente});
  static const _base = 'https://api.anthropic.com/v1';
  Map<String, String> get _cabeceras => {
        'x-api-key': clave,
        'anthropic-version': '2023-06-01',
        // La app (también la web) habla directo con la clave del propio usuario.
        'anthropic-dangerous-direct-browser-access': 'true',
        'content-type': 'application/json',
      };

  @override
  Future<List<String>> listarModelos() async {
    final datos = await _enviar(ProveedorIA.claude, () => _http.get(Uri.parse('$_base/models?limit=100'), headers: _cabeceras));
    return [for (final m in (datos['data'] as List? ?? const [])) (m as Map)['id'] as String];
  }

  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) async {
    final datos = await _enviar(
      ProveedorIA.claude,
      () => _http.post(
        Uri.parse('$_base/messages'),
        headers: _cabeceras,
        body: jsonEncode({
          'model': _modelo,
          'max_tokens': maxTokens,
          'system': sistema,
          'messages': [
            for (final m in mensajes) {'role': m.delUsuario ? 'user' : 'assistant', 'content': m.texto},
          ],
        }),
      ),
    );
    final texto = [
      for (final b in (datos['content'] as List? ?? const []))
        if ((b as Map)['type'] == 'text') b['text'] as String,
    ].join().trim();
    if (texto.isEmpty) throw const ErrorIA('Tu IA no dio respuesta. Prueba a preguntarlo de otra forma.');
    return texto;
  }
}

/// El cliente de API de [p] con su clave.
ClienteApi clienteDeApi(ProveedorIA p, String clave, {String? modelo, http.Client? cliente}) => switch (p) {
      ProveedorIA.gemini => ClienteGemini(clave, modelo: modelo, cliente: cliente),
      ProveedorIA.chatgpt => ClienteOpenAI(clave, modelo: modelo, cliente: cliente),
      ProveedorIA.claude => ClienteClaude(clave, modelo: modelo, cliente: cliente),
      ProveedorIA.apple => throw ArgumentError('Apple no usa clave'),
    };
