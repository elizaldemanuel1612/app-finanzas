import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/seguridad/politica_bloqueo.dart';
import '../almacenamiento/archivo_texto.dart';

/// Lo que la pantalla de desbloqueo necesita saber.
final class EstadoCandado {
  final bool tienePin;
  final bool tieneContrasena;
  final MetodoDesbloqueo metodo;

  /// Pasó una semana (o nunca se usó): hay que pedir el PIN aunque el método
  /// sea otro.
  final bool tocaPin;
  final int fallidos;

  /// Hasta cuándo no se puede volver a intentar; `null` si ya se puede.
  final DateTime? esperarHasta;

  /// Demasiados intentos: solo se entra confirmando la cuenta de Google.
  final bool requiereRecuperar;

  const EstadoCandado({
    required this.tienePin,
    required this.tieneContrasena,
    required this.metodo,
    required this.tocaPin,
    required this.fallidos,
    required this.esperarHasta,
    required this.requiereRecuperar,
  });
}

/// PIN, contraseña y método de desbloqueo de la app (spec-app-finanzas-v2.md
/// §7.3), guardados en el dispositivo dentro de la carpeta de la cuenta:
/// nunca se suben a ningún lado. Nunca se guarda el PIN ni la contraseña:
/// solo su huella PBKDF2-SHA256 con sal aleatoria.
final class Candado {
  final ArchivoTexto archivo;
  final DateTime Function() reloj;

  /// Vueltas de PBKDF2. Suficientes para que adivinar sea lento sin trabar
  /// la app en la web.
  final int iteraciones;

  Candado(this.archivo, {DateTime Function()? reloj, this.iteraciones = 20000})
      : reloj = reloj ?? DateTime.now;

  Future<Map<String, dynamic>> _leer() async {
    final texto = await archivo.leer();
    if (texto == null || texto.trim().isEmpty) return {};
    try {
      return jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _guardar(Map<String, dynamic> datos) => archivo.escribir(jsonEncode(datos));

  Future<EstadoCandado> estado() async {
    final d = await _leer();
    final ahora = reloj();
    final fallidos = d['fallidos'] as int? ?? 0;
    final espera = DateTime.tryParse(d['esperarHasta'] as String? ?? '');
    final ultimoPin = DateTime.tryParse(d['ultimoPin'] as String? ?? '');
    return EstadoCandado(
      tienePin: d['pin'] != null,
      tieneContrasena: d['contrasena'] != null,
      metodo: MetodoDesbloqueo.values.firstWhere(
        (m) => m.name == d['metodo'],
        orElse: () => MetodoDesbloqueo.pin,
      ),
      tocaPin: tocaPedirPin(ultimoPin: ultimoPin, ahora: ahora),
      fallidos: fallidos,
      esperarHasta: espera != null && espera.isAfter(ahora) ? espera : null,
      requiereRecuperar: esperaTrasFallidos(fallidos) == null,
    );
  }

  /// Crea o cambia el PIN (ya validado con `validarPinNuevo`). Cuenta como
  /// haberlo usado y limpia los intentos fallidos.
  Future<void> definirPin(String pin) async {
    final d = await _leer();
    d['pin'] = _huellaNueva(pin);
    d['ultimoPin'] = reloj().toIso8601String();
    d.remove('fallidos');
    d.remove('esperarHasta');
    await _guardar(d);
  }

  /// Crea o cambia la contraseña (ya validada con `validarContrasenaNueva`).
  Future<void> definirContrasena(String contrasena) async {
    final d = await _leer();
    d['contrasena'] = _huellaNueva(contrasena);
    await _guardar(d);
  }

  Future<void> elegirMetodo(MetodoDesbloqueo metodo) async {
    final d = await _leer();
    d['metodo'] = metodo.name;
    await _guardar(d);
  }

  /// `true` si es el PIN. Con [esperarHasta] vigente o tras demasiados
  /// intentos ni siquiera compara.
  Future<bool> probarPin(String pin) => _probar('pin', pin, esPin: true);

  Future<bool> probarContrasena(String contrasena) => _probar('contrasena', contrasena, esPin: false);

  Future<bool> _probar(String clave, String intento, {required bool esPin}) async {
    final d = await _leer();
    final ahora = reloj();
    final fallidos = d['fallidos'] as int? ?? 0;
    final espera = DateTime.tryParse(d['esperarHasta'] as String? ?? '');
    if (esperaTrasFallidos(fallidos) == null || (espera != null && espera.isAfter(ahora))) return false;
    final guardada = d[clave] as Map<String, dynamic>?;
    if (guardada != null && _coincide(intento, guardada)) {
      d.remove('fallidos');
      d.remove('esperarHasta');
      if (esPin) d['ultimoPin'] = ahora.toIso8601String();
      await _guardar(d);
      return true;
    }
    final nuevos = fallidos + 1;
    d['fallidos'] = nuevos;
    final siguiente = esperaTrasFallidos(nuevos);
    if (siguiente != null && siguiente > Duration.zero) {
      d['esperarHasta'] = ahora.add(siguiente).toIso8601String();
    }
    await _guardar(d);
    return false;
  }

  /// Entró con Face ID o huella: cuenta como acierto.
  Future<void> registrarBiometria() async {
    final d = await _leer();
    d.remove('fallidos');
    d.remove('esperarHasta');
    await _guardar(d);
  }

  /// Último toque con la app desbloqueada. Sobrevive a que el sistema
  /// cierre o recargue la app (la web en el iPhone lo hace al quedarse sin
  /// memoria), para que un arranque dentro del margen no vuelva a pedir el
  /// desbloqueo (spec §7.3).
  Future<void> anotarActividad(DateTime cuando) async {
    final d = await _leer();
    d['ultimaActividad'] = cuando.toIso8601String();
    await _guardar(d);
  }

  Future<DateTime?> ultimaActividad() async => DateTime.tryParse((await _leer())['ultimaActividad'] as String? ?? '');

  /// Tras confirmar la cuenta de Google: se olvida PIN, contraseña e
  /// intentos, y el usuario crea un PIN nuevo.
  Future<void> reiniciar() => archivo.borrar();

  Map<String, String> _huellaNueva(String secreto) {
    final generador = Random.secure();
    final sal = Uint8List.fromList(List.generate(16, (_) => generador.nextInt(256)));
    return {'sal': base64Encode(sal), 'huella': base64Encode(_pbkdf2(secreto, sal))};
  }

  bool _coincide(String intento, Map<String, dynamic> guardada) {
    final sal = base64Decode(guardada['sal'] as String);
    final esperada = base64Decode(guardada['huella'] as String);
    final obtenida = _pbkdf2(intento, sal);
    // Comparación en tiempo constante.
    var diferencia = esperada.length ^ obtenida.length;
    for (var i = 0; i < esperada.length && i < obtenida.length; i++) {
      diferencia |= esperada[i] ^ obtenida[i];
    }
    return diferencia == 0;
  }

  List<int> _pbkdf2(String secreto, List<int> sal) => pbkdf2Sha256(secreto, sal, iteraciones);
}

/// PBKDF2-HMAC-SHA256, un bloque de 32 bytes (RFC 8018). Pública para
/// probarla contra el vector conocido.
List<int> pbkdf2Sha256(String secreto, List<int> sal, int iteraciones) {
  final hmac = Hmac(sha256, utf8.encode(secreto));
  var u = hmac.convert([...sal, 0, 0, 0, 1]).bytes;
  final resultado = List<int>.of(u);
  for (var i = 1; i < iteraciones; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < resultado.length; j++) {
      resultado[j] ^= u[j];
    }
  }
  return resultado;
}
