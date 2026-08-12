import '../../core/money.dart';
import '../modelos/ingreso_extra.dart';

/// Desglose de lo que entró a un ciclo: el base de [Perfil.ingresoBaseMensual]
/// más los extras activos, separados por [DestinoExtra] — separados porque
/// [calcularMetaDelCiclo] solo sube la meta con el de `apartado`, nunca con
/// el de `gasto`.
final class IngresosDelCiclo {
  final Dinero base;
  final Dinero extraAApartado;
  final Dinero extraAGasto;

  const IngresosDelCiclo({
    required this.base,
    required this.extraAApartado,
    required this.extraAGasto,
  });

  const IngresosDelCiclo.soloBase(Dinero base)
      : this(base: base, extraAApartado: const Dinero.cero(), extraAGasto: const Dinero.cero());

  Dinero get extraTotal => extraAApartado + extraAGasto;

  Dinero get total => base + extraTotal;

  bool get huboExtra => extraTotal.esPositivo;
}

/// Suma los ingresos extra de [cicloId], separados por destino. Filtra aquí
/// mismo por ciclo — no confía en que [extras] ya venga filtrado — e
/// ignora los anulados (regla no negociable #3: un ingreso anulado deja de
/// mover métricas, pero sigue existiendo en el archivo).
IngresosDelCiclo calcularIngresosDelCiclo({
  required Dinero ingresoBase,
  required String cicloId,
  required Iterable<IngresoExtra> extras,
}) {
  final activosDelCiclo = extras.where(
    (e) => e.cicloId == cicloId && e.estado == EstadoIngreso.activo,
  );

  final extraAApartado = Dinero.suma(
    activosDelCiclo.where((e) => e.destino == DestinoExtra.apartado).map((e) => e.monto),
  );
  final extraAGasto = Dinero.suma(
    activosDelCiclo.where((e) => e.destino == DestinoExtra.gasto).map((e) => e.monto),
  );

  return IngresosDelCiclo(
    base: ingresoBase,
    extraAApartado: extraAApartado,
    extraAGasto: extraAGasto,
  );
}

/// La meta del ciclo sube con el extra que el usuario destinó a apartar,
/// nunca con el que ya declaró que se iba a gastar — al revés subiría la
/// meta por un ingreso que el usuario dijo explícitamente que no iba a
/// ahorrar.
Dinero calcularMetaDelCiclo({
  required Dinero metaBase,
  required IngresosDelCiclo ingresos,
}) =>
    metaBase + ingresos.extraAApartado;
