import Flutter
import UIKit
import WidgetKit

/// Accesos rápidos de iOS (spec-app-finanzas-v2.md §5.6): recibe lo que
/// piden el widget de inicio (por URL `appfinanzas://gasto` o
/// `appfinanzas://dictar`) y el atajo de Siri, y se lo pasa a Flutter.
/// También guarda en el App Group el dato que muestra el widget.
///
/// Contraparte de `lib/plataforma/accesos_rapidos.dart`.
final class AccesosRapidos: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static let esquema = "appfinanzas"
  static let appGroup = "group.com.manuelelizalde.appfinanzas"

  private static var instancia: AccesosRapidos?

  /// Acción que llegó cuando Flutter todavía no escuchaba (la app se abrió
  /// en frío desde el widget o desde Siri). Flutter la pide al arrancar.
  private static var pendiente: String?

  private let canal: FlutterMethodChannel
  private var flutterEscuchando = false

  private init(canal: FlutterMethodChannel) {
    self.canal = canal
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "app_finanzas/accesos_rapidos",
      binaryMessenger: registrar.messenger()
    )
    let instancia = AccesosRapidos(canal: canal)
    registrar.addMethodCallDelegate(instancia, channel: canal)
    registrar.addSceneDelegate(instancia)
    Self.instancia = instancia
  }

  /// Entrada única para el widget y para Siri.
  static func recibir(_ accion: String) {
    guard accion == "gasto" || accion == "dictar" else { return }
    if let instancia, instancia.flutterEscuchando {
      instancia.canal.invokeMethod("abrir", arguments: accion)
    } else {
      pendiente = accion
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "accionPendiente":
      flutterEscuchando = true
      result(Self.pendiente)
      Self.pendiente = nil
    case "dejarDeEscuchar":
      flutterEscuchando = false
      result(nil)
    case "actualizarWidget":
      if let datos = call.arguments as? [String: Any] { Self.guardarWidget(datos) }
      result(nil)
    case "limpiarWidget":
      if let compartidas = UserDefaults(suiteName: Self.appGroup) {
        compartidas.removeObject(forKey: "quedaHoyTexto")
        compartidas.removeObject(forKey: "deTexto")
        compartidas.removeObject(forKey: "fecha")
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Guarda lo que muestra el widget. Sin App Group (firma con Apple ID
  /// gratuito) no hay dónde y el widget muestra solo los botones: nada falla.
  /// También lo usa Siri al registrar sin abrir la app (§5.6.3).
  static func guardarWidget(_ datos: [String: Any]) {
    guard let compartidas = UserDefaults(suiteName: appGroup) else { return }
    compartidas.set(datos["quedaHoyTexto"] as? String, forKey: "quedaHoyTexto")
    compartidas.set(datos["deTexto"] as? String, forKey: "deTexto")
    compartidas.set(datos["fecha"] as? String, forKey: "fecha")
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Siri registró un gasto (§5.6.3): si la app está abierta, que recargue.
  static func avisarDatosCambiaron() {
    guard let instancia, instancia.flutterEscuchando else { return }
    instancia.canal.invokeMethod("datosCambiaron", arguments: nil)
  }

  // MARK: - URLs del widget

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let url = connectionOptions?.urlContexts.first(where: { Self.esNuestra($0.url) })?.url
    else { return false }
    Self.recibir(url.host ?? "")
    return true
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.first(where: { Self.esNuestra($0.url) })?.url else { return false }
    Self.recibir(url.host ?? "")
    return true
  }

  private static func esNuestra(_ url: URL) -> Bool {
    url.scheme == esquema
  }
}

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence como complemento de IA (spec §6.5): el modelo de
/// Apple corre dentro del iPhone (Foundation Models, iOS 26+). Va en este
/// archivo para no tocar el proyecto de Xcode con uno nuevo.
///
/// Contraparte de `lib/plataforma/ia_apple.dart`.
final class IAApple: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(name: "app_finanzas/ia_apple", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(IAApple(), channel: canal)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "estado":
      result(Self.estado())
    case "responder":
      guard let args = call.arguments as? [String: Any],
            let sistema = args["sistema"] as? String,
            let mensajes = args["mensajes"] as? [[String: Any]]
      else {
        result(FlutterError(code: "argumentos", message: "Faltan datos", details: nil))
        return
      }
      Self.responder(sistema: sistema, mensajes: mensajes, result: result)
    case "categoriaDeGasto":
      guard let args = call.arguments as? [String: Any],
            let instrucciones = args["instrucciones"] as? String,
            let mensaje = args["mensaje"] as? String,
            let opciones = args["opciones"] as? [String], !opciones.isEmpty
      else {
        result(FlutterError(code: "argumentos", message: "Faltan datos", details: nil))
        return
      }
      Task {
        do {
          let categoria = try await Self.categoriaDeGasto(
            instrucciones: instrucciones, mensaje: mensaje, opciones: opciones)
          await MainActor.run { result(categoria) }
        } catch {
          await MainActor.run {
            result(FlutterError(code: "ia", message: error.localizedDescription, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func estado() -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return "disponible"
      case .unavailable(.deviceNotEligible):
        return "noCompatible"
      case .unavailable(.appleIntelligenceNotEnabled):
        return "apagado"
      case .unavailable(.modelNotReady):
        return "descargando"
      case .unavailable:
        return "noCompatible"
      }
    }
    #endif
    return "noSoportado"
  }

  /// La categoría de un gasto dicho (spec §5.6.3), elegida por el modelo
  /// solo entre [opciones] (generación guiada: no puede responder un nombre
  /// que no esté). Las instrucciones y el mensaje los arma Dart
  /// (`domain/voz/interpretar_gasto.dart`) y Dart valida la respuesta. Lo
  /// mismo mide `tool/ia_gasto/probar_apple.swift` en la Mac.
  static func categoriaDeGasto(instrucciones: String, mensaje: String, opciones: [String]) async throws -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      let esquema = try GenerationSchema(
        root: DynamicGenerationSchema(
          name: "Gasto",
          properties: [
            .init(name: "categoria", schema: DynamicGenerationSchema(name: "Categoria", anyOf: opciones))
          ]),
        dependencies: [])
      let sesion = LanguageModelSession(instructions: instrucciones)
      let respuesta = try await sesion.respond(
        to: mensaje, schema: esquema, options: GenerationOptions(sampling: .greedy))
      return try respuesta.content.value(String.self, forProperty: "categoria")
    }
    #endif
    throw NSError(domain: "IAApple", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence no está disponible"])
  }

  private static func responder(sistema: String, mensajes: [[String: Any]], result: @escaping FlutterResult) {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      // Cada pregunta abre su sesión con la conversación hasta aquí: así no
      // hay estado guardado del lado nativo.
      let historia = mensajes.dropLast().map { m -> String in
        let quien = (m["usuario"] as? Bool ?? true) ? "Usuario" : "Asistente"
        return "\(quien): \(m["texto"] as? String ?? "")"
      }.joined(separator: "\n")
      let ultima = mensajes.last?["texto"] as? String ?? ""
      let prompt = historia.isEmpty ? ultima : "Conversación hasta ahora:\n\(historia)\n\nUsuario: \(ultima)"
      Task {
        do {
          let sesion = LanguageModelSession(instructions: sistema)
          let respuesta = try await sesion.respond(to: prompt)
          await MainActor.run { result(respuesta.content) }
        } catch {
          await MainActor.run {
            result(FlutterError(code: "ia", message: error.localizedDescription, details: nil))
          }
        }
      }
      return
    }
    #endif
    result(FlutterError(code: "noSoportado", message: "Apple Intelligence no está disponible", details: nil))
  }
}
