import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../modelos/perfil.dart';
import 'ajuste_presupuesto_ciclo.dart';

// Trasladar lo que sobró al ciclo siguiente (addendum-v3-ajuste-y-ux.md
// §2.5.2, 2026-11-15): opcional, categoría por categoría, solo variables.

/// Lo que le sobró a una variable en el ciclo anterior.
final class SobranteCategoria {
  final CategoriaVariable categoria;
  final Dinero sobrante;
  const SobranteCategoria({required this.categoria, required this.sobrante});
}

/// Lo mínimo que se ofrece trasladar: con menos, la hoja diría
/// "Sobraron \$0" (los montos se muestran en pesos enteros).
const sobranteMinimo = Dinero.pesos(1);

/// Lo que le sobró a cada variable activa en [cicloId] (presupuesto con los
/// ajustes de ese ciclo menos lo gastado), de mayor a menor; solo lo que
/// llega a [sobranteMinimo]. Vacío si en ese
/// ciclo no hubo gastos: sin uso, todo "sobra" y no tiene sentido ofrecerlo.
List<SobranteCategoria> sobrantesDelCiclo({
  required List<Categoria> categorias,
  required List<AjustePresupuestoCiclo> ajustesDelCiclo,
  required List<Movimiento> movimientos,
  required String cicloId,
}) {
  final gastado = <String, int>{};
  for (final m in movimientos) {
    if (m.cicloId != cicloId || m.estado != EstadoMovimiento.activo) continue;
    gastado[m.categoriaId] = (gastado[m.categoriaId] ?? 0) + m.monto.centavos;
  }
  if (gastado.isEmpty) return const [];
  final efectivas = presupuestosEfectivosParaCiclo(base: categorias, ajustesDelCiclo: ajustesDelCiclo);
  return [
    for (final c in efectivas.whereType<CategoriaVariable>())
      if (c.activa && c.presupuestoMensualCentavos.centavos - (gastado[c.id] ?? 0) >= sobranteMinimo.centavos)
        SobranteCategoria(
          categoria: c,
          sobrante: Dinero(c.presupuestoMensualCentavos.centavos - (gastado[c.id] ?? 0)),
        ),
  ]..sort((a, b) => b.sobrante.centavos.compareTo(a.sobrante.centavos));
}

/// Si hay que preguntar en [cicloActualId]: hay sobrantes y aún no se
/// decidió en este ciclo.
bool debePreguntarTraslado(Perfil perfil, String cicloActualId, List<SobranteCategoria> sobrantes) =>
    sobrantes.isNotEmpty && perfil.cicloTrasladoDecidido != cicloActualId;

/// Las que vienen marcadas: las que el usuario pidió recordar.
Set<String> trasladoPreseleccionado(Perfil perfil, List<SobranteCategoria> sobrantes) => {
      for (final s in sobrantes)
        if (perfil.trasladarSiempre.contains(s.categoria.id)) s.categoria.id,
    };

/// Los ajustes del ciclo nuevo para las elegidas: un delta positivo por
/// categoría, solo para [cicloNuevoId].
List<AjustePresupuestoCiclo> ajustesDeTraslado(
  List<SobranteCategoria> elegidas, {
  required String cicloNuevoId,
  required DateTime ahora,
}) =>
    [
      for (final s in elegidas)
        AjustePresupuestoCiclo(
          cicloId: cicloNuevoId,
          categoriaId: s.categoria.id,
          deltaCentavos: s.sobrante,
          cuando: ahora,
          dispositivo: 'traslado',
        ),
    ];

/// El perfil ya con la decisión: este ciclo queda decidido y, si se pidió
/// recordar, las elegidas vendrán marcadas la próxima vez.
Perfil perfilTrasDecidir(Perfil perfil, String cicloActualId, {Set<String>? recordar}) =>
    perfil.copyWith(cicloTrasladoDecidido: cicloActualId, trasladarSiempre: recordar == null ? null : ([...recordar]..sort()));
