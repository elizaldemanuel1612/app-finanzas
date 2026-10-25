import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/meta_apartado.dart';

/// Lo que queda después de reajustar al ingreso nuevo: las categorías ya
/// reescaladas (las archivadas regresan igual) y la meta.
final class ReajusteIngreso {
  final List<Categoria> categorias;
  final MetaApartado? meta;

  const ReajusteIngreso({required this.categorias, required this.meta});
}

/// Reescala los presupuestos en la misma proporción que cambió el ingreso
/// base (addendum-v3-ajuste-y-ux.md §2.5.1):
///
/// `Nuevo_c = Presupuesto_c × IngresoNuevo ÷ IngresoAnterior`
///
/// redondeado hacia abajo al peso entero, con mínimo de $1 para que ningún
/// presupuesto quede en cero. Aplica a fijas y variables activas; las
/// archivadas no se tocan. La meta solo se reescala si es por monto — la
/// meta por porcentaje ya es relativa al ingreso.
///
/// Todo con enteros (centavos): nada pasa por `double`.
ReajusteIngreso reajustarAlNuevoIngreso({
  required List<Categoria> categorias,
  required MetaApartado? meta,
  required Dinero ingresoAnterior,
  required Dinero ingresoNuevo,
}) {
  if (!ingresoAnterior.esPositivo || !ingresoNuevo.esPositivo || ingresoAnterior == ingresoNuevo) {
    return ReajusteIngreso(categorias: categorias, meta: meta);
  }

  Dinero escalar(Dinero monto) {
    final centavos = monto.centavos * ingresoNuevo.centavos ~/ ingresoAnterior.centavos;
    final pesosEnteros = centavos ~/ 100;
    return Dinero.pesos(pesosEnteros < 1 ? 1 : pesosEnteros);
  }

  final reescaladas = [
    for (final c in categorias)
      if (!c.activa)
        c
      else
        switch (c) {
          CategoriaFija f => CategoriaFija(
              id: f.id,
              nombre: f.nombre,
              emoji: f.emoji,
              activa: f.activa,
              esNecesaria: f.esNecesaria,
              montoFijoCentavos: escalar(f.montoFijoCentavos),
              diaDelCiclo: f.diaDelCiclo,
            ),
          CategoriaVariable v => CategoriaVariable(
              id: v.id,
              nombre: v.nombre,
              emoji: v.emoji,
              activa: v.activa,
              esNecesaria: v.esNecesaria,
              presupuestoMensualCentavos: escalar(v.presupuestoMensualCentavos),
            ),
        },
  ];

  final metaNueva = switch (meta) {
    MetaPorMonto(:final monto) => MetaPorMonto(escalar(monto)),
    _ => meta,
  };

  return ReajusteIngreso(categorias: reescaladas, meta: metaNueva);
}

/// Suma de lo presupuestado en las categorías activas (fijas + variables),
/// para enseñarle al usuario el antes y después del reajuste.
Dinero totalPresupuestado(List<Categoria> categorias) => Dinero.suma([
      for (final c in categorias)
        if (c.activa)
          switch (c) {
            CategoriaFija f => f.montoFijoCentavos,
            CategoriaVariable v => v.presupuestoMensualCentavos,
          },
    ]);
