import 'package:flutter/material.dart';

import '../../data/repositorios/categoria_repositorio.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../data/repositorios/movimiento_repositorio.dart';
import '../../data/repositorios/reglas_aprendidas_repositorio.dart';
import '../../domain/clasificacion/regla_aprendida.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/presupuesto/categorias.dart';
import '../../domain/presupuesto/eliminacion_categoria.dart';
import '../comun/tema.dart';
import 'pantalla_reasignar_movimientos.dart';

enum _AccionSoloDesactivar { archivar, reasignar }

/// Único flujo de eliminación de categoría, compartido entre el botón de
/// basurero de la pantalla de edición y el swipe de la lista de
/// categorías — evita duplicar la carga de datos, el cálculo del efecto y
/// los diálogos entre los dos sitios que ofrecen "eliminar".
///
/// Carga movimientos + reglas → evalúa el efecto → muestra el diálogo que
/// corresponde **con las cifras exactas** (regla no negociable #20) →
/// ejecuta → regresa si hubo un cambio que el llamador deba refrescar.
Future<bool> confirmarYEliminarCategoria(
  BuildContext context, {
  required Categoria categoria,
  required CategoriaRepositorio categoriaRepositorio,
  required MovimientoRepositorio movimientoRepositorio,
  required ReglasAprendidasRepositorio reglasAprendidasRepositorio,
  required CicloRepositorio cicloRepositorio,
}) async {
  final movimientos = await movimientoRepositorio.listarPorCategoria(categoria.id);
  final reglas = await reglasAprendidasRepositorio.listarTodas();
  final efecto = evaluarEliminacionCategoria(
    categoria: categoria,
    movimientosDeLaCategoria: movimientos,
    reglasAprendidas: reglas,
  );

  if (!context.mounted) return false;

  switch (efecto) {
    case SoloPuedeDesactivarse():
      final categoriasActivas = await categoriaRepositorio.listarActivas();
      final hayOtroDestino = categoriasActivas.any((c) => c.id != categoria.id);

      if (!context.mounted) return false;
      final accion = await showDialog<_AccionSoloDesactivar>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            '${categoria.nombre} ya tiene ${efecto.movimientos} movimiento(s) '
            'por ${efecto.totalHistorico.formateado()}. Eliminarla los dejaría '
            'sin categoría. Puedes archivarla (conserva su historial, deja '
            'de aparecer para capturar) o reasignar cada movimiento a otra '
            'categoría para poder borrarla de verdad.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_AccionSoloDesactivar.archivar),
              child: const Text('Archivar y desactivar'),
            ),
            TextButton(
              onPressed: hayOtroDestino
                  ? () => Navigator.of(context)
                      .pop(_AccionSoloDesactivar.reasignar)
                  : null,
              child: const Text('Reasignar movimientos'),
            ),
          ],
        ),
      );

      switch (accion) {
        case _AccionSoloDesactivar.archivar:
          await categoriaRepositorio.guardar(conActiva(categoria, false));
          return true;
        case _AccionSoloDesactivar.reasignar:
          if (!context.mounted) return false;
          final huboReasignacion = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PantallaReasignarMovimientos(
                categoria: categoria,
                categoriaRepositorio: categoriaRepositorio,
                movimientoRepositorio: movimientoRepositorio,
                cicloRepositorio: cicloRepositorio,
              ),
            ),
          );
          if (huboReasignacion != true) return false;
          if (!context.mounted) return false;
          return confirmarYEliminarCategoria(
            context,
            categoria: categoria,
            categoriaRepositorio: categoriaRepositorio,
            movimientoRepositorio: movimientoRepositorio,
            reglasAprendidasRepositorio: reglasAprendidasRepositorio,
            cicloRepositorio: cicloRepositorio,
          );
        case null:
          return false;
      }

    case PuedeEliminarse():
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar esta categoría?'),
          content: Text(
            '${categoria.nombre} no tiene movimientos. Se liberan '
            '${efecto.presupuestoLiberado.formateado()} de tu presupuesto '
            '${efecto.reglasAprendidasQueSePierden > 0 ? 'y se borran ${efecto.reglasAprendidasQueSePierden} '
                    'regla(s) que aprendimos para clasificarla' : ''}. '
            'Esto no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar', style: TextStyle(color: ColoresApp.coralTexto)),
            ),
          ],
        ),
      );
      if (confirmado != true) return false;
      await categoriaRepositorio.eliminar(categoria.id);
      if (efecto.reglasAprendidasQueSePierden > 0) {
        final reglasActualizadas =
            quitarReglasDeCategoria(reglas: reglas, categoriaId: categoria.id);
        await reglasAprendidasRepositorio.guardarTodas(reglasActualizadas);
      }
      return true;
  }
}
