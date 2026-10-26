import 'dart:io';

import '../../almacenamiento/archivo_texto.dart';
import '../../almacenamiento/archivo_texto_disco.dart';
import 'ajuste_presupuesto_ciclo_repositorio_archivo.dart';
import 'categoria_repositorio_archivo.dart';
import 'ciclo_repositorio_archivo.dart';
import 'ingreso_extra_repositorio_archivo.dart';
import 'movimiento_repositorio_archivo.dart';
import 'perfil_repositorio_archivo.dart';
import 'reglas_aprendidas_repositorio_archivo.dart';

/// Punto único de verdad de qué archivos son "los datos de la app" —
/// `main.dart` construía las 6 rutas de archivo inline, así que nadie
/// tenía forma de garantizar que "eliminar cuenta" (Fase 6, Bloque 2)
/// borrara todo. Recibe el [directorio] por fuera, igual que cada
/// repositorio individual, para poder probarse con `dart test` sin
/// `path_provider` ni dispositivo.
final class AlmacenLocal {
  /// Los 7 nombres de archivo que son "los datos de la app" — expuesto para
  /// que `main.dart` pueda migrar datos de antes de que el almacenamiento
  /// se separara por cuenta (ver comentario en `_ContenidoApp._inicializar`)
  /// sin tener que duplicar esta lista.
  static const nombresDeArchivo = [
    'categorias.json',
    'movimientos.json',
    'perfil.json',
    'reglas_aprendidas.json',
    'ciclos.json',
    'ingresos.json',
    'ajustes_presupuesto_ciclo.json',
  ];

  /// Carpeta de la cuenta en el dispositivo (también de las fotos de
  /// tickets). En la web no existe en disco: es solo un nombre.
  final Directory directorio;

  /// Los 7 "archivos" de datos por nombre — lo que sincroniza el respaldo
  /// (`data/nube/servicio_nube.dart`) y lo que borra [borrarTodo].
  final Map<String, ArchivoTexto> archivos;

  /// Estado del respaldo en Drive de esta cuenta (activo, última
  /// sincronización): no son datos de la app, así que no se sincroniza.
  final ArchivoTexto estadoNube;

  /// `false` en la web: no hay sistema de archivos para fotos de tickets.
  final bool admiteFotos;

  final CategoriaRepositorioArchivo categorias;
  final MovimientoRepositorioArchivo movimientos;
  final PerfilRepositorioArchivo perfil;
  final ReglasAprendidasRepositorioArchivo reglasAprendidas;
  final CicloRepositorioArchivo ciclos;
  final IngresoExtraRepositorioArchivo ingresosExtra;
  final AjustePresupuestoCicloRepositorioArchivo ajustesPresupuestoCiclo;

  /// En el teléfono: archivos dentro de [directorio].
  factory AlmacenLocal(Directory directorio) => AlmacenLocal._(
        directorio,
        {
          for (final nombre in nombresDeArchivo)
            nombre: ArchivoTextoDisco(File('${directorio.path}/$nombre')),
        },
        ArchivoTextoDisco(File('${directorio.path}/nube.json')),
        admiteFotos: true,
      );

  /// Con los archivos que se le den: la web (`almacenEnNavegador`, en
  /// `data/almacenamiento/archivo_texto_navegador.dart`, para que este
  /// archivo no dependa de Flutter y se pruebe con `dart test`).
  factory AlmacenLocal.con({
    required Directory directorio,
    required Map<String, ArchivoTexto> archivos,
    required ArchivoTexto estadoNube,
    required bool admiteFotos,
  }) =>
      AlmacenLocal._(directorio, archivos, estadoNube, admiteFotos: admiteFotos);

  /// Con los archivos que se le den (pruebas).
  factory AlmacenLocal.sobre(Map<String, ArchivoTexto> archivos) =>
      AlmacenLocal._(Directory('memoria'), archivos, ArchivoTextoMemoria(), admiteFotos: false);

  AlmacenLocal._(this.directorio, this.archivos, this.estadoNube, {required this.admiteFotos})
      : categorias = CategoriaRepositorioArchivo.sobre(archivos['categorias.json']!),
        movimientos = MovimientoRepositorioArchivo.sobre(archivos['movimientos.json']!),
        perfil = PerfilRepositorioArchivo.sobre(archivos['perfil.json']!),
        reglasAprendidas = ReglasAprendidasRepositorioArchivo.sobre(archivos['reglas_aprendidas.json']!),
        ciclos = CicloRepositorioArchivo.sobre(archivos['ciclos.json']!),
        ingresosExtra = IngresoExtraRepositorioArchivo.sobre(archivos['ingresos.json']!),
        ajustesPresupuestoCiclo =
            AjustePresupuestoCicloRepositorioArchivo.sobre(archivos['ajustes_presupuesto_ciclo.json']!);

  /// Borra los 7 JSON más el directorio de fotos de tickets
  /// (`data/almacenamiento/almacen_fotos.dart`) — todo lo que "eliminar
  /// cuenta" promete que desaparece. Ignora los archivos que ya no
  /// existen: borrar es idempotente, no un error si ya no había nada.
  Future<void> borrarTodo() async {
    for (final archivo in archivos.values) {
      await archivo.borrar();
    }
    await estadoNube.borrar();
    if (!admiteFotos) return;
    final tickets = Directory('${directorio.path}/tickets');
    if (await tickets.exists()) await tickets.delete(recursive: true);
  }
}
