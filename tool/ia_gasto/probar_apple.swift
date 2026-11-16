// Mide la clasificación de gastos dichos con Apple Intelligence en la Mac,
// con el mismo esquema que la app (`ios/Runner/AccesosRapidos.swift`,
// `IAApple.categoriaDeGasto`). Ver `tool/ia_gasto/frases.dart`.
import Foundation
import FoundationModels

@main
struct ProbarApple {
  static func main() async throws {
    let datos = try JSONSerialization.jsonObject(
      with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
    let instrucciones = datos["instrucciones"] as! String
    let opciones = datos["opciones"] as! [String]
    let esquema = try GenerationSchema(
      root: DynamicGenerationSchema(
        name: "Gasto",
        properties: [
          .init(name: "categoria", schema: DynamicGenerationSchema(name: "Categoria", anyOf: opciones))
        ]),
      dependencies: [])
    var salida: [[String: Any]] = []
    for f in datos["frases"] as! [[String: String]] {
      let inicio = Date()
      let sesion = LanguageModelSession(instructions: instrucciones)
      let r = try await sesion.respond(
        to: f["mensaje"]!, schema: esquema, options: GenerationOptions(sampling: .greedy))
      let categoria = try r.content.value(String.self, forProperty: "categoria")
      let ms = Int(Date().timeIntervalSince(inicio) * 1000)
      salida.append(["frase": f["frase"]!, "categoria": categoria, "ms": ms])
      FileHandle.standardError.write("\(ms) ms  \(f["frase"]!) → \(categoria)\n".data(using: .utf8)!)
    }
    let json = try JSONSerialization.data(withJSONObject: salida, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(json)
  }
}
