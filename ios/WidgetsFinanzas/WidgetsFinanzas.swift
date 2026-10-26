import AppIntents
import SwiftUI
import WidgetKit

// Widgets de FinVita (spec-app-finanzas-v2.md §5.6): un solo dato
// (cuánto queda hoy) y un solo flujo (registrar un gasto). El widget nunca
// calcula nada: muestra lo que la app dejó en el App Group
// (ios/Runner/AccesosRapidos.swift) y abre la app con un URL.

private let appGroup = "group.com.manuelelizalde.appfinanzas"
private let urlGasto = URL(string: "appfinanzas://gasto")!
private let urlDictar = URL(string: "appfinanzas://dictar")!

// lib/ui/comun/paleta.dart (dirección visual premium)
private let azul = Color(red: 0x0B / 255, green: 0x1F / 255, blue: 0x3B / 255)
private let azulSuave = Color(red: 0xE9 / 255, green: 0xEE / 255, blue: 0xF6 / 255)
private let oro = Color(red: 0xD4 / 255, green: 0xAF / 255, blue: 0x37 / 255)
private let tinta = azul
private let medio = Color(red: 0x5F / 255, green: 0x64 / 255, blue: 0x84 / 255)
private let fondo = Color(red: 0xFC / 255, green: 0xFA / 255, blue: 0xF7 / 255)

// MARK: - Datos

struct EntradaFinanzas: TimelineEntry {
  let date: Date
  /// `nil` si no hay dato de hoy: sin App Group, o la app no se ha abierto
  /// hoy (el dato de ayer ya no vale, porque cambian los días que faltan).
  let quedaHoy: String?
}

struct ProveedorFinanzas: TimelineProvider {
  func placeholder(in context: Context) -> EntradaFinanzas {
    EntradaFinanzas(date: .now, quedaHoy: "$828.15")
  }

  func getSnapshot(in context: Context, completion: @escaping (EntradaFinanzas) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : leer())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<EntradaFinanzas>) -> Void) {
    // A medianoche se vuelve a leer: si la app no ha publicado el dato del
    // día nuevo, el widget deja de mostrar el de ayer.
    let manana = Calendar.current.startOfDay(for: .now.addingTimeInterval(24 * 60 * 60))
    completion(Timeline(entries: [leer()], policy: .after(manana)))
  }

  private func leer() -> EntradaFinanzas {
    let compartidas = UserDefaults(suiteName: appGroup)
    guard let texto = compartidas?.string(forKey: "quedaHoyTexto"),
      compartidas?.string(forKey: "fecha") == Self.hoy()
    else { return EntradaFinanzas(date: .now, quedaHoy: nil) }
    return EntradaFinanzas(date: .now, quedaHoy: texto)
  }

  /// Misma forma que publica `AccesosRapidos.publicarDisponibleHoy` en Dart.
  private static func hoy() -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }
}

// MARK: - Widget principal: cuánto queda hoy + registrar

struct VistaQuedaHoy: View {
  @Environment(\.widgetFamily) private var familia
  let entrada: EntradaFinanzas

  var body: some View {
    switch familia {
    case .systemMedium: mediano
    case .accessoryRectangular: rectangular
    case .accessoryInline: enLinea
    default: chico
    }
  }

  private var dato: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(entrada.quedaHoy == nil ? "Registra tus gastos" : "Hoy puedes gastar")
        .font(.caption)
        .foregroundStyle(medio)
      Text(entrada.quedaHoy ?? "Abre la app")
        .font(.system(size: entrada.quedaHoy == nil ? 17 : 24, weight: .heavy, design: .rounded))
        .foregroundStyle(tinta)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
  }

  private var chico: some View {
    VStack(alignment: .leading) {
      dato
      Spacer()
      HStack(spacing: 6) {
        Image(systemName: "plus.circle.fill")
          .foregroundStyle(oro)
        Text("Registrar")
          .foregroundStyle(azul)
      }
      .font(.subheadline.weight(.semibold))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .widgetURL(urlGasto)
  }

  private var mediano: some View {
    HStack(spacing: 12) {
      dato.frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 8) {
        BotonWidget(titulo: "Gasto", icono: "plus", url: urlGasto, destacado: true)
        BotonWidget(titulo: "Dictar", icono: "mic.fill", url: urlDictar)
      }
      .frame(width: 112)
    }
  }

  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(entrada.quedaHoy == nil ? "FinVita" : "Hoy puedes gastar")
        .font(.caption2)
      Text(entrada.quedaHoy ?? "Registrar gasto")
        .font(.headline)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(urlGasto)
  }

  private var enLinea: some View {
    Text(entrada.quedaHoy.map { "Hoy: \($0)" } ?? "Registrar gasto")
      .widgetURL(urlGasto)
  }
}

struct BotonWidget: View {
  let titulo: String
  let icono: String
  let url: URL
  /// En oro: la acción principal (registrar). El resto en azul noche.
  var destacado = false

  var body: some View {
    Link(destination: url) {
      HStack(spacing: 6) {
        Image(systemName: icono)
        Text(titulo)
      }
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(destacado ? azul : .white)
      .frame(maxWidth: .infinity, minHeight: 40)
      .background(destacado ? oro : azul, in: RoundedRectangle(cornerRadius: 12))
    }
  }
}

struct WidgetQuedaHoy: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WidgetQuedaHoy", provider: ProveedorFinanzas()) { entrada in
      VistaQuedaHoy(entrada: entrada)
        .containerBackground(fondo, for: .widget)
    }
    .configurationDisplayName("Cuánto queda hoy")
    .description("Lo que te queda para gastar hoy y un toque para registrar.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

// MARK: - Botones redondos para la pantalla bloqueada

struct VistaBotonRedondo: View {
  let icono: String
  let url: URL

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Image(systemName: icono).font(.title2.weight(.semibold))
    }
    .widgetURL(url)
  }
}

struct WidgetRegistrarGasto: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WidgetRegistrarGasto", provider: ProveedorFinanzas()) { _ in
      VistaBotonRedondo(icono: "plus", url: urlGasto)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Registrar gasto")
    .description("Abre la captura de un gasto.")
    .supportedFamilies([.accessoryCircular])
  }
}

struct WidgetDictarGasto: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WidgetDictarGasto", provider: ProveedorFinanzas()) { _ in
      VistaBotonRedondo(icono: "mic.fill", url: urlDictar)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Dictar gasto")
    .description("Abre la app escuchando para que dictes el gasto.")
    .supportedFamilies([.accessoryCircular])
  }
}

// MARK: - Centro de Control (iOS 18)

@available(iOS 18.0, *)
struct ControlDictarGasto: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "ControlDictarGasto") {
      // Un control solo puede abrir la app con un AppIntent que viva
      // también en la app (`OpenURLIntent` no abre esquemas propios).
      ControlWidgetButton(action: DictarGastoIntent()) {
        Label("Dictar gasto", systemImage: "mic.fill")
      }
    }
    .displayName("Dictar gasto")
    .description("Abre FinVita escuchando para que dictes el gasto.")
  }
}

@main
struct WidgetsFinanzas: WidgetBundle {
  var body: some Widget {
    WidgetQuedaHoy()
    WidgetRegistrarGasto()
    WidgetDictarGasto()
    if #available(iOS 18.0, *) {
      ControlDictarGasto()
    }
  }
}

#if DEBUG
  #Preview("Mediano", as: .systemMedium) {
    WidgetQuedaHoy()
  } timeline: {
    EntradaFinanzas(date: .now, quedaHoy: "$828.15")
    EntradaFinanzas(date: .now, quedaHoy: nil)
  }

  #Preview("Chico", as: .systemSmall) {
    WidgetQuedaHoy()
  } timeline: {
    EntradaFinanzas(date: .now, quedaHoy: "$828.15")
  }
#endif
