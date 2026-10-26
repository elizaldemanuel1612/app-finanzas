import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/sincronizacion/fusion.dart';
import '../almacenamiento/archivo_texto.dart';
import '../repositorios/local/almacen_local.dart';

/// Qué tiene cada lado antes de activar el respaldo, para decidir si hay
/// que preguntarle al usuario cómo combinar (spec-app-finanzas-v2.md §4.2.1).
final class EstadoInicialNube {
  final bool hayDatosEnNube;
  final bool hayDatosLocales;

  const EstadoInicialNube({required this.hayDatosEnNube, required this.hayDatosLocales});

  bool get hayQueElegir => hayDatosEnNube && hayDatosLocales;
}

/// Respaldo y sincronización con Firestore en `cuentas/{uid}` (§4.2.1).
/// Los datos siguen viviendo en el dispositivo (§4.1): esto solo copia y
/// combina. La lógica de qué gana vive en `domain/sincronizacion/fusion.dart`.
final class ServicioNube {
  final String uid;
  final AlmacenLocal almacen;
  final FirebaseFirestore _db;

  ServicioNube({required this.uid, required this.almacen, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static const _maxPorLote = 400;

  /// Una sola sincronización a la vez por proceso.
  static Future<void>? _enCurso;

  DocumentReference<Map<String, dynamic>> get _cuenta => _db.collection('cuentas').doc(uid);

  CollectionReference<Map<String, dynamic>> _coleccion(String archivo) =>
      _cuenta.collection(archivo.replaceAll('.json', ''));

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
    final enNube = await hayRespaldoEnNube();
    final perfil = await almacen.perfil.obtener();
    final movimientos = await almacen.movimientos.listarTodos();
    return EstadoInicialNube(
      hayDatosEnNube: enNube,
      hayDatosLocales: perfil != null || movimientos.isNotEmpty,
    );
  }

  /// Hay un perfil respaldado para esta cuenta.
  Future<bool> hayRespaldoEnNube() async {
    final perfil = await _coleccion('perfil.json').doc('perfil').get(const GetOptions(source: Source.server));
    return perfil.exists;
  }

  // ───────────── acciones ─────────────

  /// Activa el respaldo con el [modo] elegido y sincroniza.
  Future<void> activar(ModoFusion modo) => _sincronizar(modo, activar: true);

  /// Sincronización de rutina (al abrir, volver o salir de la app). No hace
  /// nada si el respaldo no está activo. Nunca lanza: sin red, espera a la
  /// siguiente.
  Future<bool> sincronizarSiActiva() async {
    if (!await estaActiva()) return false;
    try {
      await _sincronizar(ModoFusion.combinar, activar: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// "Sincronizar ahora": como la de rutina, pero el error sí llega a la UI.
  Future<void> sincronizarAhora() => _sincronizar(ModoFusion.combinar, activar: false);

  /// Deja de sincronizar. La copia en la nube se conserva.
  Future<void> desactivar() async {
    final estado = await _leerEstado();
    estado['activa'] = false;
    estado.remove('base');
    await _guardarEstado(estado);
  }

  /// Borra la copia en la nube (Ajustes o "Eliminar cuenta") y desactiva.
  Future<void> borrarCopiaEnNube() async {
    for (final archivo in AlmacenLocal.nombresDeArchivo) {
      final docs = await _coleccion(archivo).get(const GetOptions(source: Source.server));
      for (var i = 0; i < docs.docs.length; i += _maxPorLote) {
        final lote = _db.batch();
        for (final d in docs.docs.skip(i).take(_maxPorLote)) {
          lote.delete(d.reference);
        }
        await lote.commit();
      }
    }
    await _cuenta.delete();
    await _guardarEstado({'activa': false});
  }

  Future<void> _sincronizar(ModoFusion modo, {required bool activar}) async {
    while (_enCurso != null) {
      await _enCurso;
    }
    final completador = Completer<void>();
    _enCurso = completador.future;
    try {
      final estado = await _leerEstado();
      final bases = (estado['base'] as Map<String, dynamic>?) ?? {};
      final nuevasBases = <String, List<String>>{};

      for (final archivo in AlmacenLocal.nombresDeArchivo) {
        final clave = claveDeArchivo(archivo)!;
        final local = await _leerLocal(archivo);
        final docs = await _coleccion(archivo).get(const GetOptions(source: Source.server));
        final nube = {for (final d in docs.docs) clave(d.data()): d.data()};
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
        await _escribirNube(archivo, r);
        nuevasBases[archivo] = r.base.toList();
      }

      await _cuenta.set({
        'nubeActiva': true,
        'actualizado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

  Future<void> _escribirNube(String archivo, ResultadoFusion r) async {
    final operaciones = <void Function(WriteBatch)>[
      for (final e in r.subir.entries)
        (lote) => lote.set(_coleccion(archivo).doc(_idDoc(e.key)), e.value),
      for (final k in r.borrarEnNube) (lote) => lote.delete(_coleccion(archivo).doc(_idDoc(k))),
    ];
    for (var i = 0; i < operaciones.length; i += _maxPorLote) {
      final lote = _db.batch();
      for (final op in operaciones.skip(i).take(_maxPorLote)) {
        op(lote);
      }
      await lote.commit();
    }
  }

  /// Un id de documento válido para cualquier clave (sin "/").
  static String _idDoc(String clave) => Uri.encodeComponent(clave);
}
