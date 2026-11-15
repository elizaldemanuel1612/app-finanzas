import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../modelos/categoria.dart';
import '../modelos/estado_movimiento.dart';
import '../modelos/movimiento.dart';
import '../presupuesto/cobertura_excesos.dart';
import 'historico_desde_movimientos.dart';

/// El estado de cada categoría variable del ciclo con su pronóstico MPC
/// (`docs/modelo-pronostico-ciclo.md`): la fuente única de "cómo cierra"
/// para Inicio, Análisis y el detalle de categoría
/// (`docs/rediseno/plan-rediseno.md`, Etapa 0).
///
/// - [categorias]: con los presupuestos **efectivos** del ciclo (ajustes
///   aplicados). Entran las variables activas y las archivadas que tengan
///   gasto en el ciclo.
/// - [hoy] se inyecta: nada aquí lee el reloj.
List<EstadoVariable> estadosDeVariables({
  required List<Categoria> categorias,
  required List<Movimiento> movimientos,
  required Ciclo ciclo,
  required DateTime hoy,
}) {
  final gastado = <String, int>{};
  for (final m in movimientos) {
    if (m.cicloId != ciclo.id || m.estado != EstadoMovimiento.activo) continue;
    gastado[m.categoriaId] = (gastado[m.categoriaId] ?? 0) + m.monto.centavos;
  }
  return [
    for (final c in categorias.whereType<CategoriaVariable>())
      if (c.activa || gastado.containsKey(c.id))
        _estado(c, Dinero(gastado[c.id] ?? 0), movimientos, ciclo, hoy),
  ];
}

EstadoVariable _estado(CategoriaVariable c, Dinero gastado, List<Movimiento> todos, Ciclo ciclo, DateTime hoy) {
  final p50 = pronosticoDeCategoria(categoria: c, todos: todos, ciclo: ciclo, hoy: hoy).pronosticoP50;
  return EstadoVariable(categoria: c, gastado: gastado, proyeccion: p50 < gastado ? gastado : p50);
}

/// Cierre estimado de todas las variables: la suma de sus pronósticos.
Dinero proyeccionTotal(List<EstadoVariable> estados) => Dinero.suma(estados.map((e) => e.proyeccion));
