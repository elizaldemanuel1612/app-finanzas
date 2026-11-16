import '../data/ia/clientes_ia.dart';
import '../data/ia/servicio_ia.dart';
import '../data/voz/registro_por_voz.dart';
import '../domain/voz/interpretar_gasto.dart';
import 'ia_apple.dart';

/// La IA que ayuda a entender lo que se dicta (spec §5.6.3): el complemento
/// activo; si no hay ninguno y el iPhone tiene Apple Intelligence, esa —
/// corre dentro del teléfono, la frase no sale de él. `null` si no hay.
///
/// Solo propone la categoría; `completarConIA` la valida.
Future<CategoriaPorIA?> iaParaDictado(ServicioIA servicio) async {
  ClienteIA? cliente;
  try {
    cliente = await servicio.clienteActivo();
  } catch (_) {
    cliente = null;
  }
  if (cliente == null && servicio.apple != null && await IAApple.estado() == EstadoApple.disponible) {
    cliente = servicio.apple;
  }
  final elegido = cliente;
  if (elegido == null) return null;
  return (frase, ctx) async {
    if (elegido is IAApple) {
      return elegido.categoriaDeGasto(
        instrucciones: instruccionesIAGasto,
        mensaje: mensajeIAGasto(frase, ctx),
        opciones: opcionesIAGasto(ctx),
      );
    }
    try {
      return await elegido.responder(
        sistema: instruccionesIAGasto,
        mensajes: [MensajeIA.usuario(mensajeIAGasto(frase, ctx))],
        maxTokens: 30,
      );
    } catch (_) {
      return null;
    }
  };
}
