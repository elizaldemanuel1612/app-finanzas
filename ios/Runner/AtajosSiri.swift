import AppIntents
import Flutter

// Siri (spec-app-finanzas-v2.md §5.6 y §5.6.3).
//
// "Oye Siri, registra un gasto en MAVfin" → "¿Qué gastaste?" → "230 en el
// súper con la BBVA ayer" → "¿Registro $230 en Súper con BBVA, ayer?" →
// "Sí" → "Listo. Te quedan $1,170 en Súper." Todo sin abrir la app.
//
// Aquí solo va la conversación: entender, preguntar lo que falte, guardar
// y qué contestar lo decide Dart (`lib/data/voz/registro_por_voz.dart`, por
// `lib/siri.dart`), el mismo código que usa la captura. `MotorSiri` arranca
// ese Dart sin pantalla dentro del proceso de la app.

/// Un Flutter sin pantalla que corre `siriMain` (`lib/main.dart`). Se crea
/// la primera vez que Siri lo necesita y se queda mientras viva el proceso.
@MainActor
final class MotorSiri {
  static let compartido = MotorSiri()

  private var motor: FlutterEngine?
  private var canal: FlutterMethodChannel?
  private var listo = false
  private var arrancando = false
  private var esperando: [(Result<Void, Error>) -> Void] = []

  enum Falla: LocalizedError {
    case noArranco
    case sinRespuesta

    var errorDescription: String? {
      switch self {
      case .noArranco: return "MAVfin no pudo prepararse. Ábrela y vuelve a intentar."
      case .sinRespuesta: return "MAVfin no respondió. Ábrela y vuelve a intentar."
      }
    }
  }

  private func preparar() async throws {
    if listo { return }
    if motor == nil && !arrancando {
      arrancando = true
      // Fuera de la tarea de Siri: crear el motor de Flutter desde dentro de
      // una tarea `async` rompía el orden de memoria de Swift Concurrency
      // ("freed pointer was not the last allocation") y cerraba la app.
      DispatchQueue.main.async { self.arrancar() }
    }
    try await esperar(segundos: 10) { (terminar: @escaping (Result<Void, Error>) -> Void) in
      if self.listo { terminar(.success(())) } else { self.esperando.append(terminar) }
    }
  }

  private func arrancar() {
    let motor = FlutterEngine(name: "siri", project: nil, allowHeadlessExecution: true)
    // Primero se arranca y luego se escucha: Flutter no deja poner el
    // manejador antes. Dart avisa "listo" hasta que su código corre, que es
    // después de este mismo ciclo del hilo principal.
    guard motor.run(withEntrypoint: "siriMain") else {
      arrancando = false
      let todos = esperando
      esperando = []
      todos.forEach { $0(.failure(Falla.noArranco)) }
      return
    }
    let canal = FlutterMethodChannel(name: "app_finanzas/siri", binaryMessenger: motor.binaryMessenger)
    canal.setMethodCallHandler { [weak self] llamada, resultado in
      if llamada.method == "listo" {
        self?.marcarListo()
      }
      resultado(nil)
    }
    GeneratedPluginRegistrant.register(with: motor)
    if let registrar = motor.registrar(forPlugin: "IAApple") {
      IAApple.register(with: registrar)
    }
    self.motor = motor
    self.canal = canal
  }

  private func marcarListo() {
    listo = true
    let todos = esperando
    esperando = []
    todos.forEach { $0(.success(())) }
  }

  /// Llama a Dart y devuelve su respuesta (`RespuestaVoz.toMap`).
  func llamar(_ metodo: String, _ argumentos: [String: Any] = [:]) async throws -> [String: Any] {
    try await preparar()
    guard let canal else { throw Falla.noArranco }
    return try await esperar(segundos: 15) { (terminar: @escaping (Result<[String: Any], Error>) -> Void) in
      DispatchQueue.main.async {
        canal.invokeMethod(metodo, arguments: argumentos) { respuesta in
          if let mapa = respuesta as? [String: Any] {
            terminar(.success(mapa))
          } else if let error = respuesta as? FlutterError {
            terminar(.failure(NSError(
              domain: "MotorSiri", code: 1,
              userInfo: [NSLocalizedDescriptionKey: error.message ?? error.code])))
          } else {
            terminar(.failure(Falla.sinRespuesta))
          }
        }
      }
    }
  }

  /// Espera a que [arrancar] termine, o falla después de [segundos]. Todo en
  /// el hilo principal: lo que llegue primero gana y lo demás se ignora.
  private func esperar<T>(
    segundos: Double, _ arrancar: (@escaping (Result<T, Error>) -> Void) -> Void
  ) async throws -> T {
    try await withCheckedThrowingContinuation { (continuacion: CheckedContinuation<T, Error>) in
      var terminado = false
      let terminar: (Result<T, Error>) -> Void = { resultado in
        guard !terminado else { return }
        terminado = true
        continuacion.resume(with: resultado)
      }
      arrancar(terminar)
      DispatchQueue.main.asyncAfter(deadline: .now() + segundos) { terminar(.failure(Falla.sinRespuesta)) }
    }
  }
}

/// "Registra un gasto": Siri pregunta, entiende, confirma y guarda sin abrir
/// la app. Pide el iPhone desbloqueado.
@available(iOS 17.0, *)
struct RegistrarGastoIntent: AppIntent {
  static let title: LocalizedStringResource = "Registrar un gasto"
  static let description = IntentDescription(
    "Dile a Siri qué gastaste, por ejemplo \"230 en el súper con la BBVA\", y MAVfin lo registra sin abrirse."
  )
  static let openAppWhenRun = false
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(
    title: "Gasto",
    description: "Cuánto, en qué y, si quieres, con qué cuenta y cuándo.",
    requestValueDialog: IntentDialog("¿Qué gastaste?")
  )
  var frase: String

  @Parameter(title: "Categoría", requestValueDialog: IntentDialog("¿En qué categoría va?"))
  var categoria: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Registrar \(\.$frase)")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let motor = MotorSiri.compartido
    var respuesta = try await motor.llamar("interpretar", ["frase": frase])

    // Lo que falte se pregunta; un par de vueltas como mucho.
    for _ in 0..<3 {
      let estado = respuesta["estado"] as? String ?? ""
      let mensaje = respuesta["mensaje"] as? String ?? ""
      switch estado {
      case "faltaMonto", "variosGastos":
        throw $frase.needsValueError(IntentDialog(stringLiteral: mensaje))
      case "faltaCategoria":
        let dicha = try await $categoria.requestValue(IntentDialog(stringLiteral: mensaje))
        respuesta = try await motor.llamar(
          "conCategoria", ["propuesta": respuesta["propuesta"] as? String ?? "", "categoria": dicha])
        continue
      case "listo":
        break
      default:
        return .result(dialog: IntentDialog(stringLiteral: mensaje))
      }
      break
    }
    guard respuesta["estado"] as? String == "listo", let propuesta = respuesta["propuesta"] as? String else {
      return .result(dialog: IntentDialog(stringLiteral: respuesta["mensaje"] as? String ?? "No pude registrarlo."))
    }

    try await requestConfirmation(
      result: .result(dialog: IntentDialog(stringLiteral: respuesta["mensaje"] as? String ?? "¿Lo registro?")),
      confirmationActionName: .add
    )

    let hecho = try await motor.llamar("registrar", ["propuesta": propuesta])
    if hecho["estado"] as? String == "registrado" {
      if let widget = hecho["widget"] as? [String: Any] { AccesosRapidos.guardarWidget(widget) }
      AccesosRapidos.avisarDatosCambiaron()
    }
    return .result(dialog: IntentDialog(stringLiteral: hecho["mensaje"] as? String ?? "Listo."))
  }
}

/// "¿Cuánto llevo gastado?": lo mismo que el héroe de Inicio, en voz.
@available(iOS 17.0, *)
struct ConsultarGastadoIntent: AppIntent {
  static let title: LocalizedStringResource = "Cuánto llevo gastado"
  static let description = IntentDescription("Te dice cuánto llevas gastado en el ciclo y cuánto te queda.")
  static let openAppWhenRun = false
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let respuesta = try await MotorSiri.compartido.llamar("resumen")
    if let widget = respuesta["widget"] as? [String: Any] { AccesosRapidos.guardarWidget(widget) }
    return .result(dialog: IntentDialog(stringLiteral: respuesta["mensaje"] as? String ?? ""))
  }
}

/// Las frases de Siri. Siri no deja meter el monto en la frase que activa
/// el atajo, así que el gasto se dice en un segundo paso.
@available(iOS 17.0, *)
struct AtajosFinanzas: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RegistrarGastoIntent(),
      phrases: [
        "Registra un gasto en \(.applicationName)",
        "Registrar un gasto en \(.applicationName)",
        "Registrar gasto en \(.applicationName)",
        "Anota un gasto en \(.applicationName)",
        "Agrega un gasto en \(.applicationName)",
        "Nuevo gasto en \(.applicationName)",
      ],
      shortTitle: "Registrar gasto",
      systemImageName: "plus.circle.fill"
    )
    AppShortcut(
      intent: ConsultarGastadoIntent(),
      phrases: [
        "Cuánto llevo gastado en \(.applicationName)",
        "Cuánto he gastado en \(.applicationName)",
        "Cuánto me queda en \(.applicationName)",
        "Cómo voy en \(.applicationName)",
      ],
      shortTitle: "Cuánto llevo",
      systemImageName: "chart.bar.fill"
    )
    AppShortcut(
      intent: DictarGastoIntent(),
      phrases: [
        "Dicta un gasto en \(.applicationName)",
        "Abre el dictado en \(.applicationName)",
      ],
      shortTitle: "Dictar en la app",
      systemImageName: "mic.fill"
    )
  }
}
