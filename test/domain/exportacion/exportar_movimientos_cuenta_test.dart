import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/exportacion/exportar_csv.dart';
import 'package:app_finanzas/domain/modelos/categoria_ingreso.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §7.4 (2026-11-16): ingresos, ajustes y
// transferencias en su propio CSV.

Cuenta _cuenta(String id, String nombre, TipoCuenta tipo) => Cuenta(
      id: id,
      nombre: nombre,
      emoji: '💳',
      tipo: tipo,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026),
    );

void main() {
  final cuentas = [
    _cuenta('bbva', 'BBVA débito', TipoCuenta.debito),
    _cuenta('ahorro', 'Ahorro, Nu', TipoCuenta.ahorro),
  ];
  const nomina = CategoriaIngreso(id: 'nomina', nombre: 'Nómina', emoji: '💼');

  test('un renglón por movimiento, en orden de fecha, con nombres y signo solo en ajustes', () {
    final csv = exportarMovimientosCuentaCsv(
      movimientos: [
        MovimientoCuenta(
          clientId: 't1',
          cuentaId: 'bbva',
          cuentaDestinoId: 'ahorro',
          fecha: DateTime(2026, 11, 10, 9, 15),
          monto: const Dinero.pesos(2000),
          tipo: TipoMovimientoCuenta.transferencia,
          entra: false,
        ),
        MovimientoCuenta(
          clientId: 'a1',
          cuentaId: 'bbva',
          fecha: DateTime(2026, 11, 1),
          monto: const Dinero.pesos(30000),
          tipo: TipoMovimientoCuenta.abono,
          entra: true,
          nota: '=quincena',
          categoriaIngresoId: 'nomina',
        ),
        MovimientoCuenta(
          clientId: 'j1',
          cuentaId: 'bbva',
          fecha: DateTime(2026, 11, 12),
          monto: const Dinero(1250),
          tipo: TipoMovimientoCuenta.ajuste,
          entra: false,
          estado: EstadoMovimientoCuenta.anulado,
        ),
        MovimientoCuenta(
          clientId: 'x1',
          cuentaId: 'borrada',
          fecha: DateTime(2026, 11, 13),
          monto: const Dinero.pesos(5),
          tipo: TipoMovimientoCuenta.abono,
          entra: true,
          categoriaIngresoId: 'ya-no-existe',
        ),
      ],
      cuentas: cuentas,
      categoriasIngreso: const [nomina],
    );
    expect(csv.startsWith('﻿'), isTrue);
    expect(csv.substring(1).trim().split('\n'), [
      'Fecha,Tipo,Monto,Cuenta,Hacia la cuenta,Categoría de ingreso,Nota,Estado,ID',
      "2026-11-01,Ingreso,30000.00,BBVA débito,,Nómina,'=quincena,Activo,a1",
      '2026-11-10 09:15,Transferencia,2000.00,BBVA débito,"Ahorro, Nu",,,Activo,t1',
      '2026-11-12,Ajuste de saldo,-12.50,BBVA débito,,,,Anulado,j1',
      '2026-11-13,Ingreso,5.00,borrada,,,,Activo,x1',
    ]);
  });

  test('sin movimientos, solo encabezados', () {
    expect(exportarMovimientosCuentaCsv(movimientos: const []), '﻿${encabezadosMovimientosCuenta.join(',')}\n');
  });
}
