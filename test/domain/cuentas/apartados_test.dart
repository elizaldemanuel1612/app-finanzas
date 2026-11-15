import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/cuentas/apartados.dart';
import 'package:app_finanzas/domain/cuentas/saldos.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/modelos/movimiento_cuenta.dart';
import 'package:test/test.dart';

final _inicio = DateTime(2026, 11, 1);

Cuenta _cuenta(String id, TipoCuenta tipo, int pesos) => Cuenta(
      id: id,
      nombre: id,
      emoji: '🏦',
      tipo: tipo,
      llevaSaldo: true,
      saldoInicial: Dinero.pesos(pesos),
      fechaSaldoInicial: _inicio,
    );

MovimientoCuenta _transferencia(String de, String a, int pesos, {String id = 't'}) => MovimientoCuenta(
      clientId: id,
      cuentaId: de,
      cuentaDestinoId: a,
      fecha: DateTime(2026, 11, 10),
      monto: Dinero.pesos(pesos),
      tipo: TipoMovimientoCuenta.transferencia,
      entra: false,
    );

void main() {
  final bbva = _cuenta('bbva', TipoCuenta.debito, 30000);

  test('un apartado es de ahorro, vacío y dentro de su cuenta', () {
    final viaje = nuevoApartado(padre: bbva, id: 'viaje', nombre: 'Viaje', emoji: '✈️', ahora: _inicio)!;
    expect(viaje.tipo, TipoCuenta.ahorro);
    expect(viaje.llevaSaldo, isTrue);
    expect(viaje.saldoInicial, const Dinero.cero());
    expect(viaje.cuentaPadreId, 'bbva');
    expect(viaje.esApartado, isTrue);
    expect(viaje.puedeTenerApartados, isFalse, reason: 'no hay apartados de apartados');
    expect(bbva.esApartado, isFalse);
  });

  test('solo débito y ahorro pueden tener apartados', () {
    expect(_cuenta('cetes', TipoCuenta.ahorro, 0).puedeTenerApartados, isTrue);
    for (final tipo in [TipoCuenta.efectivo, TipoCuenta.credito]) {
      expect(nuevoApartado(padre: _cuenta('x', tipo, 0), id: 'a', nombre: 'a', emoji: '•', ahora: _inicio), isNull);
    }
  });

  test('guardar en un apartado no cambia el patrimonio ni el total de la cuenta', () {
    final viaje = nuevoApartado(padre: bbva, id: 'viaje', nombre: 'Viaje', emoji: '✈️', ahora: _inicio)!;
    final archivado = nuevoApartado(padre: bbva, id: 'viejo', nombre: 'Viejo', emoji: '•', ahora: _inicio)!
        .copyWith(activa: false);
    final cuentas = [bbva, viaje, archivado];
    final movs = [_transferencia('bbva', 'viaje', 8000)];

    expect(saldoDe(bbva, const [], movs), const Dinero.pesos(22000));
    expect(saldoDe(viaje, const [], movs), const Dinero.pesos(8000));
    expect(totalConApartados(bbva, cuentas, const [], movs), const Dinero.pesos(30000));
    final patrimonio = calcularPatrimonio(cuentas, const [], movs);
    expect(patrimonio.disponible, const Dinero.pesos(22000));
    expect(patrimonio.ahorros, const Dinero.pesos(8000));
    expect(patrimonio.total, const Dinero.pesos(30000));

    expect(apartadosDe(bbva, cuentas).map((c) => c.id), ['viaje']);
    expect(apartadosDe(bbva, cuentas, soloActivos: false).map((c) => c.id), ['viaje', 'viejo']);
  });

  test('sin saldo no hay total', () {
    final sinSaldo = Cuenta(
      id: 'efe',
      nombre: 'Efectivo',
      emoji: '💵',
      tipo: TipoCuenta.efectivo,
      llevaSaldo: false,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: _inicio,
    );
    expect(totalConApartados(sinSaldo, [sinSaldo], const [], const []), isNull);
  });

  test('el nombre de un apartado lleva su cuenta', () {
    final viaje = nuevoApartado(padre: bbva, id: 'viaje', nombre: 'Viaje', emoji: '✈️', ahora: _inicio)!;
    expect(nombreConCuenta(viaje, [bbva, viaje]), 'Viaje · bbva');
    expect(nombreConCuenta(viaje, [viaje]), 'Viaje', reason: 'si su cuenta no está, solo su nombre');
    expect(nombreConCuenta(bbva, [bbva, viaje]), 'bbva');
  });

  test('viaja en JSON y copyWith lo conserva', () {
    final viaje = nuevoApartado(padre: bbva, id: 'viaje', nombre: 'Viaje', emoji: '✈️', ahora: _inicio)!;
    final copia = Cuenta.fromJson(viaje.toJson());
    expect(copia.cuentaPadreId, 'bbva');
    expect(viaje.copyWith(nombre: 'Japón').cuentaPadreId, 'bbva');
    expect(bbva.toJson().containsKey('cuentaPadreId'), isFalse);
  });
}
