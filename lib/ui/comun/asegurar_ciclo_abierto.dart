import 'package:flutter/material.dart';

import '../../core/result.dart';
import '../../data/repositorios/ciclo_repositorio.dart';
import '../../domain/ciclo_de_vida/cierre_ciclo.dart';
import '../../domain/modelos/ciclo_guardado.dart';
import '../../domain/reglas/ciclo_inmutable.dart';

/// Guarda de entrada para editar, guardar o anular un movimiento: si su
/// ciclo ya está cerrado (regla no negociable #6), bloquea y ofrece
/// reabrirlo — el caso de borde de app-finanzas-eliminar-reembolsos-v10
/// .html §3. El registrar un ajuste en el ciclo actual (la otra salida del
/// prototipo) pertenece al entregable E; por ahora la única salida es
/// "reabrir" (regla no negociable #22: toda pantalla que muestra un
/// problema ofrece una salida concreta).
///
/// Un `cicloId` sin [CicloGuardado] nunca se cerró — sigue abierto por
/// definición, y esta función regresa `true` de inmediato.
///
/// [esCaptura] cambia el copy: el texto por omisión habla de "editarlo o
/// eliminarlo" (un movimiento que ya existe), pero al capturar un gasto con
/// una fecha que cae en un ciclo cerrado todavía no hay movimiento que
/// editar — el mensaje debe hablar del día, no del gasto.
Future<bool> asegurarCicloAbierto(
  BuildContext context, {
  required String cicloId,
  required CicloRepositorio cicloRepositorio,
  bool esCaptura = false,
}) async {
  final guardado = await cicloRepositorio.buscarPorId(cicloId);
  if (guardado == null) return true;
  if (validarPuedeModificarse(guardado.ciclo).esExito) return true;

  if (!context.mounted) return false;
  final reabrir = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(esCaptura
          ? 'Ese día pertenece a un ciclo que ya cerraste'
          : 'Este movimiento es de un ciclo cerrado'),
      content: Text(esCaptura
          ? '${guardado.ciclo.etiqueta} ya se cerró. Para registrar un '
              'gasto ahí, primero hay que reabrir ese ciclo.'
          : '${guardado.ciclo.etiqueta} ya se cerró. Sus cifras ya son '
              'históricas. Para editarlo o eliminarlo, primero hay que '
              'reabrir ese ciclo.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Reabrir ${guardado.ciclo.etiqueta}'),
        ),
      ],
    ),
  );
  if (reabrir != true) return false;

  final resultado = reabrirCiclo(guardado);
  if (resultado case Falla()) return false;
  await cicloRepositorio.guardar((resultado as Exito<CicloGuardado>).valor);
  return true;
}
