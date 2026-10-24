import AppIntents

/// "Registrar un gasto": abre App Finanzas con el dictado ya escuchando
/// (spec-app-finanzas-v2.md §5.6). Lo usan el atajo de Siri
/// (`Runner/AtajosSiri.swift`) y el control del Centro de Control
/// (`WidgetsFinanzas/WidgetsFinanzas.swift`).
///
/// Vive en los dos targets porque así lo exige iOS para los controles, pero
/// por `openAppWhenRun` siempre se ejecuta dentro de la app: la copia de la
/// extensión nunca corre `perform()` y por eso ahí no hace nada.
@available(iOS 17.0, *)
struct DictarGastoIntent: AppIntent {
  static let title: LocalizedStringResource = "Registrar un gasto"
  static let description = IntentDescription(
    "Abre App Finanzas escuchando para que dictes el gasto."
  )
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    #if !EXTENSION_WIDGETS
      AccesosRapidos.recibir("dictar")
    #endif
    return .result()
  }
}
