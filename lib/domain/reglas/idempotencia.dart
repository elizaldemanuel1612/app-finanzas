import '../../core/result.dart';

/// Regla no negociable #2 (paquete-construccion-final.md §6): toda captura
/// lleva un `clientId` generado en el dispositivo. El servidor ignora
/// duplicados — esto es lo que hace que un doble tap, o un dictado
/// procesado dos veces, produzca un solo movimiento.
Resultado<void> validarClientId(String clientId) {
  if (clientId.trim().isEmpty) {
    return const Falla('clientId no puede estar vacío.');
  }
  if (clientId.length < 8) {
    return const Falla(
      'clientId demasiado corto para ser único entre dispositivos.',
    );
  }
  return const Exito(null);
}

/// `true` si `clientId` ya existe en `clientIdsExistentes` — el servidor
/// debe ignorar la escritura en ese caso, no crear un segundo movimiento.
bool esDuplicado(String clientId, Iterable<String> clientIdsExistentes) =>
    clientIdsExistentes.contains(clientId);
