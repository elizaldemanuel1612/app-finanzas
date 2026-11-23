import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import 'estado_ritmo.dart';
import 'rollup.dart';

/// Cómo ordenar las categorías en Inicio, siempre de mayor a menor
/// (spec-app-finanzas-v2.md §5.6).
enum OrdenCategorias {
  /// Qué tanto del presupuesto ya se consumió.
  porcentajeUsado,

  /// Cuánto dinero se ha gastado.
  dineroGastado,
}

/// Copia ordenada de [categorias] según [orden]. Lo gastado sin presupuesto
/// contra qué medir va primero en [OrdenCategorias.porcentajeUsado]: es lo
/// más pasado de todo. Los empates se resuelven por el otro criterio y luego
/// por nombre, para que la lista no cambie de lugar entre recargas.
List<T> ordenarCategorias<T extends Categoria>(
  List<T> categorias,
  Map<String, Rollup> rollups,
  OrdenCategorias orden,
) {
  int gastado(T c) => rollups[c.id]?.totalCentavos.centavos ?? 0;
  double usado(T c) {
    final porcentaje = rollups[c.id]?.porcentajeUsado;
    if (porcentaje != null) return porcentaje;
    // Sin presupuesto (spec §7.3.6) no hay porcentaje: al final, sin juicio.
    return -1;
  }

  int porUsado(T a, T b) => usado(b).compareTo(usado(a));
  int porGastado(T a, T b) => gastado(b).compareTo(gastado(a));
  final primero = orden == OrdenCategorias.porcentajeUsado ? porUsado : porGastado;
  final segundo = orden == OrdenCategorias.porcentajeUsado ? porGastado : porUsado;

  return [...categorias]
    ..sort((a, b) {
      final uno = primero(a, b);
      if (uno != 0) return uno;
      final dos = segundo(a, b);
      return dos != 0 ? dos : a.nombre.compareTo(b.nombre);
    });
}

/// Orden del presupuesto en Inicio (`docs/rediseno/plan-rediseno.md`,
/// Etapa 2): **lo que necesita atención va primero** — las que se pasaron
/// (de mayor a menor porcentaje), luego las que van rápido ([tonoDeRitmo],
/// el mismo veredicto del chip y la barra) y al final las que van bien, de
/// mayor a menor porcentaje usado. Las que no tienen presupuesto (spec
/// §7.3.6) van al final, de mayor a menor gasto. Empates, por nombre.
List<T> ordenarPorAtencion<T extends Categoria>(
  List<T> categorias,
  Map<String, Rollup> rollups, {
  required double avanceCiclo,
}) {
  double usado(T c) => rollups[c.id]?.porcentajeUsado ?? 0;
  int gastado(T c) => rollups[c.id]?.totalCentavos.centavos ?? 0;
  int prioridad(T c) => rollups[c.id] != null && rollups[c.id]!.porcentajeUsado == null
      ? 3
      : switch (tonoDeRitmo(porcentajeUsado: rollups[c.id]?.porcentajeUsado, avanceCiclo: avanceCiclo)) {
        TonoRitmo.tePasaste => 0,
        TonoRitmo.vasRapido => 1,
        TonoRitmo.vasBien => 2,
      };
  return [...categorias]
    ..sort((a, b) {
      final p = prioridad(a).compareTo(prioridad(b));
      if (p != 0) return p;
      final u = usado(b).compareTo(usado(a));
      if (u != 0) return u;
      final g = gastado(b).compareTo(gastado(a));
      return g != 0 ? g : a.nombre.compareTo(b.nombre);
    });
}

/// Orden para elegir categoría al registrar un gasto (spec-app-finanzas-v2.md
/// §5.6): de la más usada a la menos usada, contando los gastos activos de
/// [movimientos]. Así la lista aprende sola; sin historial, o en empate, va
/// de mayor a menor presupuesto (el monto, en las fijas) y luego por nombre.
List<Categoria> ordenarPorUso(List<Categoria> categorias, List<Movimiento> movimientos) {
  final usos = <String, int>{};
  for (final m in movimientos) {
    if (m.estado == EstadoMovimiento.activo) usos[m.categoriaId] = (usos[m.categoriaId] ?? 0) + 1;
  }
  int presupuesto(Categoria c) => switch (c) {
        CategoriaFija f => f.montoFijoCentavos.centavos,
        CategoriaVariable v => v.presupuestoMensualCentavos.centavos,
      };

  return [...categorias]
    ..sort((a, b) {
      final porUso = (usos[b.id] ?? 0).compareTo(usos[a.id] ?? 0);
      if (porUso != 0) return porUso;
      final porPresupuesto = presupuesto(b).compareTo(presupuesto(a));
      return porPresupuesto != 0 ? porPresupuesto : a.nombre.compareTo(b.nombre);
    });
}

/// Cómo acomoda el usuario el presupuesto de Inicio (spec-app-finanzas-v2.md
/// §5.6.4). Se guarda por nombre en el perfil.
enum OrdenPresupuesto {
  /// Lo que necesita atención primero ([ordenarPorAtencion]); el de fábrica.
  atencion,

  /// El que el usuario acomodó arrastrando (`Perfil.ordenPropio`).
  propio,

  /// De mayor a menor gasto del ciclo.
  masGastado,

  /// A–Z, sin que estorben acentos ni mayúsculas.
  nombre;

  /// El guardado en el perfil; uno desconocido (de una versión futura) o
  /// ausente cae en [atencion].
  static OrdenPresupuesto deNombre(String? nombre) =>
      values.where((o) => o.name == nombre).firstOrNull ?? atencion;
}

/// El presupuesto de Inicio según [orden] (spec §5.6.4). En
/// [OrdenPresupuesto.propio], [ordenPropio] son los ids en el orden que el
/// usuario eligió: lo que no está ahí (una categoría nueva) va al final por
/// nombre, y un id que ya no existe se ignora.
List<T> ordenarPresupuesto<T extends Categoria>(
  List<T> categorias,
  Map<String, Rollup> rollups, {
  required OrdenPresupuesto orden,
  required double avanceCiclo,
  List<String> ordenPropio = const [],
}) {
  int porNombre(T a, T b) {
    final n = _paraOrdenar(a.nombre).compareTo(_paraOrdenar(b.nombre));
    return n != 0 ? n : a.id.compareTo(b.id);
  }

  int gastado(T c) => rollups[c.id]?.totalCentavos.centavos ?? 0;
  switch (orden) {
    case OrdenPresupuesto.atencion:
      return ordenarPorAtencion(categorias, rollups, avanceCiclo: avanceCiclo);
    case OrdenPresupuesto.nombre:
      return [...categorias]..sort(porNombre);
    case OrdenPresupuesto.masGastado:
      return [...categorias]
        ..sort((a, b) {
          final g = gastado(b).compareTo(gastado(a));
          return g != 0 ? g : porNombre(a, b);
        });
    case OrdenPresupuesto.propio:
      final lugar = {for (final (i, id) in ordenPropio.indexed) id: i};
      return [...categorias]
        ..sort((a, b) {
          final la = lugar[a.id];
          final lb = lugar[b.id];
          if (la != null && lb != null) return la.compareTo(lb);
          if (la != null) return -1;
          if (lb != null) return 1;
          return porNombre(a, b);
        });
  }
}

String _paraOrdenar(String texto) {
  const con = 'áéíóúüñ';
  const sin = 'aeiouun';
  final bajo = texto.toLowerCase();
  final salida = StringBuffer();
  for (final r in bajo.split('')) {
    final i = con.indexOf(r);
    salida.write(i >= 0 ? sin[i] : r);
  }
  return salida.toString();
}
