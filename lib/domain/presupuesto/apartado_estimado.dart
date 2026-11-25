import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../pronostico/pronostico_del_ciclo.dart';

/// Cuánto se apartaría al cierre del ciclo en curso (spec-app-finanzas-v2.md
/// §5.6.1):
///
/// `ingreso − fijas − variablesEstimadas`
///
/// - fijas: lo mayor entre su presupuesto y lo ya pagado (regla #9: no se
///   pronostican, se asumen completas).
/// - variablesEstimadas: lo mayor entre su presupuesto y
///   [proyeccionVariables], el cierre estimado por el MPC
///   (`proyeccionTotal`, `domain/pronostico/pronostico_del_ciclo.dart`): la
///   misma cifra en Inicio y Análisis (`docs/rediseno/plan-rediseno.md`,
///   Etapa 0). No promete lo que todavía no pasa.
///
/// Puede salir negativo: los gastos pasarían lo que entra.
Dinero calcularApartadoEstimado({
  required Dinero ingreso,
  required Dinero presupuestoFijas,
  required Dinero gastadoFijas,
  required Dinero presupuestoVariables,
  required Dinero proyeccionVariables,
}) {
  final fijas = gastadoFijas > presupuestoFijas ? gastadoFijas : presupuestoFijas;
  final variables = proyeccionVariables > presupuestoVariables ? proyeccionVariables : presupuestoVariables;
  return ingreso - fijas - variables;
}

/// [calcularApartadoEstimado] armado desde los datos (2026-11-25): lo que
/// apartarías al cierre de [ciclo] si sigues así, con [categorias] ya con
/// los presupuestos efectivos del ciclo. Es la barra del ciclo en curso en
/// «Cuánto has apartado por ciclo»: antes pintaba ingreso − gastado a hoy,
/// como si ya no se fuera a gastar nada más.
Dinero estimarApartadoAlCierre({
  required List<Categoria> categorias,
  required List<Movimiento> movimientos,
  required Ciclo ciclo,
  required Dinero ingreso,
  required DateTime hoy,
}) {
  var presupuestoFijas = 0;
  var presupuestoVariables = 0;
  for (final c in categorias) {
    if (!c.activa) continue;
    switch (c) {
      case CategoriaFija():
        presupuestoFijas += c.montoFijoCentavos.centavos;
      case CategoriaVariable():
        presupuestoVariables += c.presupuestoMensualCentavos.centavos;
    }
  }
  final fijas = {for (final c in categorias.whereType<CategoriaFija>()) c.id};
  var gastadoFijas = 0;
  for (final m in movimientos) {
    if (m.cicloId == ciclo.id && m.estado == EstadoMovimiento.activo && fijas.contains(m.categoriaId)) {
      gastadoFijas += m.monto.centavos;
    }
  }
  final estados = estadosDeVariables(categorias: categorias, movimientos: movimientos, ciclo: ciclo, hoy: hoy);
  return calcularApartadoEstimado(
    ingreso: ingreso,
    presupuestoFijas: Dinero(presupuestoFijas),
    gastadoFijas: Dinero(gastadoFijas),
    presupuestoVariables: Dinero(presupuestoVariables),
    proyeccionVariables: proyeccionTotal(estados),
  );
}
