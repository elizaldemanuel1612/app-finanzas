import '../modelos/categoria.dart';
import '../modelos/snapshot_ciclo.dart';

/// Para ver en Análisis un ciclo cerrado "como quedó" (spec §5.7): cada
/// variable que aparece en la fotografía del cierre toma el presupuesto que
/// tenía ese día, aunque después se haya cambiado o archivado. Lo demás se
/// queda igual. Sin [snapshot] (ciclo nunca cerrado) regresa [categorias].
List<Categoria> presupuestosDelCierre({
  required List<Categoria> categorias,
  required SnapshotCiclo? snapshot,
}) {
  if (snapshot == null) return categorias;
  final delCierre = {
    for (final r in snapshot.renglones)
      if (r.presupuestoCentavos.esPositivo) r.categoriaId: r.presupuestoCentavos,
  };
  return [
    for (final c in categorias)
      if (c is CategoriaVariable && delCierre.containsKey(c.id))
        CategoriaVariable(
          id: c.id,
          nombre: c.nombre,
          emoji: c.emoji,
          activa: true,
          esNecesaria: c.esNecesaria,
          presupuestoMensualCentavos: delCierre[c.id]!,
        )
      else
        c,
  ];
}
