import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/objetivo_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/objetivo.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/ui/comun/tema.dart';
import 'package:app_finanzas/ui/objetivos/pantalla_objetivos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repos_memoria.dart';

// Objetivos por cumplir, logrados y archivados (spec-app-finanzas-v2.md
// §7.3.3, 2026-11-17).

Objetivo _obj(String id, String nombre, int pesos, String cuenta) => Objetivo(
      id: id,
      nombre: nombre,
      emoji: '🎯',
      monto: Dinero.pesos(pesos),
      cuentaId: cuenta,
      creado: DateTime(2026, 11, 1),
    );

void main() {
  testWidgets('separa por cumplir y logrados; un logrado se archiva', (tester) async {
    final cuentas = CuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    for (final (id, pesos) in [('cetes', 700000), ('nu', 0)]) {
      await cuentas.guardar(Cuenta(
        id: id,
        nombre: id.toUpperCase(),
        emoji: '🏦',
        tipo: TipoCuenta.ahorro,
        llevaSaldo: true,
        saldoInicial: Dinero.pesos(pesos),
        fechaSaldoInicial: DateTime(2026, 1, 1),
      ));
    }
    final objetivos = ObjetivoRepositorioArchivo.sobre(ArchivoTextoMemoria());
    await objetivos.guardar(_obj('depa', 'Depa', 684480, 'cetes'));
    await objetivos.guardar(_obj('viaje', 'Viaje', 30000, 'nu'));

    await tester.pumpWidget(MaterialApp(
      theme: construirTema(),
      home: PantallaObjetivos(
        perfil: const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000)),
        objetivoRepositorio: objetivos,
        cuentaRepositorio: cuentas,
        movimientoRepositorio: MovimientoRepositorioMemoria([]),
        movimientoCuentaRepositorio: MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria()),
        categoriaRepositorio: CategoriaRepositorioMemoria([]),
      ),
    ));
    await tester.pumpAndSettle();

    // Por omisión, lo que falta.
    expect(find.text('Te faltan'), findsOneWidget);
    expect(find.text('Por cumplir · 1'), findsOneWidget);
    expect(find.text('Logrados · 1'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Depa'), findsNothing);

    await tester.tap(find.text('Logrados · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Depa'), findsOneWidget);
    await tester.tap(find.text('Ya lo usé, archivar'));
    await tester.pumpAndSettle();
    expect((await objetivos.listarTodos()).firstWhere((o) => o.id == 'depa').activo, isFalse);
    // Sin logrados, vuelve a lo que falta.
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.textContaining('Logrados'), findsNothing);

    await tester.tap(find.text('Archivados · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Depa'), findsOneWidget);
  });
}
