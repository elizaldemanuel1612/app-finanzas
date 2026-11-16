import 'dart:convert';

import '../../core/result.dart';
import '../../domain/clasificacion/historial_comercios.dart';
import '../../domain/clasificacion/regla_aprendida.dart';
import '../../domain/cuentas/saldos.dart';
import '../../domain/modelos/categoria.dart';
import '../../domain/modelos/estado_movimiento.dart';
import '../../domain/modelos/movimiento.dart';
import '../../domain/presupuesto/ajuste_presupuesto_ciclo.dart';
import '../../domain/presupuesto/resumen_variables.dart';
import '../../domain/reglas/ciclo_inmutable.dart';
import '../../domain/reglas/creacion_movimiento.dart';
import '../../domain/rollups/calcular_rollups.dart';
import '../../domain/rollups/rollup.dart';
import '../../domain/voz/frases_voz.dart';
import '../../domain/voz/interpretar_gasto.dart';
import '../repositorios/local/almacen_local.dart';

/// La categoría que propone una IA para la frase (spec §5.6.3); `null` si
/// no sabe o falla. Se valida después con `completarConIA`.
typedef CategoriaPorIA = Future<String?> Function(String frase, ContextoDictado ctx);

/// En qué quedó lo que se dijo.
enum EstadoVoz {
  /// Completo: falta solo que la persona confirme.
  listo,

  /// No se entendió el monto (o había dos y no se sabe cuál).
  faltaMonto,

  /// Falta la categoría: se pregunta.
  faltaCategoria,

  /// La frase traía varios gastos.
  variosGastos,

  /// Registrado.
  registrado,

  /// Ese día es de un ciclo cerrado (regla #6): no se guarda.
  cicloCerrado,

  /// No hay sesión en el dispositivo, o la cuenta aún no está configurada.
  sinSesion,

  /// Algo no pasó las reglas del gasto (lo dice el mensaje).
  error,
}

/// Lo que Siri (o la captura) recibe: en qué quedó, qué decir y la
/// propuesta para el siguiente paso.
final class RespuestaVoz {
  final EstadoVoz estado;
  final String mensaje;
  final GastoEntendido? gasto;

  /// El `clientId` con que se guardará: el mismo en cada paso, para que un
  /// reintento no duplique (regla #2).
  final String? clientId;

  /// Lo que muestra el widget después de registrar (§5.6).
  final ResumenVariables? resumen;

  const RespuestaVoz(this.estado, this.mensaje, {this.gasto, this.clientId, this.resumen});

  /// La propuesta como texto, para ir y volver por el canal nativo.
  String? get propuesta => gasto == null ? null : jsonEncode({'gasto': gasto!.toJson(), 'clientId': clientId});

  Map<String, Object?> toMap() => {'estado': estado.name, 'mensaje': mensaje, 'propuesta': propuesta};
}

/// Registrar un gasto con la voz (spec-app-finanzas-v2.md §5.6.3): la
/// misma lógica para Siri (sin abrir la app) y para el dictado. Todo pasa
/// por aquí: entender, preguntar lo que falta, confirmar y guardar con las
/// mismas reglas que la captura.
final class RegistroPorVoz {
  final AlmacenLocal almacen;
  final CategoriaPorIA? ia;
  final DateTime Function() reloj;
  final String Function() nuevoClientId;

  RegistroPorVoz({
    required this.almacen,
    required this.nuevoClientId,
    this.ia,
    DateTime Function()? reloj,
  }) : reloj = reloj ?? DateTime.now;

  /// Categorías activas (las más usadas primero), cuentas para registrar,
  /// reglas e historial: todo lo que hace falta para entender la frase.
  Future<ContextoDictado> contexto() async {
    final categorias = await almacen.categorias.listarActivas();
    final movimientos = await almacen.movimientos.listarTodos();
    final cuentas = await almacen.cuentas.listarTodas();
    final reglas = await almacen.reglasAprendidas.listarTodas();
    final usos = <String, int>{};
    for (final m in movimientos) {
      if (m.estado == EstadoMovimiento.activo) usos[m.categoriaId] = (usos[m.categoriaId] ?? 0) + 1;
    }
    final ordenadas = [...categorias]..sort((a, b) => (usos[b.id] ?? 0).compareTo(usos[a.id] ?? 0));
    return ContextoDictado(
      categorias: ordenadas,
      cuentas: cuentasParaRegistrar(ordenarCuentasPorUso(cuentas, movimientos)),
      cuentaPorOmision: ultimaCuentaUsada(movimientos),
      hoy: reloj(),
      reglas: reglas,
      historialComercios: construirHistorialComercios([
        for (final m in movimientos)
          if (m.estado == EstadoMovimiento.activo) ObservacionComercio(m.descripcion, m.categoriaId),
      ]),
    );
  }

  /// Entiende [frase]: reglas y, si falta la categoría, la IA.
  Future<RespuestaVoz> interpretar(String frase) async {
    if (await almacen.perfil.obtener() == null) return sinSesion;
    final ctx = await contexto();
    var g = interpretarFraseGasto(frase, ctx);
    if (g.categoriaId == null && g.monto != null && !g.variosGastos && ia != null) {
      try {
        g = completarConIA(g, await ia!(frase, ctx), ctx);
      } catch (_) {
        // Sin IA se pregunta la categoría: nada falla.
      }
    }
    return _responder(g, ctx, nuevoClientId());
  }

  /// La persona dijo la categoría que faltaba.
  Future<RespuestaVoz> conCategoria(String propuesta, String dicha) async {
    final (g, clientId) = _leer(propuesta);
    final ctx = await contexto();
    final cat = categoriaPorNombre(dicha, ctx.categorias);
    if (cat == null) {
      return RespuestaVoz(
        EstadoVoz.faltaCategoria,
        'No encontré "${dicha.trim()}". ${preguntaDeCategoria(ctx)}',
        gasto: g,
        clientId: clientId,
      );
    }
    return _responder(g.copyWith(categoriaId: cat.id, descripcion: g.descripcion.isEmpty ? cat.nombre : null), ctx, clientId);
  }

  /// Guarda la propuesta confirmada.
  Future<RespuestaVoz> registrar(String propuesta) async {
    final perfil = await almacen.perfil.obtener();
    if (perfil == null) return sinSesion;
    final (g, clientId) = _leer(propuesta);
    if (!g.completo) return const RespuestaVoz(EstadoVoz.faltaMonto, 'Falta información para registrar el gasto.');
    final categoria = await almacen.categorias.buscarPorId(g.categoriaId!);
    if (categoria == null || !categoria.activa) {
      return const RespuestaVoz(EstadoVoz.faltaCategoria, 'Esa categoría ya no está activa. Dímelo otra vez.');
    }
    final calculadora = perfil.calculadoraCiclo;
    final ciclo = calculadora.calcularPara(g.fecha);
    final guardado = await almacen.ciclos.buscarPorId(ciclo.id);
    if (guardado != null && validarPuedeModificarse(guardado.ciclo) is Falla) {
      return RespuestaVoz(
        EstadoVoz.cicloCerrado,
        '${guardado.ciclo.etiquetaConAnio} ya está cerrado. Para registrar ahí, reábrelo en la app.',
      );
    }
    final cuentas = await almacen.cuentas.listarTodas();
    final cuenta = cuentas.where((c) => c.id == g.cuentaId && c.activa).firstOrNull;
    // Mismo día que dijo; la hora, la de ahora (o mediodía si fue otro día),
    // para que quede en orden con lo demás.
    final ahora = reloj();
    final fecha = DateTime(g.fecha.year, g.fecha.month, g.fecha.day,
        g.fechaDicha ? 12 : ahora.hour, g.fechaDicha ? 0 : ahora.minute, g.fechaDicha ? 0 : ahora.second);
    final creado = crearMovimiento(
      clientId: clientId,
      fecha: fecha,
      calculadoraCiclo: calculadora,
      monto: g.monto!,
      categoriaId: categoria.id,
      medio: cuenta?.tipo.medio ?? MedioPago.tarjeta,
      descripcion: g.descripcion.isEmpty ? categoria.nombre : g.descripcion,
      origenCaptura: OrigenCaptura.voz,
    );
    switch (creado) {
      case Falla(:final mensaje):
        return RespuestaVoz(EstadoVoz.error, 'No pude registrarlo: $mensaje');
      case Exito(:final valor):
        final movimiento = valor.copyWith(cuentaId: cuenta?.id, clasificadoPorIA: g.deIA.contains(DatoGasto.categoria));
        await almacen.movimientos.guardar(movimiento);
        // Como la captura (§6.2): cada registro confirma o corrige la regla.
        final reglas = await almacen.reglasAprendidas.listarTodas();
        final actualizadas = registrarCorreccion(
          reglasActuales: reglas,
          patron: movimiento.descripcion,
          categoriaId: categoria.id,
        );
        if (!identical(actualizadas, reglas)) await almacen.reglasAprendidas.guardarTodas(actualizadas);

        final (rollups, resumen) = await _delCiclo(movimiento.cicloId, perfil.calculadoraCiclo.calcularPara(ahora).id);
        return RespuestaVoz(
          EstadoVoz.registrado,
          registradoEn(categoria, rollups[categoria.id]),
          resumen: resumen,
        );
    }
  }

  /// "¿Cuánto llevo gastado?": lo mismo que el héroe de Inicio.
  Future<RespuestaVoz> resumen() async {
    final perfil = await almacen.perfil.obtener();
    if (perfil == null) return sinSesion;
    final ahora = reloj();
    final ciclo = perfil.calculadoraCiclo.calcularPara(ahora);
    final (_, resumen) = await _delCiclo(ciclo.id, ciclo.id);
    return RespuestaVoz(EstadoVoz.listo, resumenHablado(resumen, ciclo.diasParaTerminar(ahora)), resumen: resumen);
  }

  /// Los rollups del ciclo [cicloId] y el resumen de variables del ciclo en
  /// curso [actualId] (para el widget).
  Future<(Map<String, Rollup>, ResumenVariables)> _delCiclo(String cicloId, String actualId) async {
    final categorias = await almacen.categorias.listarActivas();
    final movimientos = await almacen.movimientos.listarTodos();
    Future<Map<String, Rollup>> rollupsDe(String id) async {
      final ajustes = await almacen.ajustesPresupuestoCiclo.listarPorCiclo(id);
      final efectivas = presupuestosEfectivosParaCiclo(base: categorias, ajustesDelCiclo: ajustes);
      final rs = calcularRollups(
        movimientos: [for (final m in movimientos) if (m.cicloId == id) m],
        categorias: efectivas,
        cicloId: id,
        ahora: reloj(),
      );
      return {for (final r in rs) r.categoriaId: r};
    }

    final delGasto = await rollupsDe(cicloId);
    final actuales = cicloId == actualId ? delGasto : await rollupsDe(actualId);
    final resumen = resumirVariables(categorias.whereType<CategoriaVariable>(), actuales);
    return (delGasto, resumen);
  }

  RespuestaVoz _responder(GastoEntendido g, ContextoDictado ctx, String clientId) {
    final falta = loQueFalta(g, ctx);
    final estado = g.variosGastos
        ? EstadoVoz.variosGastos
        : g.monto == null
            ? EstadoVoz.faltaMonto
            : g.categoriaId == null
                ? EstadoVoz.faltaCategoria
                : EstadoVoz.listo;
    return RespuestaVoz(estado, falta ?? confirmacionDeGasto(g, ctx), gasto: g, clientId: clientId);
  }

  (GastoEntendido, String) _leer(String propuesta) {
    final json = jsonDecode(propuesta) as Map<String, Object?>;
    return (GastoEntendido.fromJson(json['gasto'] as Map<String, Object?>), json['clientId'] as String);
  }

  /// Sin sesión abierta en el dispositivo (o sin configurar todavía).
  static const sinSesion = RespuestaVoz(
    EstadoVoz.sinSesion,
    'Primero abre MAVfin e inicia sesión; después ya puedes registrar con Siri.',
  );
}
