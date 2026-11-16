import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/voz/interpretar_gasto.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §5.6.3: lo que Siri y el dictado entienden de una
// frase, sin IA y con la IA validada.

CategoriaVariable _cat(String id, String nombre, {bool activa = true}) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🛒',
      activa: activa,
      esNecesaria: false,
      presupuestoMensualCentavos: const Dinero.pesos(1000),
    );

Cuenta _cuenta(String id, String nombre, TipoCuenta tipo) => Cuenta(
      id: id,
      nombre: nombre,
      emoji: '💳',
      tipo: tipo,
      llevaSaldo: false,
      saldoInicial: const Dinero.cero(),
      fechaSaldoInicial: DateTime(2026, 1, 1),
    );

// Domingo 15 de noviembre de 2026.
final _hoy = DateTime(2026, 11, 15, 14, 30);

final _ctx = ContextoDictado(
  categorias: [
    _cat('super', 'Súper/Comida'),
    _cat('salidas', 'Salidas'),
    _cat('gasolina', 'Gasolina'),
    _cat('salud', 'Salud'),
    _cat('cafe', 'Café'),
    _cat('vieja', 'Ropa', activa: false),
  ],
  cuentas: [
    _cuenta('bbva', 'BBVA', TipoCuenta.debito),
    _cuenta('banamex', 'Banamex platino', TipoCuenta.credito),
    _cuenta('efectivo', 'Efectivo', TipoCuenta.efectivo),
    _cuenta('santander', 'Santander', TipoCuenta.debito),
  ],
  cuentaPorOmision: 'bbva',
  hoy: _hoy,
  reglas: [ReglaAprendida(patron: 'oxxo', categoriaId: 'cafe', contador: 3)],
  historialComercios: const {'pemex': 'gasolina'},
);

GastoEntendido _g(String frase) => interpretarFraseGasto(frase, _ctx);

void main() {
  group('monto', () {
    test('en palabras, en cifras, con signo, comas y decimales', () {
      expect(_g('230 en el súper').monto, const Dinero.pesos(230));
      expect(_g('doscientos treinta en el súper').monto, const Dinero.pesos(230));
      expect(_g(r'$1,250.50 en el súper').monto, const Dinero(125050));
      expect(_g('1,500 de gasolina').monto, const Dinero.pesos(1500));
      expect(_g('gasté 45.5 en café').monto, const Dinero(4550));
      expect(_g('veintidós de café').monto, const Dinero.pesos(22));
      expect(_g('3 mil 132 en el súper').monto, const Dinero.pesos(3132));
    });

    test('pesos con centavos dichos', () {
      expect(_g('doscientos treinta pesos con cincuenta centavos en el súper').monto, const Dinero(23050));
      expect(_g('230 pesos con 50 de gasolina').monto, const Dinero(23050));
    });

    test('dos números sin saber cuál: no adivina', () {
      final g = _g('doce tacos de treinta pesos');
      expect(g.monto, isNull);
      expect(g.montosDichos, [const Dinero.pesos(12), const Dinero.pesos(30)]);
      expect(g.completo, isFalse);
    });

    test('sin número no hay monto', () {
      final g = _g('fui al súper');
      expect(g.monto, isNull);
      expect(g.montosDichos, isEmpty);
    });

    test('varios gastos en una frase se marcan', () {
      expect(_g('50 de café y 200 de súper').variosGastos, isTrue);
      expect(_g('50 de café y 200 de súper').completo, isFalse);
    });
  });

  group('fecha', () {
    test('hoy por omisión', () {
      final g = _g('230 en el súper');
      expect(g.fecha, DateTime(2026, 11, 15));
      expect(g.fechaDicha, isFalse);
    });

    test('ayer, antier y anoche', () {
      expect(_g('230 en el súper ayer').fecha, DateTime(2026, 11, 14));
      expect(_g('antier gasté 80 de café').fecha, DateTime(2026, 11, 13));
      expect(_g('anoche 400 en salidas').fecha, DateTime(2026, 11, 14));
      expect(_g('230 en el súper ayer').fechaDicha, isTrue);
    });

    test('un día de la semana es el más reciente antes de hoy', () {
      expect(_g('el lunes 300 de gasolina').fecha, DateTime(2026, 11, 9));
      expect(_g('500 en salidas el viernes').fecha, DateTime(2026, 11, 13));
      expect(_g('el sábado 100 de café').fecha, DateTime(2026, 11, 14));
      // Hoy es domingo: "el domingo" es el de la semana pasada.
      expect(_g('el domingo pasado 100 de café').fecha, DateTime(2026, 11, 8));
    });

    test('el día del mes, con o sin mes', () {
      expect(_g('el 12 gasté 300 en el súper').fecha, DateTime(2026, 11, 12));
      expect(_g('300 de gasolina el 3 de noviembre').fecha, DateTime(2026, 11, 3));
      expect(_g('el día 20 pagué 200 de café').fecha, DateTime(2026, 10, 20), reason: 'el 20 aún no llega: el del mes pasado');
      expect(_g('el primero de octubre 90 de café').fecha, DateTime(2026, 10, 1));
    });

    test('el número de la fecha no se toma como monto', () {
      final g = _g('el 12 gasté 300 en el súper');
      expect(g.monto, const Dinero.pesos(300));
      expect(g.montosDichos, [const Dinero.pesos(300)]);
    });

    test('"el 7 eleven" no es una fecha', () {
      final g = _g('45 en el 7 eleven');
      expect(g.fechaDicha, isFalse);
      expect(g.montosDichos, contains(const Dinero.pesos(45)));
    });

    test('nada a futuro ni de hace más de 62 días', () {
      final viejo = _g('el 3 de marzo 200 de café');
      expect(viejo.fechaDicha, isFalse);
      expect(viejo.fecha, DateTime(2026, 11, 15));
      expect(viejo.monto, const Dinero.pesos(200), reason: 'el 3 se quitó: no es el monto');
    });
  });

  group('cuenta', () {
    test('la de omisión si no se dice', () {
      final g = _g('230 en el súper');
      expect(g.cuentaId, 'bbva');
      expect(g.cuentaDicha, isFalse);
    });

    test('por su nombre o una palabra que solo ella tiene', () {
      expect(_g('230 en el súper con la Santander').cuentaId, 'santander');
      expect(_g('pagué 500 de gasolina con la banamex').cuentaId, 'banamex');
      expect(_g('230 en el súper con mi tarjeta Banamex platino').cuentaId, 'banamex');
    });

    test('por su tipo: efectivo, crédito, tarjeta', () {
      expect(_g('80 de café en efectivo').cuentaId, 'efectivo');
      expect(_g('400 en salidas con la de crédito').cuentaId, 'banamex');
      expect(_g('400 en salidas con tarjeta').cuentaId, 'bbva', reason: 'la de omisión ya es tarjeta');
    });

    test('la cuenta no ensucia la descripción', () {
      final g = _g('pagué 500 de gasolina con la banamex');
      expect(g.descripcion, 'Gasolina');
      expect(g.categoriaId, 'gasolina');
    });
  });

  group('categoría y descripción', () {
    test('por su nombre en la frase', () {
      final g = _g('230 en el súper');
      expect(g.categoriaId, 'super');
      expect(g.descripcion, 'Súper');
    });

    test('por las reglas del usuario y el historial de comercios', () {
      expect(_g('45 en el oxxo').categoriaId, 'cafe');
      expect(_g('600 en pemex').categoriaId, 'gasolina');
    });

    test('sin pista, sin categoría (se pregunta)', () {
      final g = _g('300 en la farmacia del ahorro');
      expect(g.categoriaId, isNull);
      expect(g.descripcion, 'Farmacia ahorro');
    });

    test('una categoría archivada no se usa', () {
      expect(_g('500 de ropa').categoriaId, isNull);
    });

    test('frase completa de Siri', () {
      final g = _g('ayer gasté 1,250.50 en el súper con la Santander');
      expect(g.monto, const Dinero(125050));
      expect(g.categoriaId, 'super');
      expect(g.cuentaId, 'santander');
      expect(g.fecha, DateTime(2026, 11, 14));
      expect(g.completo, isTrue);
    });
  });

  group('casos de borde', () {
    ContextoDictado otro({required DateTime hoy, String? omision, List<Cuenta>? cuentas}) => ContextoDictado(
          categorias: _ctx.categorias,
          cuentas: cuentas ?? _ctx.cuentas,
          cuentaPorOmision: omision,
          hoy: hoy,
        );

    test('en enero, "el 20" es de diciembre del año pasado', () {
      final g = interpretarFraseGasto('el 20 gasté 90 de café', otro(hoy: DateTime(2027, 1, 5)));
      expect(g.fecha, DateTime(2026, 12, 20));
    });

    test('efectivo y débito por su tipo aunque se llamen distinto', () {
      final cuentas = [
        _cuenta('cartera', 'Cartera', TipoCuenta.efectivo),
        _cuenta('nomina', 'Nómina HSBC', TipoCuenta.debito),
        _cuenta('amex', 'Amex', TipoCuenta.credito),
      ];
      final ctx = otro(hoy: _hoy, cuentas: cuentas, omision: 'cartera');
      expect(interpretarFraseGasto('80 de café en efectivo', ctx).cuentaId, 'cartera');
      expect(interpretarFraseGasto('80 de café con la de débito', ctx).cuentaId, 'nomina');
      // La de omisión es efectivo: "con tarjeta" es la primera tarjeta.
      expect(interpretarFraseGasto('80 de café con tarjeta', ctx).cuentaId, 'nomina');
      // Sin cuentas de ese tipo, no se toma.
      final soloCredito = otro(hoy: _hoy, cuentas: [cuentas.last]);
      expect(interpretarFraseGasto('80 de café en efectivo', soloCredito).cuentaDicha, isFalse);
      expect(interpretarFraseGasto('80 de café con la de débito', soloCredito).cuentaDicha, isFalse);
    });

    test('sin cuentas, sin cuenta', () {
      final g = interpretarFraseGasto('80 de café', otro(hoy: _hoy, cuentas: const []));
      expect(g.cuentaId, isNull);
    });

    test('artículos sueltos al final no quedan en la descripción', () {
      expect(_g('200 de tacos con los').descripcion, 'Tacos');
    });

    test('copyWith sin cambios conserva todo', () {
      final g = _g('230 en el súper ayer');
      expect(g.copyWith().toJson(), g.toJson());
    });
  });

  group('categoriaPorNombre', () {
    test('exacta, sin acentos, por una de sus partes o parecida', () {
      expect(categoriaPorNombre('salidas', _ctx.categorias)?.id, 'salidas');
      expect(categoriaPorNombre('CAFE', _ctx.categorias)?.id, 'cafe');
      expect(categoriaPorNombre('súper', _ctx.categorias)?.id, 'super');
      expect(categoriaPorNombre('comida', _ctx.categorias)?.id, 'super');
      expect(categoriaPorNombre('Súper/Comida', _ctx.categorias)?.id, 'super');
      expect(categoriaPorNombre('la gasolina', _ctx.categorias)?.id, 'gasolina');
    });

    test('nada, archivada o vacía', () {
      expect(categoriaPorNombre('Viajes', _ctx.categorias), isNull);
      expect(categoriaPorNombre('Ropa', _ctx.categorias), isNull);
      expect(categoriaPorNombre('', _ctx.categorias), isNull);
    });
  });

  group('completarConIA', () {
    test('pone la categoría si las reglas no la resolvieron', () {
      final g = completarConIA(_g('300 en la farmacia del ahorro'), 'Salud', _ctx);
      expect(g.categoriaId, 'salud');
      expect(g.descripcion, 'Farmacia ahorro', reason: 'la descripción sigue siendo de las reglas');
      expect(g.deIA, {DatoGasto.categoria});
      expect(g.completo, isTrue);
    });

    test('solo una categoría activa que exista; "Ninguna" no cuenta', () {
      expect(completarConIA(_g('300 en la farmacia'), 'Medicinas', _ctx).categoriaId, isNull);
      expect(completarConIA(_g('300 en la tienda'), 'Ropa', _ctx).categoriaId, isNull);
      expect(completarConIA(_g('300 en la tienda'), ningunaCategoria, _ctx).categoriaId, isNull);
      expect(completarConIA(_g('300 en la tienda'), null, _ctx).categoriaId, isNull);
    });

    test('no cambia lo que las reglas ya resolvieron', () {
      final g = completarConIA(_g('230 en el súper'), 'Salidas', _ctx);
      expect(g.categoriaId, 'super');
      expect(g.deIA, isEmpty);
    });

    test('sin descripción, la de la categoría', () {
      final vacia = GastoEntendido(
        frase: '230',
        monto: const Dinero.pesos(230),
        montosDichos: const [Dinero.pesos(230)],
        descripcion: '',
        categoriaId: null,
        cuentaId: 'bbva',
        fecha: DateTime(2026, 11, 15),
      );
      expect(completarConIA(vacia, 'Salidas', _ctx).descripcion, 'Salidas');
    });

    test('no completa el monto: dos números se preguntan', () {
      final g = completarConIA(_g('doce tacos de treinta pesos'), 'Salidas', _ctx);
      expect(g.monto, isNull);
      expect(g.completo, isFalse);
    });
  });

  test('ida y vuelta en JSON (lo que viaja por Siri)', () {
    final g = completarConIA(_g('doce tacos de treinta pesos ayer con la banamex'), 'Salidas', _ctx);
    final otra = GastoEntendido.fromJson(g.toJson());
    expect(otra.toJson(), g.toJson());
    expect(otra.deIA, {DatoGasto.categoria});
    expect(otra.montosDichos, g.montosDichos);
    expect(otra.fechaDicha && otra.cuentaDicha, isTrue);
  });

  test('el mensaje y las opciones para la IA: solo categorías activas', () {
    final m = mensajeIAGasto('230 en el súper', _ctx);
    expect(m, 'Categorías: Súper/Comida, Salidas, Gasolina, Salud, Café.\nGasto: "230 en el súper"');
    expect(opcionesIAGasto(_ctx), ['Súper/Comida', 'Salidas', 'Gasolina', 'Salud', 'Café', ningunaCategoria]);
    expect(instruccionesIAGasto, contains('"$ningunaCategoria"'));
  });
}
