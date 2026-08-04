/// Una entrada de la subcolección `auditoria/` de un movimiento (regla no
/// negociable #4): toda edición de monto o categoría queda registrada como
/// valor anterior → nuevo, cuándo, y desde qué dispositivo.
final class CambioAuditoria {
  final String campo;
  final String valorAnterior;
  final String valorNuevo;
  final DateTime cuando;
  final String dispositivo;

  const CambioAuditoria({
    required this.campo,
    required this.valorAnterior,
    required this.valorNuevo,
    required this.cuando,
    required this.dispositivo,
  });

  @override
  bool operator ==(Object other) =>
      other is CambioAuditoria &&
      other.campo == campo &&
      other.valorAnterior == valorAnterior &&
      other.valorNuevo == valorNuevo &&
      other.cuando == cuando &&
      other.dispositivo == dispositivo;

  @override
  int get hashCode =>
      Object.hash(campo, valorAnterior, valorNuevo, cuando, dispositivo);

  @override
  String toString() =>
      '$campo: $valorAnterior → $valorNuevo ($cuando, $dispositivo)';
}
