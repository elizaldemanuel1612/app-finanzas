import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/cuentas/eliminar_cuenta.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

// "Eliminar cuenta" (spec-app-finanzas-v2.md §7.3.1): se borra si nunca se
// usó; con historial, se archiva.

Cuenta _cuenta(String id, {TipoCuenta tipo = TipoCuenta.debito, String? padre, bool activa = true}) => Cuenta(
      id: id,
      nombre: id,
      emoji: '🏦',
      tipo: tipo,
      llevaSaldo: true,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 1, 1),
      activa: activa,
      cuentaPadreId: padre,
    );

Movimiento _gasto(String cuentaId, {EstadoMovimiento estado = EstadoMovimiento.activo}) => Movimiento(
      clientId: 'g',
      fecha: DateTime(2026, 10, 1),
      cicloId: 'c',
      periodoNatural: '2026-10',
      monto: const Dinero.pesos(1),
      categoriaId: 'super',
      medio: MedioPago.tarjeta,
      descripcion: 'x',
      estado: estado,
      origenCaptura: OrigenCaptura.manual,
      cuentaId: cuentaId,
    );

MovimientoCuenta _transferencia(String de, String a) => MovimientoCuenta(
      clientId: 't',
      cuentaId: de,
      cuentaDestinoId: a,
      fecha: DateTime(2026, 10, 1),
      monto: const Dinero.pesos(10),
      tipo: TipoMovimientoCuenta.transferencia,
      entra: false,
    );

void main() {
  final nu = _cuenta('nu');
  final otra = _cuenta('otra');

  test('sin ningún movimiento se borra por completo', () {
    expect(comoQuitarCuenta(nu, [nu, otra], [_gasto('otra')], [_transferencia('otra', 'bbva')]), QuitarCuenta.eliminar);
  });

  test('con gastos, aun anulados, se archiva', () {
    expect(comoQuitarCuenta(nu, [nu], [_gasto('nu', estado: EstadoMovimiento.anulado)], const []), QuitarCuenta.archivar);
  });

  test('con una transferencia que la toca, de ida o de vuelta, se archiva', () {
    expect(comoQuitarCuenta(nu, [nu], const [], [_transferencia('otra', 'nu')]), QuitarCuenta.archivar);
    expect(comoQuitarCuenta(nu, [nu], const [], [_transferencia('nu', 'otra')]), QuitarCuenta.archivar);
  });

  test('con apartados activos, primero hay que eliminarlos; si ya se eliminaron, se archiva', () {
    final viaje = _cuenta('viaje', tipo: TipoCuenta.ahorro, padre: 'nu');
    expect(comoQuitarCuenta(nu, [nu, viaje], const [], const []), QuitarCuenta.tieneApartados);
    final archivado = _cuenta('viaje', tipo: TipoCuenta.ahorro, padre: 'nu', activa: false);
    expect(comoQuitarCuenta(nu, [nu, archivado], const [], const []), QuitarCuenta.archivar);
  });

  test('Efectivo no se quita; Tarjeta, que se vuelve a crear sola, solo se archiva', () {
    final base = cuentasBase(DateTime(2026));
    final tarjeta = base.firstWhere((c) => c.id == idCuentaTarjeta);
    final efectivo = base.firstWhere((c) => c.id == idCuentaEfectivo);
    expect(comoQuitarCuenta(efectivo, base, const [], const []), QuitarCuenta.noSePuede);
    expect(comoQuitarCuenta(tarjeta, base, const [], const []), QuitarCuenta.archivar);
  });
}
