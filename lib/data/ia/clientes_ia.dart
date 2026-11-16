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

  Future<http.Response> _generar(String sistema, List<MensajeIA> mensajes, int maxTokens, bool json, Map<String, Object>? pensar) =>
      _http.post(
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
    final pensar = configuracionDePensar(_modelo);
    // Con espacio de sobra por si el modelo piensa de todos modos.
    const holgura = 4096;
    Map<String, dynamic> datos;
    try {
      datos = await _enviar(ProveedorIA.gemini, () => _generar(sistema, mensajes, maxTokens, json, pensar));
    } on ErrorIA catch (e) {
      // Un modelo que no acepta esa forma de apagar el pensar contesta 400:
      // se reintenta sin ella.
      if (pensar == null || !e.mensaje.contains('código 400')) rethrow;
      datos = await _enviar(ProveedorIA.gemini, () => _generar(sistema, mensajes, maxTokens + holgura, json, null));
    }
    var texto = _textoDe(datos);
    if (texto.isEmpty) {
      // Se le fue el espacio en pensar: una vez más, con holgura.
      datos = await _enviar(ProveedorIA.gemini, () => _generar(sistema, mensajes, maxTokens + holgura, json, null));
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
