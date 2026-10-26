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
      // Sin App Group (firma con Apple ID gratuito) esto escribe en las
      // preferencias propias de la app y el widget simplemente no lo ve:
      // muestra solo los botones. Nada falla.
      if let datos = call.arguments as? [String: Any],
        let compartidas = UserDefaults(suiteName: Self.appGroup)
      {
        compartidas.set(datos["quedaHoyTexto"] as? String, forKey: "quedaHoyTexto")
        compartidas.set(datos["fecha"] as? String, forKey: "fecha")
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    case "limpiarWidget":
      if let compartidas = UserDefaults(suiteName: Self.appGroup) {
        compartidas.removeObject(forKey: "quedaHoyTexto")
        compartidas.removeObject(forKey: "fecha")
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
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
