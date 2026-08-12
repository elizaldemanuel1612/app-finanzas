import 'dart:io';

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

  final Directory directorio;

  final CategoriaRepositorioArchivo categorias;
  final MovimientoRepositorioArchivo movimientos;
  final PerfilRepositorioArchivo perfil;
  final ReglasAprendidasRepositorioArchivo reglasAprendidas;
  final CicloRepositorioArchivo ciclos;
  final IngresoExtraRepositorioArchivo ingresosExtra;
  final AjustePresupuestoCicloRepositorioArchivo ajustesPresupuestoCiclo;

  AlmacenLocal(this.directorio)
      : categorias = CategoriaRepositorioArchivo(File('${directorio.path}/categorias.json')),
        movimientos = MovimientoRepositorioArchivo(File('${directorio.path}/movimientos.json')),
        perfil = PerfilRepositorioArchivo(File('${directorio.path}/perfil.json')),
        reglasAprendidas = ReglasAprendidasRepositorioArchivo(
          File('${directorio.path}/reglas_aprendidas.json'),
        ),
        ciclos = CicloRepositorioArchivo(File('${directorio.path}/ciclos.json')),
        ingresosExtra =
            IngresoExtraRepositorioArchivo(File('${directorio.path}/ingresos.json')),
        ajustesPresupuestoCiclo = AjustePresupuestoCicloRepositorioArchivo(
          File('${directorio.path}/ajustes_presupuesto_ciclo.json'),
        );

  /// Borra los 7 JSON más el directorio de fotos de tickets
  /// (`data/almacenamiento/almacen_fotos.dart`) — todo lo que "eliminar
  /// cuenta" promete que desaparece. Ignora los archivos que ya no
  /// existen: borrar es idempotente, no un error si ya no había nada.
  Future<void> borrarTodo() async {
    for (final nombre in nombresDeArchivo) {
      final archivo = File('${directorio.path}/$nombre');
      if (await archivo.exists()) await archivo.delete();
    }
    final tickets = Directory('${directorio.path}/tickets');
    if (await tickets.exists()) await tickets.delete(recursive: true);
  }
}
