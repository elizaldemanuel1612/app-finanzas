import 'dart:convert';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/ia/clientes_ia.dart';
import 'package:app_finanzas/data/ia/configuracion_ia.dart';
import 'package:app_finanzas/data/ia/servicio_ia.dart';
import 'package:app_finanzas/domain/ia/proveedor_ia.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// spec §6.5: conectar = probar la clave; la clave solo vive en ia.json; la
// IA nunca estorba a la captura.

const _super = CategoriaVariable(
  id: 'super',
  nombre: 'Súper',
  emoji: '🛒',
  activa: true,
  esNecesaria: false,
  presupuestoMensualCentavos: Dinero.pesos(1000),
);

http.Response _json(Object datos, [int codigo = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(datos)), codigo, headers: {'content-type': 'application/json'});

final class _ClienteFijo implements ClienteIA {
  final String respuesta;
  _ClienteFijo(this.respuesta);
  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) async =>
      respuesta;
}

void main() {
  group('clientes', () {
    test('Gemini: lista modelos de texto y responde con instrucciones e historial', () async {
      late Map<String, dynamic> enviado;
      final cliente = MockClient((r) async {
        expect(r.headers['x-goog-api-key'], 'k');
        if (r.method == 'GET') {
          return _json({
            'models': [
              {'name': 'models/gemini-2.5-flash', 'supportedGenerationMethods': ['generateContent']},
              {'name': 'models/embedding-001', 'supportedGenerationMethods': ['embedContent']},
            ],
          });
        }
        expect(r.url.path, endsWith('gemini-2.5-flash:generateContent'));
        enviado = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Hola '},
                  {'text': 'ñandú'},
                ],
              },
            },
          ],
        });
      });
      final g = ClienteGemini('k', modelo: 'gemini-2.5-flash', cliente: cliente);
      expect(await g.listarModelos(), ['models/gemini-2.5-flash']);
      final r = await g.responder(
        sistema: 'S',
        mensajes: const [MensajeIA.usuario('a'), MensajeIA.asistente('b'), MensajeIA.usuario('c')],
        json: true,
      );
      expect(r, 'Hola ñandú');
      expect(enviado['systemInstruction']['parts'][0]['text'], 'S');
      expect([for (final c in enviado['contents'] as List) c['role']], ['user', 'model', 'user']);
      expect(enviado['generationConfig']['responseMimeType'], 'application/json');
    });

    test('los errores se dicen en palabras', () async {
      Future<String> conCodigo(int codigo, {String cuerpo = '{}'}) async {
        final g = ClienteGemini('k', modelo: 'm', cliente: MockClient((_) async => http.Response(cuerpo, codigo)));
        try {
          await g.responder(sistema: 's', mensajes: const [MensajeIA.usuario('a')]);
          return 'sin error';
        } on ErrorIA catch (e) {
          return e.toString();
        }
      }

      expect(await conCodigo(401), contains('La clave no es válida'));
      expect(await conCodigo(400, cuerpo: 'API key not valid'), contains('La clave no es válida'));
      expect(await conCodigo(402), contains('saldo'));
      expect(await conCodigo(429), contains('límite'));
      expect(await conCodigo(503), contains('no está respondiendo'));
      expect(await conCodigo(418), contains('código 418'));
      expect(await conCodigo(200, cuerpo: 'no es json'), contains('No entendí'));
      expect(await conCodigo(200, cuerpo: '{"candidates": []}'), contains('no dio respuesta'));

      final sinRed = ClienteGemini('k', modelo: 'm', cliente: MockClient((_) async => throw Exception('x')));
      expect(() => sinRed.listarModelos(), throwsA(isA<ErrorIA>().having((e) => e.mensaje, 'mensaje', contains('conexión'))));
      expect(() => clienteDeApi(ProveedorIA.apple, 'k'), throwsArgumentError);
    });
  });

  test('un ia.json de antes con ChatGPT o Claude se lee sin ellos (2026-11-15)', () {
    final c = ConfiguracionIA.fromJson({
      'activo': 'claude',
      'claves': {'chatgpt': 'a', 'claude': 'b', 'gemini': 'g'},
      'modelos': {'claude': 'm', 'gemini': 'gemini-2.5-flash'},
    });
    expect(c.activo, isNull);
    expect(c.claves, {ProveedorIA.gemini: 'g'});
    expect(c.conectados, [ProveedorIA.gemini]);
  });

  group('servicio', () {
    late ArchivoTextoMemoria archivo;
    setUp(() => archivo = ArchivoTextoMemoria());

    ServicioIA servicio({required http.Client cliente, ClienteIA? apple}) =>
        ServicioIA(AlmacenConfiguracionIA(archivo), apple: apple, cliente: cliente);

    test('conectar prueba la clave, elige modelo y la deja activa; una clave mala no se guarda', () async {
      final cliente = MockClient((r) async {
        if (r.headers['x-goog-api-key'] == 'mala') return http.Response('{}', 403);
        return _json({
          'models': [
            {'name': 'models/gemini-2.5-flash', 'supportedGenerationMethods': ['generateContent']},
          ],
        });
      });
      final s = servicio(cliente: cliente);
      await expectLater(s.conectarConClave(ProveedorIA.gemini, '  '), throwsA(isA<ErrorIA>()));
      await expectLater(s.conectarConClave(ProveedorIA.gemini, 'mala'), throwsA(isA<ErrorIA>()));
      expect((await s.configuracion()).conectados, isEmpty);
      expect(await s.conectarConClave(ProveedorIA.gemini, ' buena '), 'gemini-2.5-flash');
      final config = await s.configuracion();
      expect(config.activo, ProveedorIA.gemini);
      expect(config.claves[ProveedorIA.gemini], 'buena');
      expect(await s.clienteActivo(), isA<ClienteGemini>());
    });

    test('sin modelos de texto no conecta', () async {
      final s = servicio(cliente: MockClient((_) async => _json({'data': []})));
      await expectLater(s.conectarConClave(ProveedorIA.gemini, 'k'), throwsA(isA<ErrorIA>()));
    });

    test('Apple, cambiar de activa y desconectar', () async {
      final apple = _ClienteFijo('{"categoria": "Súper", "confianza": 0.95}');
      final s = servicio(cliente: MockClient((_) async => _json({})), apple: apple);
      expect(await s.clienteActivo(), isNull);
      await s.conectarApple();
      expect(await s.clienteActivo(), same(apple));
      await archivo.escribir(jsonEncode((await s.configuracion()).conectar(ProveedorIA.gemini, clave: 'k', modelo: 'm').toJson()));
      await s.usar(ProveedorIA.apple);
      expect((await s.configuracion()).activo, ProveedorIA.apple);
      await s.desconectar(ProveedorIA.apple);
      expect((await s.configuracion()).activo, ProveedorIA.gemini);
      await s.desconectar(ProveedorIA.gemini);
      expect((await s.configuracion()).activo, isNull);
    });

    test('clasificar: solo si está encendido y nunca truena', () async {
      final s = servicio(cliente: MockClient((_) async => _json({})), apple: _ClienteFijo('{"categoria": "Súper", "confianza": 0.95}'));
      expect(await s.clasificar('costco', const [_super]), isNull); // sin IA
      await s.conectarApple();
      expect(await s.clasificar('costco', const [_super]), isNull); // apagado
      await s.sugerirCategorias(true);
      expect((await s.clasificar('costco', const [_super]))!.categoriaId, 'super');
      expect(await s.clasificar(' ', const [_super]), isNull);
      expect(await s.clasificar('costco', const []), isNull);

      final falla = ServicioIA(AlmacenConfiguracionIA(archivo), apple: _ClienteQueFalla());
      expect(await falla.clasificar('costco', const [_super]), isNull);
      // Sin apple inyectada (web) aunque esté activa: no hay cliente.
      expect(await ServicioIA(AlmacenConfiguracionIA(archivo)).clasificar('costco', const [_super]), isNull);
    });

    test('la configuración aguanta un archivo dañado y desconectar todo apaga sugerir', () async {
      await archivo.escribir('no es json');
      final s = servicio(cliente: MockClient((_) async => _json({})));
      expect((await s.configuracion()).conectados, isEmpty);
      final c = const ConfiguracionIA().conectar(ProveedorIA.apple).conSugerirCategorias(true).desconectar(ProveedorIA.apple);
      expect(c.sugerirCategorias, isFalse);
      final ida = ConfiguracionIA.fromJson({
        ...const ConfiguracionIA().conectar(ProveedorIA.gemini, clave: 'k', modelo: 'm').toJson(),
        'claves': {'gemini': 'k', 'otra': 'x'},
      });
      expect(ida.claves.keys, [ProveedorIA.gemini]);
      expect(ida.conActivo(null).activo, isNull);
    });
  });
}

final class _ClienteQueFalla implements ClienteIA {
  @override
  Future<String> responder({required String sistema, required List<MensajeIA> mensajes, int maxTokens = 800, bool json = false}) =>
      throw const ErrorIA('x');
}
