import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/data/almacenamiento/archivo_texto.dart';
import 'package:app_finanzas/data/repositorios/local/almacen_local.dart';
import 'package:app_finanzas/data/voz/registro_por_voz.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/perfil.dart';
import 'package:app_finanzas/siri.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// El canal que usa `ios/Runner/AtajosSiri.swift` (spec §5.6.3): lo que
// Swift manda y lo que recibe. Las pruebas en el iPhone simulado están en
// `ios/RunnerTests/RunnerTests.swift`.
void main() {
  late RegistroPorVoz voz;

  setUp(() async {
    final a = AlmacenLocal.sobre({for (final n in AlmacenLocal.nombresDeArchivo) n: ArchivoTextoMemoria()});
    await a.perfil.guardar(const Perfil(diaCorte: 1, ingresoBaseMensual: Dinero.pesos(20000)));
    await a.categorias.guardar(const CategoriaVariable(
      id: 'super',
      nombre: 'Súper',
      emoji: '🛒',
      activa: true,
      esNecesaria: true,
      presupuestoMensualCentavos: Dinero.pesos(3000),
    ));
    var n = 0;
    voz = RegistroPorVoz(
      almacen: a,
      reloj: () => DateTime(2026, 11, 15, 10),
      nuevoClientId: () => 'siri-prueba-${n++}',
    );
  });

  test('interpretar → registrar, con lo que muestra el widget', () async {
    final r = await atenderSiri(const MethodCall('interpretar', {'frase': '230 en el súper'}), registro: voz);
    expect(r['estado'], 'listo');
    expect(r['mensaje'], r'¿Registro $230 en Súper con Tarjeta, hoy?');
    expect(r.containsKey('widget'), isFalse);

    final hecho = await atenderSiri(MethodCall('registrar', {'propuesta': r['propuesta']}), registro: voz);
    expect(hecho['estado'], 'registrado');
    expect(hecho['mensaje'], r'Listo. Te quedan $2,770 en Súper.');
    expect(hecho['widget'], {'quedaHoyTexto': r'$230.00', 'deTexto': r'de $3,000.00', 'fecha': '2026-11-15'});
  });

  test('conCategoria y resumen', () async {
    final r = await atenderSiri(const MethodCall('interpretar', {'frase': '80 en la tlapalería'}), registro: voz);
    expect(r['estado'], 'faltaCategoria');
    final lista = await atenderSiri(
      MethodCall('conCategoria', {'propuesta': r['propuesta'], 'categoria': 'súper'}),
      registro: voz,
    );
    expect(lista['estado'], 'listo');
    final resumen = await atenderSiri(const MethodCall('resumen'), registro: voz);
    expect(resumen['mensaje'], startsWith(r'Llevas $0 de $3,000 este ciclo.'));
  });

  test('un método que no existe', () async {
    expect(() => atenderSiri(const MethodCall('otro'), registro: voz), throwsA(isA<MissingPluginException>()));
  });
}
