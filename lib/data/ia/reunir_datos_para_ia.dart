import '../../core/money.dart';
import '../../domain/ciclo_de_vida/ingresos_ciclo.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/ia/datos_para_ia.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/cuenta.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/objetivos/progreso_objetivos.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/meta_base.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../repositorios/local/almacen_local.dart';

/// Reúne lo que el asistente puede saber de los números del usuario (spec
/// §6.5, uso 4), con los mismos cálculos de Inicio y Patrimonio. `null` si
/// la cuenta aún no está configurada.
Future<DatosParaIA?> reunirDatosParaIA(AlmacenLocal almacen, DateTime ahora) async {
  final perfil = await almacen.perfil.obtener();
  if (perfil == null) return null;
  final calculadora = perfil.calculadoraCiclo;
  final ciclo = calculadora.calcularPara(ahora);
  final categorias = await almacen.categorias.listarActivas();
  final movimientos = await almacen.movimientos.listarTodos();
  final ajustes = await almacen.ajustesPresupuestoCiclo.listarPorCiclo(ciclo.id);
  final efectivas = presupuestosEfectivosParaCiclo(base: categorias, ajustesDelCiclo: ajustes);
  final rollups = {
    for (final r in calcularRollups(
      movimientos: [for (final m in movimientos) if (m.cicloId == ciclo.id) m],
      categorias: efectivas,
      cicloId: ciclo.id,
      ahora: ahora,
    ))
      r.categoriaId: r,
  };
  final extras = await almacen.ingresosExtra.listarPorCiclo(ciclo.id);
  final ingresos = calcularIngresosDelCiclo(ingresoBase: perfil.ingresoBaseMensual, cicloId: ciclo.id, extras: extras);

  // El ciclo pasado: el del día anterior al inicio de este.
  final pasado = calculadora.calcularPara(ciclo.fechaInicio.subtract(const Duration(days: 1)));
  final delPasado = [
    for (final m in movimientos)
      if (m.cicloId == pasado.id && m.estado == EstadoMovimiento.activo) m.monto,
  ];

  final cuentas = await almacen.cuentas.listarTodas();
  final abonos = await almacen.movimientosCuenta.listarTodos();
  final conSaldo = <CuentaParaIA>[];
  final saldoPorCuenta = <String, Dinero>{};
  for (final c in cuentas.where((c) => c.activa)) {
    final saldo = saldoDe(c, movimientos, abonos);
    if (saldo == null) continue;
    saldoPorCuenta[c.id] = saldo;
    final debe = c.tipo == TipoCuenta.credito && saldo.esNegativo;
    conSaldo.add((nombre: c.nombre, saldo: saldo, debe: debe));
  }
  final objetivos = calcularProgresoObjetivos(
    objetivos: [for (final o in await almacen.objetivos.listarTodos()) if (o.activo) o],
    saldoPorCuenta: saldoPorCuenta,
    hoy: ahora,
    calculadora: calculadora,
  );

  return DatosParaIA(
    hoy: ahora,
    ciclo: ciclo,
    ingreso: ingresos.total,
    meta: calcularMetaDelCiclo(metaBase: calcularMetaBase(perfil: perfil, categorias: categorias), ingresos: ingresos),
    categorias: [
      for (final c in categorias)
        (
          nombre: c.nombre,
          gastado: rollups[c.id]?.totalCentavos ?? const Dinero.cero(),
          presupuesto: rollups[c.id]?.presupuestoCentavos ??
              switch (c) {
                CategoriaVariable() => c.presupuestoMensualCentavos,
                CategoriaFija() => c.montoFijoCentavos,
              },
          fija: c is CategoriaFija,
        ),
    ],
    gastadoCicloPasado: delPasado.isEmpty ? null : Dinero.suma(delPasado),
    cuentas: conSaldo,
    patrimonio: conSaldo.isEmpty ? null : calcularPatrimonio(cuentas, movimientos, abonos).total,
    objetivos: [for (final p in objetivos) (nombre: p.objetivo.nombre, meta: p.objetivo.monto, llevas: p.llevas)],
  );
}
