import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'data/repositorios/local/almacen_local.dart';
import 'data/voz/registro_por_voz.dart';
import 'plataforma/accesos_rapidos.dart';
import 'plataforma/ia_dictado.dart';
import 'plataforma/sesion_siri.dart';
import 'ui/ia/servicio_ia_app.dart';

/// El canal con `ios/Runner/AtajosSiri.swift` (`MotorSiri`).
const canalSiri = MethodChannel('app_finanzas/siri');

/// Siri sin abrir la app (spec-app-finanzas-v2.md §5.6.3): el lado nativo
/// arranca este Dart sin pantalla (`siriMain` en `main.dart`) y le pide
/// entender, registrar o resumir. Aquí no hay lógica propia: todo es
/// `RegistroPorVoz`, lo mismo que usa la captura.
Future<void> iniciarSiri() async {
  WidgetsFlutterBinding.ensureInitialized();
  canalSiri.setMethodCallHandler(atenderSiri);
  await canalSiri.invokeMethod<void>('listo');
}

/// Una petición de Siri. [registro] se inyecta en las pruebas.
Future<Map<String, Object?>> atenderSiri(MethodCall llamada, {RegistroPorVoz? registro}) async {
  final voz = registro ?? await _registroDeLaSesion();
  if (voz == null) return RegistroPorVoz.sinSesion.toMap();
  final args = (llamada.arguments as Map?)?.cast<String, Object?>() ?? const {};
  final respuesta = switch (llamada.method) {
    'interpretar' => await voz.interpretar(args['frase'] as String? ?? ''),
    'conCategoria' => await voz.conCategoria(args['propuesta'] as String, args['categoria'] as String? ?? ''),
    'registrar' => await voz.registrar(args['propuesta'] as String),
    'resumen' => await voz.resumen(),
    _ => throw MissingPluginException('Siri no sabe "${llamada.method}"'),
  };
  final resumen = respuesta.resumen;
  return {
    ...respuesta.toMap(),
    // Lo que muestra el widget, ya con el gasto nuevo (§5.6).
    if (resumen != null)
      'widget': AccesosRapidos.datosDelWidget(
        resumen.soloRegistro ? resumen.gastadoSinPresupuesto : resumen.gastadoConPresupuesto,
        resumen.presupuesto,
        voz.reloj(),
      ),
  };
}

Future<RegistroPorVoz?> _registroDeLaSesion() async {
  final uid = await SesionSiri.cuenta();
  if (uid == null || uid.isEmpty) return null;
  final base = await getApplicationDocumentsDirectory();
  final directorio = Directory('${base.path}/usuarios/$uid');
  if (!directorio.existsSync()) return null;
  final almacen = AlmacenLocal(directorio);
  return RegistroPorVoz(
    almacen: almacen,
    nuevoClientId: const Uuid().v4,
    ia: await iaParaDictado(servicioIADe(almacen)),
  );
}
