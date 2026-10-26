/// Dónde vive la copia del respaldo (spec-app-finanzas-v2.md §4.2.1). Hoy
/// es el Google Drive del propio usuario (`respaldo_drive.dart`); la
/// fusión de `servicio_nube.dart` no sabe de Drive, solo de esto.
///
/// Las colecciones van por nombre de archivo local (`movimientos.json`, …),
/// cada una como lista de registros JSON.
abstract interface class RespaldoRemoto {
  /// Confirma que hay acceso a la copia. Con [interactivo] puede pedirle
  /// permiso al usuario (ventana de Google); sin él, solo usa un permiso
  /// ya concedido y devuelve `false` si no lo hay.
  Future<bool> tieneAcceso({required bool interactivo});

  /// `null` si todavía no hay respaldo.
  Future<Map<String, List<Map<String, dynamic>>>?> descargar();

  /// Reemplaza la copia completa.
  Future<void> subir(Map<String, List<Map<String, dynamic>>> colecciones);

  /// No es error si no existía.
  Future<void> borrar();
}

/// Para pruebas: la "nube" vive en memoria.
final class RespaldoEnMemoria implements RespaldoRemoto {
  Map<String, List<Map<String, dynamic>>>? copia;
  bool acceso;

  /// Cuántas veces se subió la copia completa.
  int subidas = 0;

  RespaldoEnMemoria({this.copia, this.acceso = true});

  @override
  Future<bool> tieneAcceso({required bool interactivo}) async => acceso;

  @override
  Future<Map<String, List<Map<String, dynamic>>>?> descargar() async {
    _exigirAcceso();
    final c = copia;
    return c == null ? null : {for (final e in c.entries) e.key: [for (final m in e.value) Map.of(m)]};
  }

  @override
  Future<void> subir(Map<String, List<Map<String, dynamic>>> colecciones) async {
    _exigirAcceso();
    subidas++;
    copia = {for (final e in colecciones.entries) e.key: [for (final m in e.value) Map.of(m)]};
  }

  @override
  Future<void> borrar() async {
    _exigirAcceso();
    copia = null;
  }

  void _exigirAcceso() {
    if (!acceso) throw StateError('Sin acceso al respaldo.');
  }
}
