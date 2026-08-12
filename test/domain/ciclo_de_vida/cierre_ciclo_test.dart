import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/cierre_ciclo.dart';
import 'package:app_finanzas/domain/ciclo_de_vida/ingresos_ciclo.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/ciclo_guardado.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/ingreso_extra.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/snapshot_ciclo.dart';
import 'package:app_finanzas/domain/reglas/creacion_movimiento.dart';
import 'package:test/test.dart';

const _sinExtra = IngresosDelCiclo.soloBase(Dinero.pesos(87000));

const _calculadora = CalculadoraCiclo(12);
final _ciclo = _calculadora.calcularPara(DateTime(2026, 7, 15)); // 2026-07, abierto

final _fija = CategoriaFija(
  id: 'renta',
  nombre: 'Renta',
  emoji: '🏠',
  activa: true,
  esNecesaria: true,
  montoFijoCentavos: const Dinero.pesos(5000),
  diaDelCiclo: 1,
);

final _variable = CategoriaVariable(
  id: 'super',
  nombre: 'Súper',
  emoji: '🛒',
  activa: true,
  esNecesaria: false,
  presupuestoMensualCentavos: const Dinero.pesos(8000),
);

Movimiento _mov(String clientId, String categoriaId, int pesos) {
  final r = crearMovimiento(
    clientId: clientId,
    fecha: DateTime(2026, 7, 20),
    calculadoraCiclo: _calculadora,
    monto: Dinero.pesos(pesos),
    categoriaId: categoriaId,
    medio: MedioPago.tarjeta,
    descripcion: categoriaId,
    origenCaptura: OrigenCaptura.manual,
  ) as Exito<Movimiento>;
  return r.valor;
}

void main() {
  group('calcularSnapshotCierre', () {
    test('calcula el snapshot correcto a partir de los rollups', () {
      final movimientos = [_mov('a12345678', 'super', 300), _mov('b12345678', 'super', 200)];
      final resultado = calcularSnapshotCierre(
        ciclo: _ciclo,
        movimientos: movimientos,
        categorias: [_fija, _variable],
        ingresos: _sinExtra,
        metaBase: const Dinero.pesos(34800),
        fechaCierre: DateTime(2026, 8, 12),
      );
      expect(resultado.esExito, isTrue);
      final snapshot = (resultado as Exito<SnapshotCiclo>).valor;
      expect(snapshot.cicloId, '2026-07');
      expect(snapshot.totalGastado, const Dinero.pesos(500));
      expect(snapshot.ingresoTotal, const Dinero.pesos(87000));
      expect(snapshot.metaApartado, const Dinero.pesos(34800));
      expect(snapshot.renglones, hasLength(2));
      final renglonSuper = snapshot.renglones.firstWhere((r) => r.categoriaId == 'super');
      expect(renglonSuper.realCentavos, const Dinero.pesos(500));
      expect(renglonSuper.conteoMovimientos, 2);
    });

    test('nombre y emoji quedan congelados en cada renglón', () {
      final resultado = calcularSnapshotCierre(
        ciclo: _ciclo,
        movimientos: const [],
        categorias: [_fija, _variable],
        ingresos: _sinExtra,
        metaBase: const Dinero.pesos(34800),
        fechaCierre: DateTime(2026, 8, 12),
      );
      final snapshot = (resultado as Exito<SnapshotCiclo>).valor;
      final renglonSuper = snapshot.renglones.firstWhere((r) => r.categoriaId == 'super');
      expect(renglonSuper.nombre, 'Súper');
      expect(renglonSuper.emoji, '🛒');
    });

    test('falla si el ciclo ya está cerrado', () {
      final cerrado = _ciclo.cerrar().valorOLanza;
      final resultado = calcularSnapshotCierre(
        ciclo: cerrado,
        movimientos: const [],
        categorias: [_fija, _variable],
        ingresos: _sinExtra,
        metaBase: const Dinero.pesos(34800),
        fechaCierre: DateTime(2026, 8, 12),
      );
      expect(resultado.esFalla, isTrue);
    });

    test('falla si un movimiento activo tiene una categoría que ya no existe (descuadre)', () {
      final movimientos = [
        _mov('a12345678', 'super', 300),
        _mov('huerfano1', 'categoria_borrada', 999),
      ];
      final resultado = calcularSnapshotCierre(
        ciclo: _ciclo,
        movimientos: movimientos,
        categorias: [_fija, _variable],
        ingresos: _sinExtra,
        metaBase: const Dinero.pesos(34800),
        fechaCierre: DateTime(2026, 8, 12),
      );
      expect(resultado.esFalla, isTrue);
    });

    test('los movimientos anulados no cuentan para el descuadre', () {
      final movimientos = [
        _mov('a12345678', 'super', 300),
        _mov('anulado1', 'categoria_borrada', 999).copyWith(estado: EstadoMovimiento.anulado),
      ];
      final resultado = calcularSnapshotCierre(
        ciclo: _ciclo,
        movimientos: movimientos,
        categorias: [_fija, _variable],
        ingresos: _sinExtra,
        metaBase: const Dinero.pesos(34800),
        fechaCierre: DateTime(2026, 8, 12),
      );
      expect(resultado.esExito, isTrue);
    });

    test('el snapshot conserva el desglose de extras y metaApartado = metaBase + extraAApartado', () {
      final movimientos = [_mov('a12345678', 'super', 300)];
      final ingresos = calcularIngresosDelCiclo(
        ingresoBase: const Dinero.pesos(87000),
        cicloId: _ciclo.id,
        extras: [
          IngresoExtra(
            id: 'ing-1',
            cicloId: _ciclo.id,
            etiqueta: 'Bono',
            monto: const Dinero.pesos(15000),
            fecha: DateTime(2026, 7, 20),
            destino: DestinoExtra.apartado,
            estado: EstadoIngreso.activo,
          ),
        ],
      );
      final resultado = calcularSnapshotCierre(
        ciclo: _ciclo,
        movimientos: movimientos,
        categorias: [_fija, _variable],
        ingresos: ingresos,
        metaBase: const Dinero.pesos(34800),
        fechaCierre: DateTime(2026, 8, 12),
      );
      expect(resultado.esExito, isTrue);
      final snapshot = (resultado as Exito<SnapshotCiclo>).valor;
      expect(snapshot.extraAApartado, const Dinero.pesos(15000));
      expect(snapshot.extraAGasto, const Dinero.cero());
      expect(snapshot.ingresoTotal, const Dinero.pesos(102000));
      expect(snapshot.metaApartado, const Dinero.pesos(49800));
    });
  });

  group('cerrarCiclo', () {
    test('cierra el ciclo y adjunta el snapshot', () {
      final snapshot = SnapshotCiclo(
        cicloId: _ciclo.id,
        fechaCierre: DateTime(2026, 8, 12),
        ingresoTotal: const Dinero.pesos(87000),
        metaApartado: const Dinero.pesos(34800),
        totalGastado: const Dinero.pesos(500),
        renglones: const [],
      );
      final resultado = cerrarCiclo(ciclo: _ciclo, snapshot: snapshot);
      expect(resultado.esExito, isTrue);
      final guardado = (resultado as Exito<CicloGuardado>).valor;
      expect(guardado.ciclo.estado, EstadoCiclo.cerrado);
      expect(guardado.snapshot, snapshot);
    });

    test('falla si el ciclo ya está cerrado', () {
      final cerrado = _ciclo.cerrar().valorOLanza;
      final snapshot = SnapshotCiclo(
        cicloId: _ciclo.id,
        fechaCierre: DateTime(2026, 8, 12),
        ingresoTotal: const Dinero.pesos(87000),
        metaApartado: const Dinero.pesos(34800),
        totalGastado: const Dinero.pesos(500),
        renglones: const [],
      );
      final resultado = cerrarCiclo(ciclo: cerrado, snapshot: snapshot);
      expect(resultado.esFalla, isTrue);
    });
  });

  group('reabrirCiclo', () {
    test('reabre y conserva el snapshot anterior', () {
      final snapshot = SnapshotCiclo(
        cicloId: _ciclo.id,
        fechaCierre: DateTime(2026, 8, 12),
        ingresoTotal: const Dinero.pesos(87000),
        metaApartado: const Dinero.pesos(34800),
        totalGastado: const Dinero.pesos(500),
        renglones: const [],
      );
      final cerrado = CicloGuardado(ciclo: _ciclo.cerrar().valorOLanza, snapshot: snapshot);
      final resultado = reabrirCiclo(cerrado);
      expect(resultado.esExito, isTrue);
      final reabierto = (resultado as Exito<CicloGuardado>).valor;
      expect(reabierto.ciclo.estado, EstadoCiclo.abierto);
      expect(reabierto.snapshot, snapshot);
    });

    test('falla si el ciclo ya está abierto', () {
      final abierto = CicloGuardado(ciclo: _ciclo, snapshot: null);
      final resultado = reabrirCiclo(abierto);
      expect(resultado.esFalla, isTrue);
    });
  });
}
