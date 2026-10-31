import 'dart:async';
import 'dart:convert';

import '../../domain/sincronizacion/fusion.dart';
import '../almacenamiento/archivo_texto.dart';
import '../repositorios/local/almacen_local.dart';
import 'respaldo_remoto.dart';

/// Qué tiene cada lado antes de activar el respaldo, para decidir si hay
/// que preguntarle al usuario cómo combinar (spec-app-finanzas-v2.md §4.2.1).
final class EstadoInicialNube {
  final bool hayDatosEnNube;
  final bool hayDatosLocales;

  const EstadoInicialNube({required this.hayDatosEnNube, required this.hayDatosLocales});

  bool get hayQueElegir => hayDatosEnNube && hayDatosLocales;
}

/// Respaldo y sincronización con la copia del usuario (§4.2.1, hoy su
/// Google Drive vía [RespaldoRemoto]). Los datos siguen viviendo en el
/// dispositivo (§4.1): esto solo copia y combina. La lógica de qué gana
/// vive en `domain/sincronizacion/fusion.dart`.
///
/// Las acciones que el usuario dispara con un botón ([estadoInicial],
/// [activar], [sincronizarAhora], [borrarCopiaEnNube]) piden el acceso
/// **antes de cualquier otra espera**: en la web la ventana de permiso de
/// Google solo se abre si sale directo del toque.
final class ServicioNube {
  final AlmacenLocal almacen;
  final RespaldoRemoto remoto;

  ServicioNube({required this.almacen, required this.remoto});

  /// Una sola sincronización a la vez por proceso.
  static Future<void>? _enCurso;

  // ───────────── estado local del respaldo (no se sincroniza) ─────────────

  ArchivoTexto get _estadoArchivo => almacen.estadoNube;

  Future<Map<String, dynamic>> _leerEstado() async {
    final texto = await _estadoArchivo.leer();
    if (texto == null || texto.trim().isEmpty) return {};
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  Future<void> _guardarEstado(Map<String, dynamic> estado) => _estadoArchivo.escribir(jsonEncode(estado));

  Future<bool> estaActiva() async => (await _leerEstado())['activa'] == true;

  Future<DateTime?> ultimaSincronizacion() async {
    final texto = (await _leerEstado())['ultima'] as String?;
    return texto == null ? null : DateTime.tryParse(texto);
  }

  // ───────────── consultas ─────────────

  Future<EstadoInicialNube> estadoInicial() async {
    await _exigirAcceso();
    final enNube = await _hayPerfilRespaldado();
    final perfil = await almacen.perfil.obtener();
    final movimientos = await almacen.movimientos.listarTodos();
    return EstadoInicialNube(
      hayDatosEnNube: enNube,
      hayDatosLocales: perfil != null || movimientos.isNotEmpty,
    );
  }

  /// Hay un perfil respaldado para esta cuenta. Sin un permiso ya concedido
  /// responde `false` sin preguntar (arranque de la app).
  Future<bool> hayRespaldoEnNube() async {
    if (!await remoto.tieneAcceso(interactivo: false)) return false;
    return _hayPerfilRespaldado();
  }

  Future<bool> _hayPerfilRespaldado() async {
    final copia = await remoto.descargar();
    return copia?['perfil.json']?.isNotEmpty ?? false;
  }

  // ───────────── acciones ─────────────

  /// Activa el respaldo con el [modo] elegido y sincroniza.
  Future<void> activar(ModoFusion modo) async {
    await _exigirAcceso();
    await _sincronizar(modo, activar: true);
  }

  /// Sincronización de rutina (al abrir, volver o salir de la app). No hace
  /// nada si el respaldo no está activo o si haría falta pedir permiso.
  /// Nunca lanza: sin red, espera a la siguiente.
  Future<bool> sincronizarSiActiva() async {
    try {
      if (!await estaActiva()) return false;
      if (!await remoto.tieneAcceso(interactivo: false)) return false;
      await _sincronizar(ModoFusion.combinar, activar: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// "Sincronizar ahora": como la de rutina, pero puede pedir permiso y el
  /// error sí llega a la UI.
  Future<void> sincronizarAhora() async {
    await _exigirAcceso();
    await _sincronizar(ModoFusion.combinar, activar: false);
  }

  /// Pide el permiso de Drive; en la web, llamar directo desde el toque.
  Future<bool> pedirAcceso() => remoto.tieneAcceso(interactivo: true);

  /// Lo que se guarde a continuación reemplaza la copia en vez de fusionarse
  /// con ella: la fusión revive lo eliminado (importar, spec §7.4). Queda
  /// anotado para que sobreviva a una falta de red.
  Future<void> marcarReemplazo() async {
    final estado = await _leerEstado();
    estado['reemplazar'] = true;
    await _guardarEstado(estado);
  }

  /// Deja de sincronizar. La copia se conserva.
  Future<void> desactivar() async {
    final estado = await _leerEstado();
    estado['activa'] = false;
    estado.remove('base');
    estado.remove('reemplazar');
    await _guardarEstado(estado);
  }

  /// Borra la copia (Ajustes o "Eliminar cuenta") y desactiva.
  Future<void> borrarCopiaEnNube() async {
    await _exigirAcceso();
    await remoto.borrar();
    await _guardarEstado({'activa': false});
  }

  Future<void> _exigirAcceso() async {
    if (!await remoto.tieneAcceso(interactivo: true)) {
      throw StateError('Sin permiso para el respaldo.');
    }
  }

  Future<void> _sincronizar(ModoFusion modo, {required bool activar}) async {
    while (_enCurso != null) {
      await _enCurso;
    }
    final completador = Completer<void>();
    _enCurso = completador.future;
    try {
      final estado = await _leerEstado();
      if (estado['reemplazar'] == true) {
        await _reemplazarCopia();
        return;
      }
      final bases = (estado['base'] as Map<String, dynamic>?) ?? {};
      final nuevasBases = <String, List<String>>{};
      final copia = await remoto.descargar();
      final nuevaCopia = <String, List<Map<String, dynamic>>>{};
      var hayCambiosEnNube = copia == null;

      for (final archivo in AlmacenLocal.nombresDeArchivo) {
        final clave = claveDeArchivo(archivo)!;
        final local = await _leerLocal(archivo);
        final nube = {for (final m in copia?[archivo] ?? const <Map<String, dynamic>>[]) clave(m): m};
        final base = modo == ModoFusion.combinar && !activar
            ? (bases[archivo] as List<dynamic>?)?.cast<String>().toSet()
            : null;

        final r = fusionarColeccion(
          local: local,
          nube: nube,
          clave: clave,
          modo: modo,
          base: base,
          anularEnVezDeBorrar: archivo == 'movimientos.json',
        );

        await _escribirLocal(archivo, r.local);
        final enNube = {...nube, ...r.subir}..removeWhere((k, _) => r.borrarEnNube.contains(k));
        nuevaCopia[archivo] = enNube.values.toList();
        hayCambiosEnNube = hayCambiosEnNube || r.hayCambiosEnNube;
        nuevasBases[archivo] = r.base.toList();
      }

      if (hayCambiosEnNube) await remoto.subir(nuevaCopia);
      await _guardarEstado({
        'activa': true,
        'ultima': DateTime.now().toIso8601String(),
        'base': nuevasBases,
      });
    } finally {
      _enCurso = null;
      completador.complete();
    }
  }

  Future<void> _reemplazarCopia() async {
    final copia = <String, List<Map<String, dynamic>>>{};
    final bases = <String, List<String>>{};
    for (final archivo in AlmacenLocal.nombresDeArchivo) {
      final clave = claveDeArchivo(archivo)!;
      copia[archivo] = await _leerLocal(archivo);
      bases[archivo] = [for (final m in copia[archivo]!) clave(m)];
    }
    await remoto.subir(copia);
    await _guardarEstado({
      'activa': true,
      'ultima': DateTime.now().toIso8601String(),
      'base': bases,
    });
  }

  Future<List<Map<String, dynamic>>> _leerLocal(String archivo) async {
    final texto = await almacen.archivos[archivo]!.leer();
    if (texto == null || texto.trim().isEmpty) return [];
    final valor = jsonDecode(texto);
    // perfil.json es un objeto, no una lista.
    if (valor is Map<String, dynamic>) return [valor];
    return (valor as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _escribirLocal(String archivo, List<Map<String, dynamic>> items) async {
    final destino = almacen.archivos[archivo]!;
    final antes = await destino.leer();
    final String despues;
    if (archivo == 'perfil.json') {
      if (items.isEmpty) return;
      despues = jsonEncode(items.first);
    } else {
      despues = jsonEncode(items);
    }
    if (antes != despues) await destino.escribir(despues);
  }
}
