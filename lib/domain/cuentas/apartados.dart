import '../../core/money.dart';
import '../modelos/cuenta.dart';
import '../modelos/movimiento.dart';
import '../modelos/movimiento_cuenta.dart';
import 'saldos.dart';

/// Apartados dentro de una cuenta (spec-app-finanzas-v2.md §7.3.5): una
/// cuenta de ahorro con `cuentaPadreId`. El dinero entra y sale con
/// transferencias entre el apartado y su cuenta, así que el patrimonio no
/// cambia al guardar o sacar.

/// Un apartado nuevo dentro de [padre], vacío desde [ahora]. `null` si
/// [padre] no puede tener apartados (efectivo, crédito u otro apartado).
Cuenta? nuevoApartado({
  required Cuenta padre,
  required String id,
  required String nombre,
  required String emoji,
  required DateTime ahora,
}) {
  if (!padre.puedeTenerApartados) return null;
  return Cuenta(
    id: id,
    nombre: nombre,
    emoji: emoji,
    tipo: TipoCuenta.ahorro,
    llevaSaldo: true,
    saldoInicial: const Dinero.cero(),
    fechaSaldoInicial: ahora,
    cuentaPadreId: padre.id,
  );
}

/// Los apartados de [padre] en [cuentas], en su orden. Con [soloActivos],
/// sin los archivados.
List<Cuenta> apartadosDe(Cuenta padre, List<Cuenta> cuentas, {bool soloActivos = true}) => [
      for (final c in cuentas)
        if (c.cuentaPadreId == padre.id && (c.activa || !soloActivos)) c,
    ];

/// Lo que hay en [padre] contando sus apartados activos: lo que el banco
/// llama "saldo total". `null` si [padre] no lleva saldo.
Dinero? totalConApartados(
  Cuenta padre,
  List<Cuenta> cuentas,
  List<Movimiento> gastos,
  List<MovimientoCuenta> movimientosCuenta,
) {
  final propio = saldoDe(padre, gastos, movimientosCuenta);
  if (propio == null) return null;
  var centavos = propio.centavos;
  for (final a in apartadosDe(padre, cuentas)) {
    centavos += saldoDe(a, gastos, movimientosCuenta)?.centavos ?? 0;
  }
  return Dinero(centavos);
}

/// "Viaje · BBVA débito" para un apartado; el nombre solo para las demás.
String nombreConCuenta(Cuenta cuenta, List<Cuenta> cuentas) {
  final padreId = cuenta.cuentaPadreId;
  if (padreId == null) return cuenta.nombre;
  for (final c in cuentas) {
    if (c.id == padreId) return '${cuenta.nombre} · ${c.nombre}';
  }
  return cuenta.nombre;
}

/// Lo que hay que hacer para eliminar [apartado] (spec §7.3.5): la
/// transferencia que regresa su [saldo] a la cuenta donde vive —o que la
/// cubre, si quedó negativo— y el apartado ya archivado. Transferencia
/// `null` si el saldo es cero. `null` del todo si [apartado] no es un
/// apartado.
({MovimientoCuenta? liberacion, Cuenta archivado})? eliminarApartado({
  required Cuenta apartado,
  required Dinero saldo,
  required String clientId,
  required DateTime ahora,
}) {
  final padre = apartado.cuentaPadreId;
  if (padre == null) return null;
  final regresa = !saldo.esNegativo;
  return (
    liberacion: saldo.esCero
        ? null
        : MovimientoCuenta(
            clientId: clientId,
            cuentaId: regresa ? apartado.id : padre,
            cuentaDestinoId: regresa ? padre : apartado.id,
            fecha: ahora,
            monto: saldo.absoluto,
            tipo: TipoMovimientoCuenta.transferencia,
            entra: false,
          ),
    archivado: apartado.copyWith(activa: false),
  );
}
