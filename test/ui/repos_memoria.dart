import 'package:app_finanzas/data/repositorios/ajuste_presupuesto_ciclo_repositorio.dart';
import 'package:app_finanzas/data/repositorios/categoria_repositorio.dart';
import 'package:app_finanzas/data/repositorios/ciclo_repositorio.dart';
import 'package:app_finanzas/data/repositorios/ingreso_extra_repositorio.dart';
import 'package:app_finanzas/data/repositorios/movimiento_repositorio.dart';
import 'package:app_finanzas/data/repositorios/perfil_repositorio.dart';
import 'package:app_finanzas/data/repositorios/reglas_aprendidas_repositorio.dart';
import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/domain/presupuesto/ajuste_presupuesto_ciclo.dart';

// Repositorios en memoria compartidos entre las pruebas de test/ui/. Real
// dart:io no funciona dentro de la zona de tiempo simulado de
// `testWidgets` sin `tester.runAsync()` (ver paridad_pantallas_test.dart);
// para pruebas que solo necesitan montar una pantalla con datos fijos,
// evitar E/S real por completo es más simple y más rápido.

final class CategoriaRepositorioMemoria implements CategoriaRepositorio {
  final List<Categoria> items;
  CategoriaRepositorioMemoria(this.items);

  @override
  Future<List<Categoria>> listarTodas() async => items;
  @override
  Future<List<Categoria>> listarActivas() async =>
      items.where((c) => c.activa).toList();
  @override
  Future<Categoria?> buscarPorId(String id) async {
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<void> guardar(Categoria categoria) async {
    items.removeWhere((c) => c.id == categoria.id);
    items.add(categoria);
  }

  @override
  Future<void> eliminar(String id) => throw UnimplementedError();
}

final class MovimientoRepositorioMemoria implements MovimientoRepositorio {
  final List<Movimiento> items;
  MovimientoRepositorioMemoria(this.items);

  @override
  Future<List<Movimiento>> listarPorCiclo(String cicloId) async =>
      items.where((m) => m.cicloId == cicloId).toList();
  @override
  Future<List<Movimiento>> listarPorCategoria(String categoriaId) async =>
      items.where((m) => m.categoriaId == categoriaId).toList();
  @override
  Future<List<Movimiento>> listarTodos() async => items;
  @override
  Future<bool> existeClientId(String clientId) async =>
      items.any((m) => m.clientId == clientId);
  @override
  Future<Movimiento> guardar(Movimiento movimiento) =>
      throw UnimplementedError();
  @override
  Future<void> actualizar(Movimiento movimiento) => throw UnimplementedError();
  @override
  Future<void> anular(String id) => throw UnimplementedError();
}

final class ReglasAprendidasRepositorioMemoria implements ReglasAprendidasRepositorio {
  @override
  Future<List<ReglaAprendida>> listarTodas() async => const [];
  @override
  Future<void> guardarTodas(List<ReglaAprendida> reglas) =>
      throw UnimplementedError();
}

final class CicloRepositorioMemoria implements CicloRepositorio {
  final List<CicloGuardado> items;
  CicloRepositorioMemoria([this.items = const []]);

  @override
  Future<CicloGuardado?> buscarPorId(String id) async {
    for (final g in items) {
      if (g.ciclo.id == id) return g;
    }
    return null;
  }

  @override
  Future<List<CicloGuardado>> listarTodos() async => items;
  @override
  Future<void> guardar(CicloGuardado guardado) => throw UnimplementedError();
}

final class IngresoExtraRepositorioMemoria implements IngresoExtraRepositorio {
  final List<IngresoExtra> items;
  IngresoExtraRepositorioMemoria(this.items);

  @override
  Future<List<IngresoExtra>> listarPorCiclo(String cicloId) async =>
      items.where((e) => e.cicloId == cicloId).toList();
  @override
  Future<List<IngresoExtra>> listarTodos() async => items;
  @override
  Future<IngresoExtra> guardar(IngresoExtra ingreso) =>
      throw UnimplementedError();
  @override
  Future<void> anular(String id) => throw UnimplementedError();
}

final class AjustePresupuestoCicloRepositorioMemoria
    implements AjustePresupuestoCicloRepositorio {
  final List<AjustePresupuestoCiclo> items;
  AjustePresupuestoCicloRepositorioMemoria([this.items = const []]);

  @override
  Future<List<AjustePresupuestoCiclo>> listarPorCiclo(String cicloId) async =>
      items.where((a) => a.cicloId == cicloId).toList();
  @override
  Future<void> agregarLote(List<AjustePresupuestoCiclo> ajustes) =>
      throw UnimplementedError();
}

final class PerfilRepositorioMemoria implements PerfilRepositorio {
  Perfil? perfil;
  PerfilRepositorioMemoria(this.perfil);

  @override
  Future<Perfil?> obtener() async => perfil;
  @override
  Future<void> guardar(Perfil perfil) async => this.perfil = perfil;
}

Movimiento conId(Movimiento m) => m.id == null ? m.copyWith(id: m.clientId) : m;
