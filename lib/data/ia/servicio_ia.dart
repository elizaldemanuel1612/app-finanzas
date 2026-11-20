import 'package:http/http.dart' as http;

import '../../domain/clasificacion/cascada_clasificacion.dart';
import '../../domain/ia/clasificacion_ia.dart';
import '../../domain/ia/proveedor_ia.dart';
import '../../domain/modelos/categoria.dart';
import 'clientes_ia.dart';
import 'configuracion_ia.dart';

/// Complementos de IA (spec §6.5): conectar la IA del usuario, elegir la
/// activa y usarla. La de Apple llega inyectada (canal nativo, solo
/// iPhone); las de API se arman con la clave guardada en el dispositivo.
final class ServicioIA {
  final AlmacenConfiguracionIA almacen;

  /// El modelo de Apple Intelligence; `null` fuera del iPhone.
  final ClienteIA? apple;
  final http.Client? _http;

  /// El resumen de los números del usuario (`textoParaIA`) para el
  /// asistente (spec §6.5, uso 4); `null` donde no hay datos (pruebas).
  final Future<String?> Function()? datosDelUsuario;

  ServicioIA(this.almacen, {this.apple, this.datosDelUsuario, http.Client? cliente}) : _http = cliente;

  Future<ConfiguracionIA> configuracion() => almacen.leer();

  /// Prueba [clave] pidiendo los modelos del proveedor, elige uno y la
  /// guarda como la activa. Regresa el modelo; si la clave no sirve, lanza
  /// [ErrorIA] y no guarda nada.
  Future<String> conectarConClave(ProveedorIA proveedor, String clave) async {
    final limpia = clave.trim();
    if (limpia.isEmpty) throw const ErrorIA('Pega tu clave para conectar.');
    final ids = await clienteDeApi(proveedor, limpia, cliente: _http).listarModelos();
    final modelo = elegirModelo(proveedor, ids);
    if (modelo == null) throw const ErrorIA('Tu clave funciona, pero no encontré un modelo de texto para usar.');
    await almacen.guardar((await almacen.leer()).conectar(proveedor, clave: limpia, modelo: modelo));
    return modelo;
  }

  Future<void> conectarApple() async => almacen.guardar((await almacen.leer()).conectar(ProveedorIA.apple));

  Future<void> desconectar(ProveedorIA proveedor) async => almacen.guardar((await almacen.leer()).desconectar(proveedor));

  Future<void> usar(ProveedorIA proveedor) async => almacen.guardar((await almacen.leer()).conActivo(proveedor));

  Future<void> sugerirCategorias(bool activo) async =>
      almacen.guardar((await almacen.leer()).conSugerirCategorias(activo));

  Future<void> verMisNumeros(bool activo) async => almacen.guardar((await almacen.leer()).conVerMisNumeros(activo));

  /// Los números del usuario para el asistente, solo si lo permitió.
  Future<String?> datosParaAsistente() async {
    if (datosDelUsuario == null || !(await almacen.leer()).verMisNumeros) return null;
    try {
      return await datosDelUsuario!();
    } catch (_) {
      return null;
    }
  }

  /// La IA activa, lista para preguntarle; `null` si no hay ninguna.
  Future<ClienteIA?> clienteActivo() async {
    final config = await almacen.leer();
    final activo = config.activo;
    if (activo == null || !config.conectado(activo)) return null;
    if (activo == ProveedorIA.apple) return apple;
    return clienteDeApi(activo, config.claves[activo]!, modelo: config.modelos[activo], cliente: _http);
  }

  /// Nivel 3 de la cascada (§6.1): la categoría que sugiere la IA para
  /// [nota]. `null` si está apagado, no hay IA o algo falla: nunca estorba
  /// a la captura.
  Future<ResultadoIA?> clasificar(String nota, List<Categoria> categorias) async {
    if (nota.trim().isEmpty || categorias.isEmpty) return null;
    final config = await almacen.leer();
    if (!config.sugerirCategorias) return null;
    final cliente = await clienteActivo();
    if (cliente == null) return null;
    try {
      final respuesta = await cliente.responder(
        sistema: instruccionesClasificacion,
        mensajes: [MensajeIA.usuario(mensajeClasificacion(nota, categorias))],
        maxTokens: 100,
        json: true,
      );
      return interpretarClasificacion(respuesta, categorias);
    } catch (_) {
      return null;
    }
  }
}
