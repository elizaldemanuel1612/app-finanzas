import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/data/repositorios/anular_gasto.dart';
import 'package:app_finanzas/domain/cuentas/compra_a_meses.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

import '../../ui/repos_memoria.dart';

// spec §7.3.1 (2026-11-16): una mensualidad no se quita sola; anular y
// Deshacer van con toda la compra.

void main() {
  List<Movimiento> compra() => switch (crearCompraAMeses(
        compraId: 'compra-tele-0001',
        fecha: DateTime(2026, 11, 10),
        calculadoraCiclo: const CalculadoraCiclo(1),
        total: const Dinero.pesos(300),
        meses: 3,
        categoriaId: 'casa',
        descripcion: 'Tele',
        origenCaptura: OrigenCaptura.manual,
        cuentaId: 'platino',
      )) {
        Exito(:final valor) => [for (final m in valor) m.copyWith(id: m.clientId)],
        Falla(:final mensaje) => throw StateError(mensaje),
      };

  test('anular una mensualidad anula la compra; restaurar la regresa entera', () async {
    final suelto = compra().first.copyWith(
      id: 'gasto-suelto-01',
      clientId: 'gasto-suelto-01',
      compraId: null,
    );
    final contado = Movimiento.fromJson({...suelto.toJson()}..remove('compraId')..remove('mensualidad')..remove('meses'));
    final repo = MovimientoRepositorioMemoria([...compra(), contado]);

    await anularGasto(repo, repo.items[1]);
    expect([for (final m in repo.items) m.estado], [
      EstadoMovimiento.anulado,
      EstadoMovimiento.anulado,
      EstadoMovimiento.anulado,
      EstadoMovimiento.activo,
    ]);
    // Anular otra vez no vuelve a tocar las ya anuladas.
    await anularGasto(repo, repo.items[0]);

    await restaurarGasto(repo, repo.items[2]);
    expect(repo.items.every((m) => m.estado == EstadoMovimiento.activo), isTrue);

    await anularGasto(repo, contado);
    expect(repo.items.last.estado, EstadoMovimiento.anulado);
    expect(repo.items.first.estado, EstadoMovimiento.activo);
    await restaurarGasto(repo, repo.items.last);
    expect(repo.items.last.estado, EstadoMovimiento.activo);
  });
}
