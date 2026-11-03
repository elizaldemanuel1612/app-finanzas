import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/data/repositorios/local/movimiento_cuenta_repositorio_archivo.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

void main() {
  test('las cuentas base se crean solas una vez, y se pueden editar', () async {
    final archivo = ArchivoTextoMemoria();
    final repo = CuentaRepositorioArchivo.sobre(archivo, reloj: () => DateTime(2026, 11, 2));
    final primeras = await repo.listarTodas();
    expect([for (final c in primeras) c.id], [idCuentaTarjeta, idCuentaEfectivo]);
    await repo.guardar(primeras.last.copyWith(llevaSaldo: true, saldoInicial: const Dinero.pesos(800)));
    await repo.guardar(Cuenta(
      id: 'bbva',
      nombre: 'BBVA',
      emoji: '💳',
      tipo: TipoCuenta.debito,
      llevaSaldo: true,
      saldoInicial: const Dinero.pesos(5000),
      fechaSaldoInicial: DateTime(2026, 11, 2),
    ));
    final todas = await repo.listarTodas();
    expect(todas, hasLength(3));
    expect(todas[1].llevaSaldo, isTrue);
  });

  test('abonos: idempotentes por clientId y se anulan', () async {
    final repo = MovimientoCuentaRepositorioArchivo.sobre(ArchivoTextoMemoria());
    final abono = MovimientoCuenta(
      clientId: 'a1',
      cuentaId: 'bbva',
      fecha: DateTime(2026, 11, 2),
      monto: const Dinero.pesos(100),
      tipo: TipoMovimientoCuenta.abono,
      entra: true,
    );
    await repo.guardar(abono);
    await repo.guardar(abono);
    expect(await repo.listarTodos(), hasLength(1));
    await repo.anular('a1');
    expect((await repo.listarTodos()).single.estado, EstadoMovimientoCuenta.anulado);
    expect(() => repo.anular('no'), throwsStateError);
  });
}
