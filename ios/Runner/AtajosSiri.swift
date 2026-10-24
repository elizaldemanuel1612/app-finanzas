import AppIntents

/// Atajo de voz (spec-app-finanzas-v2.md §5.6): "Oye Siri, registra un
/// gasto en App Finanzas" abre la captura con el dictado ya escuchando
/// (`Compartido/DictarGastoIntent.swift`). Siri no deja meter el monto en
/// la frase que activa el atajo, así que el gasto se dicta en un segundo
/// paso con el mismo `parsearDictado` de la app.
@available(iOS 17.0, *)
struct AtajosFinanzas: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: DictarGastoIntent(),
      phrases: [
        "Registra un gasto en \(.applicationName)",
        "Registrar un gasto en \(.applicationName)",
        "Registrar gasto en \(.applicationName)",
        "Anota un gasto en \(.applicationName)",
        "Nuevo gasto en \(.applicationName)",
        "Dicta un gasto en \(.applicationName)",
      ],
      shortTitle: "Registrar gasto",
      systemImageName: "mic.fill"
    )
  }
}
