import 'dart:convert';

import '../../domain/ia/proveedor_ia.dart';
import '../almacenamiento/archivo_texto.dart';

/// Lo que el usuario conectó (spec §6.5). Vive solo en el dispositivo.
final class ConfiguracionIA {
  /// El complemento que usa la app; `null` = ninguno.
  final ProveedorIA? activo;

  /// Clave de API por proveedor (Apple no lleva).
  final Map<ProveedorIA, String> claves;

  /// El modelo elegido al conectar, por proveedor.
  final Map<ProveedorIA, String> modelos;

  /// Apple Intelligence: conectado sin clave.
  final bool appleConectado;

  /// Nivel 3 de la cascada: sugerir categorías con la IA activa.
  final bool sugerirCategorias;

  const ConfiguracionIA({
    this.activo,
    this.claves = const {},
    this.modelos = const {},
    this.appleConectado = false,
    this.sugerirCategorias = false,
  });

  bool conectado(ProveedorIA p) => p == ProveedorIA.apple ? appleConectado : claves.containsKey(p);

  List<ProveedorIA> get conectados => [for (final p in ProveedorIA.values) if (conectado(p)) p];

  ConfiguracionIA conActivo(ProveedorIA? p) => ConfiguracionIA(
        activo: p,
        claves: claves,
        modelos: modelos,
        appleConectado: appleConectado,
        sugerirCategorias: sugerirCategorias,
      );

  ConfiguracionIA conectar(ProveedorIA p, {String? clave, String? modelo}) => ConfiguracionIA(
        activo: p,
        claves: {...claves, p: ?clave},
        modelos: {...modelos, p: ?modelo},
        appleConectado: appleConectado || p == ProveedorIA.apple,
        sugerirCategorias: sugerirCategorias,
      );

  /// Quita el proveedor; si era el activo, pasa al siguiente conectado.
  ConfiguracionIA desconectar(ProveedorIA p) {
    final claves = {...this.claves}..remove(p);
    final modelos = {...this.modelos}..remove(p);
    final apple = appleConectado && p != ProveedorIA.apple;
    final quedan = [
      for (final q in ProveedorIA.values)
        if (q == ProveedorIA.apple ? apple : claves.containsKey(q)) q,
    ];
    return ConfiguracionIA(
      activo: activo == p ? quedan.firstOrNull : activo,
      claves: claves,
      modelos: modelos,
      appleConectado: apple,
      sugerirCategorias: sugerirCategorias && quedan.isNotEmpty,
    );
  }

  ConfiguracionIA conSugerirCategorias(bool v) => ConfiguracionIA(
        activo: activo,
        claves: claves,
        modelos: modelos,
        appleConectado: appleConectado,
        sugerirCategorias: v,
      );

  Map<String, dynamic> toJson() => {
        if (activo != null) 'activo': activo!.name,
        'claves': {for (final e in claves.entries) e.key.name: e.value},
        'modelos': {for (final e in modelos.entries) e.key.name: e.value},
        'appleConectado': appleConectado,
        'sugerirCategorias': sugerirCategorias,
      };

  factory ConfiguracionIA.fromJson(Map<String, dynamic> json) {
    ProveedorIA? proveedor(String? nombre) => ProveedorIA.values.where((p) => p.name == nombre).firstOrNull;
    Map<ProveedorIA, String> mapa(Object? valor) => {
          if (valor is Map)
            for (final e in valor.entries)
              ?proveedor(e.key as String): e.value as String,
        };
    return ConfiguracionIA(
      activo: proveedor(json['activo'] as String?),
      claves: mapa(json['claves']),
      modelos: mapa(json['modelos']),
      appleConectado: json['appleConectado'] as bool? ?? false,
      sugerirCategorias: json['sugerirCategorias'] as bool? ?? false,
    );
  }
}

/// Lee y guarda [ConfiguracionIA] en `ia.json` (no se sincroniza).
final class AlmacenConfiguracionIA {
  final ArchivoTexto archivo;
  const AlmacenConfiguracionIA(this.archivo);

  Future<ConfiguracionIA> leer() async {
    final texto = await archivo.leer();
    if (texto == null || texto.trim().isEmpty) return const ConfiguracionIA();
    try {
      return ConfiguracionIA.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      return const ConfiguracionIA();
    }
  }

  Future<void> guardar(ConfiguracionIA config) => archivo.escribir(jsonEncode(config.toJson()));
}
