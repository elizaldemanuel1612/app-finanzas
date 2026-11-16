import Flutter
import UIKit
import XCTest

@testable import Runner

/// Siri de punta a punta dentro de la app (spec-app-finanzas-v2.md §5.6.3):
/// `MotorSiri` arranca el Dart sin pantalla, entiende la frase, guarda en
/// los mismos archivos de la app y contesta. Corre en el simulador con
/// `xcodebuild test` (ver docs/tiendas/checklist-publicacion.md).
final class SiriTests: XCTestCase {
  private let uid = "prueba-siri"
  private var carpeta: URL!

  override func setUpWithError() throws {
    let documentos = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    carpeta = documentos.appendingPathComponent("usuarios/\(uid)")
    try? FileManager.default.removeItem(at: carpeta)
    try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
    // Lo mismo que escriben los repositorios de Dart (mismos nombres de campo).
    try escribir("perfil.json", #"{"diaCorte":12,"ingresoBaseMensualCentavos":3000000,"moneda":"MXN","zonaHoraria":"America/Mexico_City"}"#)
    try escribir("categorias.json", #"""
      [{"tipo":"variable","id":"super","nombre":"Súper/Comida","emoji":"🛒","activa":true,"esNecesaria":true,"presupuestoMensualCentavos":400000},{"tipo":"variable","id":"salidas","nombre":"Salidas","emoji":"🍽️","activa":true,"esNecesaria":false,"presupuestoMensualCentavos":150000},{"tipo":"variable","id":"transporte","nombre":"Transporte","emoji":"🚕","activa":true,"esNecesaria":false,"presupuestoMensualCentavos":80000},{"tipo":"variable","id":"mascotas","nombre":"Mascotas","emoji":"🐶","activa":true,"esNecesaria":false,"presupuestoMensualCentavos":70000}]
      """#)
    try escribir("cuentas.json", #"[{"id":"bbva","nombre":"BBVA","emoji":"🟦","tipo":"debito","llevaSaldo":true,"saldoInicialCentavos":500000,"fechaSaldoInicial":"2026-01-01T00:00:00.000","activa":true}]"#)
    UserDefaults.standard.set(uid, forKey: "siri.cuenta")
  }

  override func tearDownWithError() throws {
    UserDefaults.standard.removeObject(forKey: "siri.cuenta")
    try? FileManager.default.removeItem(at: carpeta)
  }

  /// Corre [bloque] en el hilo principal y espera. Las pruebas `async` de
  /// XCTest se cerraban solas en este Xcode antes de llegar al código.
  private func correr(_ bloque: @escaping @MainActor () async throws -> Void) {
    let hecho = expectation(description: "Siri")
    Task { @MainActor in
      do {
        try await bloque()
      } catch {
        XCTFail("\(error)")
      }
      hecho.fulfill()
    }
    wait(for: [hecho], timeout: 90)
  }

  private func escribir(_ nombre: String, _ texto: String) throws {
    try texto.write(to: carpeta.appendingPathComponent(nombre), atomically: true, encoding: .utf8)
  }

  private func movimientos() throws -> [[String: Any]] {
    let url = carpeta.appendingPathComponent("movimientos.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]] ?? []
  }

  func testEntiendeConfirmaYGuarda() {
    correr {
      let motor = MotorSiri.compartido
      let inicio = Date()
      let entendido = try await motor.llamar("interpretar", ["frase": "ayer gasté 230 en el súper con la BBVA"])
      print("interpretar (con arranque): \(Int(Date().timeIntervalSince(inicio) * 1000)) ms")
      XCTAssertEqual(entendido["estado"] as? String, "listo")
      XCTAssertEqual(entendido["mensaje"] as? String, "¿Registro $230 en Súper y Comida con BBVA, ayer?")

      let hecho = try await motor.llamar("registrar", ["propuesta": try XCTUnwrap(entendido["propuesta"] as? String)])
      XCTAssertEqual(hecho["estado"] as? String, "registrado")
      XCTAssertEqual(hecho["mensaje"] as? String, "Listo. Te quedan $3,770 en Súper y Comida.")
      let widget = try XCTUnwrap(hecho["widget"] as? [String: Any])
      XCTAssertEqual(widget["deTexto"] as? String, "de $7,000.00")

      let guardados = try self.movimientos()
      XCTAssertEqual(guardados.count, 1)
      XCTAssertEqual(guardados.first?["montoCentavos"] as? Int, 23000)
      XCTAssertEqual(guardados.first?["categoriaId"] as? String, "super")
      XCTAssertEqual(guardados.first?["cuentaId"] as? String, "bbva")
      XCTAssertEqual(guardados.first?["origenCaptura"] as? String, "voz")
    }
  }

  func testPreguntaLaCategoriaYElMonto() {
    correr {
      let motor = MotorSiri.compartido
      let sinMonto = try await motor.llamar("interpretar", ["frase": "fui al súper"])
      XCTAssertEqual(sinMonto["estado"] as? String, "faltaMonto")

      // Sin pista en las reglas: o Apple Intelligence la propone (si el
      // simulador la tiene) o se pregunta.
      let inicio = Date()
      let r = try await motor.llamar("interpretar", ["frase": "350 en croquetas para el perro"])
      print("interpretar con IA: \(Int(Date().timeIntervalSince(inicio) * 1000)) ms → \(r["estado"] ?? "") \(r["mensaje"] ?? "")")
      let estado = r["estado"] as? String
      XCTAssertTrue(estado == "listo" || estado == "faltaCategoria")
      if estado == "listo" {
        XCTAssertEqual(r["mensaje"] as? String, "¿Registro $350 en Mascotas con BBVA, hoy?")
      }

      let pregunta = try await motor.llamar("interpretar", ["frase": "350 en la tlapalería"])
      if pregunta["estado"] as? String == "faltaCategoria" {
        let lista = try await motor.llamar(
          "conCategoria", ["propuesta": try XCTUnwrap(pregunta["propuesta"] as? String), "categoria": "salidas"])
        XCTAssertEqual(lista["estado"] as? String, "listo")
      }
    }
  }

  func testResumenYSinSesion() {
    correr {
      let motor = MotorSiri.compartido
      let r = try await motor.llamar("resumen")
      XCTAssertTrue((r["mensaje"] as? String ?? "").hasPrefix("Llevas $0 de $7,000 este ciclo."), "\(r)")

      UserDefaults.standard.removeObject(forKey: "siri.cuenta")
      let sin = try await motor.llamar("interpretar", ["frase": "230 en el súper"])
      XCTAssertEqual(sin["estado"] as? String, "sinSesion")
    }
  }
}
