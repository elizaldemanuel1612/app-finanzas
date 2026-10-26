import 'dart:convert';

/// Cómo combinar el dispositivo con la nube (spec-app-finanzas-v2.md §4.2.1).
enum ModoFusion {
  /// Junta ambos (fusión de tres vías contra la última sincronización);
  /// donde el mismo registro difiere, gana el dispositivo.
  combinar,

  /// El dispositivo queda igual que la nube.
  usarNube,

  /// La nube queda igual que el dispositivo.
  usarDispositivo,
}

/// Qué hacer con una colección después de fusionar.
final class ResultadoFusion {
  /// Lo que queda guardado en el dispositivo.
  final List<Map<String, dynamic>> local;

  /// Documentos a escribir en la nube, por clave.
  final Map<String, Map<String, dynamic>> subir;

  /// Claves a borrar de la nube.
  final Set<String> borrarEnNube;

  /// Claves que ambos lados tienen al terminar: la base de la próxima
  /// fusión de tres vías.
  final Set<String> base;

  const ResultadoFusion({
    required this.local,
    required this.subir,
    required this.borrarEnNube,
    required this.base,
  });

  bool get hayCambiosEnNube => subir.isNotEmpty || borrarEnNube.isNotEmpty;
}

/// Clave de cada registro según el archivo de datos donde vive (§4.2.1).
/// `null` para un archivo que no se sincroniza.
String Function(Map<String, dynamic>)? claveDeArchivo(String nombre) => switch (nombre) {
      'categorias.json' || 'ciclos.json' || 'ingresos.json' => (m) => m['id'] as String,
      'movimientos.json' => (m) => m['clientId'] as String,
      'reglas_aprendidas.json' => (m) => m['patron'] as String,
      'ajustes_presupuesto_ciclo.json' => (m) => '${m['cicloId']}|${m['categoriaId']}|${m['cuando']}',
      'perfil.json' => (_) => 'perfil',
      _ => null,
    };

/// Fusiona una colección del dispositivo con la de la nube.
///
/// - [base]: claves que ambos lados tenían en la última sincronización
///   (`null` la primera vez). Con base, lo que se borró de un lado se borra
///   del otro en vez de "revivir".
/// - [anularEnVezDeBorrar]: para movimientos (regla #3): lo que sobra en la
///   nube no se borra, se sube con `estado: anulado`.
///
/// Al chocar dos versiones de un mismo registro: `anulado` gana siempre, un
/// ciclo `cerrado` gana sobre uno abierto (regla #6) y, fuera de eso, gana
/// el dispositivo.
ResultadoFusion fusionarColeccion({
  required List<Map<String, dynamic>> local,
  required Map<String, Map<String, dynamic>> nube,
  required String Function(Map<String, dynamic>) clave,
  required ModoFusion modo,
  Set<String>? base,
  bool anularEnVezDeBorrar = false,
}) {
  final porClave = {for (final m in local) clave(m): m};

  switch (modo) {
    case ModoFusion.usarNube:
      return ResultadoFusion(
        local: nube.values.toList(),
        subir: const {},
        borrarEnNube: const {},
        base: nube.keys.toSet(),
      );

    case ModoFusion.usarDispositivo:
      final subir = <String, Map<String, dynamic>>{
        for (final e in porClave.entries)
          if (!_iguales(e.value, nube[e.key])) e.key: e.value,
      };
      final borrar = <String>{};
      final base = porClave.keys.toSet();
      for (final e in nube.entries) {
        if (porClave.containsKey(e.key)) continue;
        if (anularEnVezDeBorrar) {
          if (e.value['estado'] != 'anulado') subir[e.key] = {...e.value, 'estado': 'anulado'};
          base.add(e.key);
        } else {
          borrar.add(e.key);
        }
      }
      return ResultadoFusion(local: local, subir: subir, borrarEnNube: borrar, base: base);

    case ModoFusion.combinar:
      final resultado = <String, Map<String, dynamic>>{};
      final subir = <String, Map<String, dynamic>>{};
      final borrar = <String>{};
      final claves = {...porClave.keys, ...nube.keys};
      for (final k in claves) {
        final l = porClave[k];
        final n = nube[k];
        final estaba = base?.contains(k) ?? false;
        if (l != null && n != null) {
          final v = _ganador(l, n);
          resultado[k] = v;
          if (!_iguales(v, n)) subir[k] = v;
        } else if (l != null) {
          // Solo aquí: o es nuevo, o la nube lo borró desde otro dispositivo.
          if (estaba && !anularEnVezDeBorrar) continue;
          resultado[k] = l;
          subir[k] = l;
        } else {
          // Solo en la nube: o es nuevo de otro dispositivo, o aquí se borró.
          if (estaba) {
            if (anularEnVezDeBorrar) {
              resultado[k] = n!;
            } else {
              borrar.add(k);
            }
            continue;
          }
          resultado[k] = n!;
        }
      }
      // Conserva el orden original del dispositivo; lo nuevo, al final.
      final ordenado = <Map<String, dynamic>>[
        for (final m in local)
          if (resultado.containsKey(clave(m))) resultado[clave(m)]!,
        for (final e in resultado.entries)
          if (!porClave.containsKey(e.key)) e.value,
      ];
      return ResultadoFusion(local: ordenado, subir: subir, borrarEnNube: borrar, base: resultado.keys.toSet());
  }
}

Map<String, dynamic> _ganador(Map<String, dynamic> local, Map<String, dynamic> nube) {
  if (_iguales(local, nube)) return local;
  final lAnulado = local['estado'] == 'anulado';
  final nAnulado = nube['estado'] == 'anulado';
  if (lAnulado != nAnulado) return lAnulado ? local : nube;
  final lCerrado = local['estado'] == 'cerrado';
  final nCerrado = nube['estado'] == 'cerrado';
  if (lCerrado != nCerrado) return lCerrado ? local : nube;
  return local;
}

/// Igualdad por contenido, sin importar el orden de las llaves (la nube no
/// lo conserva).
bool _iguales(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (a == null || b == null) return a == b;
  return _canonico(a) == _canonico(b);
}

String _canonico(Object? valor) => jsonEncode(_ordenar(valor));

Object? _ordenar(Object? valor) {
  if (valor is Map) {
    final llaves = valor.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in llaves) k: _ordenar(valor[k])};
  }
  if (valor is List) return valor.map(_ordenar).toList();
  return valor;
}
