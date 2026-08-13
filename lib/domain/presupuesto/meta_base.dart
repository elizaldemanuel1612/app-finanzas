import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';
import '../modelos/perfil.dart';
import 'reparto.dart';

/// Meta de apartado del ciclo antes de sumar ingresos extra (ver
/// `calcularMetaDelCiclo` en `ciclo_de_vida/ingresos_ciclo.dart`): la
/// declarada explícitamente en [Perfil.metaApartado] si existe, o la
/// derivada de [ResultadoReparto.sinAsignar] si no — mismo criterio que
/// usaban, duplicado, `PantallaCierreCiclo` y `PantallaCiclosAnteriores`
/// antes de que existiera este punto único.
///
/// `Dinero.cero()` si el reparto falla (fijas que no caben en el ingreso):
/// no tiene sentido proponer una meta sobre un presupuesto que ya sabemos
/// que no cuadra.
Dinero calcularMetaBase({
  required Perfil perfil,
  required List<Categoria> categorias,
}) {
  final metaDeclarada = perfil.metaApartado;
  if (metaDeclarada != null) return metaDeclarada.montoPara(perfil.ingresoBaseMensual);

  final reparto = calcularReparto(
    ingresoDisponible: perfil.ingresoBaseMensual,
    fijas: categorias.whereType<CategoriaFija>().toList(),
    variables: categorias.whereType<CategoriaVariable>().toList(),
  );
  return switch (reparto) {
    Exito(:final valor) => valor.sinAsignar,
    Falla() => const Dinero.cero(),
  };
}
