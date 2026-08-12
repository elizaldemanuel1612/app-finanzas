import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';

/// Contrato para persistir ajustes temporales de presupuesto. Append-only
/// a propósito: un [AjustePresupuestoCiclo] no tiene `id` porque no se
/// edita ni se busca individual, solo se acumula.
abstract interface class AjustePresupuestoCicloRepositorio {
  Future<List<AjustePresupuestoCiclo>> listarPorCiclo(String cicloId);

  Future<void> agregarLote(List<AjustePresupuestoCiclo> ajustes);
}
