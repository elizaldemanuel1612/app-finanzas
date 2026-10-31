import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
import 'package:app_finanzas/domain/clasificacion/regla_aprendida.dart';
import 'package:app_finanzas/domain/importacion/importar_movimientos.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/estado_movimiento.dart';
import 'package:app_finanzas/domain/modelos/movimiento.dart';
import 'package:test/test.dart';

const _calculadora = CalculadoraCiclo(1);

CategoriaVariable _categoriaExistente(String id, String nombre) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🛒',
      activa: true,
      esNecesaria: false,
      presupuestoMensualCentavos: const Dinero.pesos(1000),
    );

ResultadoImportacion _ok(String csv, {List<Categoria> categorias = const []}) {
  final r = previsualizarImportacion(
    contenidoCsv: csv,
    calculadoraCiclo: _calculadora,
    categoriasExistentes: categorias,
  );
  return (r as Exito<ResultadoImportacion>).valor;
}

void main() {
  test('archivo vacío falla', () {
    final r = previsualizarImportacion(
      contenidoCsv: '',
      calculadoraCiclo: _calculadora,
      categoriasExistentes: const [],
    );
    expect(r.esFalla, isTrue);
  });

  test('sin columnas de fecha ni monto falla', () {
    final r = previsualizarImportacion(
      contenidoCsv: 'a,b\n1,2\n',
      calculadoraCiclo: _calculadora,
      categoriasExistentes: const [],
    );
    expect(r.esFalla, isTrue);
  });

  test('renglones en blanco se saltan sin reportarse como problema', () {
    final datos = _ok('fecha,monto\n2026-08-05,100\n\n2026-08-06,200\n');
    expect(datos.movimientos, hasLength(2));
    expect(datos.renglonesConProblema, isEmpty);
  });

  test('fecha no reconocida se reporta como problema con el número de renglón', () {
    final datos = _ok('fecha,monto\nno-es-fecha,100\n');
    expect(datos.movimientos, isEmpty);
    expect(datos.renglonesConProblema, hasLength(1));
    expect(datos.renglonesConProblema.first.numeroDeRenglon, 2);
    expect(datos.renglonesConProblema.first.motivo, contains('fecha'));
  });

  test('monto no parseable se reporta como problema', () {
    final datos = _ok('fecha,monto\n2026-08-05,no-es-monto\n');
    expect(datos.movimientos, isEmpty);
    expect(datos.renglonesConProblema.single.motivo, contains('monto'));
  });

  test('monto en cero se reporta como problema (vía crearMovimientoMigrado)', () {
    final datos = _ok('fecha,monto\n2026-08-05,0\n');
    expect(datos.movimientos, isEmpty);
    expect(datos.renglonesConProblema, hasLength(1));
  });

  test('fecha en formato dd/mm/aaaa', () {
    final datos = _ok('fecha,monto\n05/08/2026,100\n');
    expect(datos.movimientos.single.fecha, DateTime(2026, 8, 5));
  });

  test('fecha en formato ISO aaaa-mm-dd', () {
    final datos = _ok('fecha,monto\n2026-08-05,100\n');
    expect(datos.movimientos.single.fecha, DateTime(2026, 8, 5));
  });

  test('mes fuera de rango en dd/mm/aaaa se reporta como problema', () {
    final datos = _ok('fecha,monto\n05/13/2026,100\n');
    expect(datos.movimientos, isEmpty);
    expect(datos.renglonesConProblema, hasLength(1));
  });

  test('monto tolera símbolo de peso y espacios', () {
    // El monto va entre comillas porque trae una coma embebida (RFC 4180):
    // sin comillas, la coma partiría el CSV en dos columnas.
    final datos = _ok('fecha,monto\n2026-08-05,"\$ 1,234.56"\n');
    expect(datos.movimientos.single.monto, const Dinero(123456));
  });

  test('categoría que no existe se agrega a categoriasPorCrear con presupuesto cero', () {
    final datos = _ok('fecha,monto,categoria\n2026-08-05,100,Mascotas\n');
    expect(datos.categoriasPorCrear, hasLength(1));
    expect(datos.categoriasPorCrear.single.nombre, 'Mascotas');
    expect((datos.categoriasPorCrear.single as CategoriaVariable).presupuestoMensualCentavos, const Dinero.cero());
    expect(datos.movimientos.single.categoriaId, datos.categoriasPorCrear.single.id);
  });

  test('categoría que ya existe (mismo nombre) se reutiliza, no se duplica', () {
    final existente = _categoriaExistente('cat-super', 'Súper');
    final datos = _ok(
      'fecha,monto,categoria\n2026-08-05,100,súper\n',
      categorias: [existente],
    );
    expect(datos.categoriasPorCrear, isEmpty);
    expect(datos.movimientos.single.categoriaId, 'cat-super');
  });

  test('dos renglones con el mismo nombre de categoría nueva solo la crean una vez', () {
    final datos = _ok(
      'fecha,monto,categoria\n2026-08-05,100,Mascotas\n2026-08-06,200,mascotas\n',
    );
    expect(datos.categoriasPorCrear, hasLength(1));
    expect(datos.movimientos[0].categoriaId, datos.movimientos[1].categoriaId);
  });

  test('sin columna de categoría ni forma de adivinarla, va a "Sin categoría"', () {
    final datos = _ok('fecha,monto\n2026-08-05,100\n');
    expect(datos.categoriasPorCrear.single.nombre, categoriaSinCategoria);
    expect(datos.sinCategoria, 1);
  });

  test('descripción vacía usa el nombre de la categoría', () {
    final datos = _ok('fecha,monto,categoria\n2026-08-05,100,Súper\n');
    expect(datos.movimientos.single.descripcion, 'Súper');
  });

  test('medio "efectivo" se reconoce; cualquier otro texto cae en tarjeta', () {
    final datos = _ok(
      'fecha,monto,medio\n2026-08-05,100,Efectivo\n2026-08-06,100,Crédito\n2026-08-07,100,\n',
    );
    expect(datos.movimientos[0].medio, MedioPago.efectivo);
    expect(datos.movimientos[1].medio, MedioPago.tarjeta);
    expect(datos.movimientos[2].medio, MedioPago.tarjeta);
  });

  test('totalesPorCiclo agrega por cicloId', () {
    final datos = _ok('fecha,monto\n2026-01-05,100\n2026-01-15,200\n2026-02-05,50\n');
    expect(datos.totalesPorCiclo.values.fold(const Dinero.cero(), (a, b) => a + b), const Dinero.pesos(350));
    expect(datos.totalesPorCiclo.length, 2);
  });

  test('reimportar el mismo archivo produce los mismos clientId (no duplica)', () {
    const csv = 'fecha,monto\n2026-08-05,100\n2026-08-06,200\n';
    final primera = _ok(csv);
    final segunda = _ok(csv);
    expect(
      primera.movimientos.map((m) => m.clientId).toList(),
      segunda.movimientos.map((m) => m.clientId).toList(),
    );
  });

  test('dos archivos con contenido distinto no colisionan en clientId', () {
    final a = _ok('fecha,monto\n2026-08-05,100\n');
    final b = _ok('fecha,monto\n2026-08-05,200\n');
    expect(a.movimientos.single.clientId, isNot(b.movimientos.single.clientId));
  });

  test('huellaEstable es determinista y distingue contenidos distintos', () {
    expect(huellaEstable('hola'), huellaEstable('hola'));
    expect(huellaEstable('hola'), isNot(huellaEstable('adios')));
  });

  test('RenglonConProblema.toString describe el renglón y el motivo', () {
    final datos = _ok('fecha,monto\nno-es-fecha,100\n');
    expect(datos.renglonesConProblema.single.toString(), contains('Renglón 2'));
  });

  group('formato de ida y vuelta (2026-10-29)', () {
    test('estado: etiquetas, nombres internos y sinónimos', () {
      final datos = _ok('fecha,monto,estado\n'
          '2026-08-05,1,Activo\n2026-08-05,2,anulado\n2026-08-05,3,Cancelado\n'
          '2026-08-05,4,Pendiente\n2026-08-05,5,propuesto\n2026-08-05,6,\n2026-08-05,7,pagado\n');
      expect([for (final m in datos.movimientos) m.estado], [
        EstadoMovimiento.activo,
        EstadoMovimiento.anulado,
        EstadoMovimiento.anulado,
        EstadoMovimiento.propuesto,
        EstadoMovimiento.propuesto,
        EstadoMovimiento.activo,
        EstadoMovimiento.activo,
      ]);
      expect(datos.avisos, isEmpty);
      expect(datos.anulados, 2);
    });

    test('estado desconocido no tumba el renglón: se importa activo con aviso', () {
      final datos = _ok('fecha,monto,estado\n2026-08-05,100,quién sabe\n');
      expect(datos.movimientos.single.estado, EstadoMovimiento.activo);
      expect(datos.renglonesConProblema, isEmpty);
      expect(datos.avisos.single.numeroDeRenglon, 2);
      expect(datos.avisos.single.motivo, contains('quién sabe'));
    });

    test('lo anulado y lo pendiente no suman al total del ciclo', () {
      final datos = _ok('fecha,monto,estado\n2026-08-05,100,Anulado\n2026-08-05,40,Pendiente\n2026-08-06,25,\n');
      expect(datos.totalesPorCiclo.values.single, const Dinero.pesos(25));
    });

    test('medio: sinónimos de tarjeta y aviso si no se reconoce', () {
      final datos = _ok('fecha,monto,medio\n2026-08-05,1,Crédito\n2026-08-05,2,TDD\n2026-08-05,3,vales\n');
      expect([for (final m in datos.movimientos) m.medio], everyElement(MedioPago.tarjeta));
      expect(datos.avisos.single.motivo, contains('vales'));
    });

    test('cómo se registró: etiqueta o nombre interno; si no, Importado', () {
      final datos = _ok('fecha,monto,como se registro\n2026-08-05,1,Voz\n2026-08-05,2,ticket\n'
          '2026-08-05,3,Importado\n2026-08-05,4,otro\n');
      expect([for (final m in datos.movimientos) m.origenCaptura], [
        OrigenCaptura.voz,
        OrigenCaptura.ticket,
        OrigenCaptura.migracion,
        OrigenCaptura.migracion,
      ]);
    });

    test('la columna ID es el clientId; repetida en el archivo, el segundo usa la huella', () {
      final datos = _ok('fecha,monto,id\n2026-08-05,1,abc\n2026-08-05,2,abc\n2026-08-05,3,\n');
      expect(datos.movimientos[0].clientId, 'abc');
      expect(datos.movimientos[1].clientId, startsWith('IMP-'));
      expect(datos.movimientos[2].clientId, startsWith('IMP-'));
      expect(datos.avisos.single.numeroDeRenglon, 3);
    });

    test('emoji: columna, pegado al nombre o sugerido por el nombre', () {
      final datos = _ok('fecha,monto,categoria,emoji\n'
          '2026-08-05,1,Cine,🎟️\n2026-08-05,2,🐶 Perro\n2026-08-05,3,Super/Comida,\n'
          '2026-08-05,4,Varios,\n');
      expect([for (final c in datos.categoriasPorCrear) '${c.emoji} ${c.nombre}'], [
        '🎟️ Cine',
        '🐶 Perro',
        '🛒 Super/Comida',
        '🏷️ Varios',
      ]);
    });

    test('una categoría existente con el 📥 de antes recibe su emoji, una sola vez', () {
      const vieja = CategoriaVariable(
        id: 'imp-super',
        nombre: 'Super/Comida',
        emoji: '📥',
        activa: true,
        esNecesaria: false,
        presupuestoMensualCentavos: Dinero.cero(),
      );
      final datos = _ok(
        'fecha,monto,categoria\n2026-08-05,1,Super/Comida\n2026-08-06,2,super/comida\n',
        categorias: const [vieja],
      );
      expect(datos.categoriasPorCrear, isEmpty);
      expect(datos.categoriasPorActualizar.single.emoji, '🛒');
      expect(datos.categoriasPorActualizar.single.id, 'imp-super');
      expect(datos.movimientos.map((m) => m.categoriaId), everyElement('imp-super'));
    });

    test('el emoji del archivo gana; sin él, la existente conserva el suyo', () {
      final categorias = [_categoriaExistente('super', 'Súper')];
      expect(
        _ok('fecha,monto,categoria,emoji\n2026-08-05,1,Súper,🍎\n', categorias: categorias)
            .categoriasPorActualizar
            .single
            .emoji,
        '🍎',
      );
      expect(
        _ok('fecha,monto,categoria\n2026-08-05,1,Súper\n', categorias: categorias).categoriasPorActualizar,
        isEmpty,
      );
    });

    test('fechas como las reescribe Excel: dd/mm/aa, guiones y con hora', () {
      final datos = _ok('fecha,monto\n05/08/26,1\n05-08-2026 14:30,2\n2026-08-05 09:15,3\n05/08/2026 7:05:59,4\n');
      expect([for (final m in datos.movimientos) m.fecha], [
        DateTime(2026, 8, 5),
        DateTime(2026, 8, 5, 14, 30),
        DateTime(2026, 8, 5, 9, 15),
        DateTime(2026, 8, 5, 7, 5),
      ]);
    });

    test('fecha en UTC se pasa a hora local', () {
      final datos = _ok('fecha,monto\n2026-08-05T18:00:00Z,1\n');
      final esperado = DateTime.utc(2026, 8, 5, 18).toLocal();
      expect(datos.movimientos.single.fecha,
          DateTime(esperado.year, esperado.month, esperado.day, esperado.hour, esperado.minute));
    });

    test('hora fuera de rango en dd/mm/aaaa es un problema', () {
      final datos = _ok('fecha,monto\n05/08/2026 25:00,1\n');
      expect(datos.renglonesConProblema, hasLength(1));
    });

    test('monto con MXN', () {
      final datos = _ok('fecha,monto\n2026-08-05,450.50 MXN\n');
      expect(datos.movimientos.single.monto, Dinero(45050));
    });

    test('CSV con punto y coma (Excel en otros idiomas)', () {
      final datos = _ok('Fecha;Monto;Categoría\n2026-08-05;1,250.00;Súper\n');
      expect(datos.movimientos.single.monto, const Dinero.pesos(1250));
      expect(datos.categoriasPorCrear.single.nombre, 'Súper');
    });

    test('la comilla de seguridad de la exportación se quita al leer', () {
      final datos = _ok("fecha,monto,descripcion\n2026-08-05,1,'=algo\n");
      expect(datos.movimientos.single.descripcion, '=algo');
    });
  });

  group('categoría vacía: se adivina por la descripción', () {
    ResultadoImportacion importar(
      String csv, {
      List<ReglaAprendida> reglas = const [],
      Map<String, String> historial = const {},
    }) =>
        (previsualizarImportacion(
          contenidoCsv: csv,
          calculadoraCiclo: _calculadora,
          categoriasExistentes: [_categoriaExistente('super', 'Súper'), _categoriaExistente('auto', 'Auto')],
          reglasUsuario: reglas,
          historialComercios: historial,
        ) as Exito<ResultadoImportacion>)
            .valor;

    test('con una regla del usuario (Nivel 1)', () {
      final datos = importar(
        'fecha,monto,categoria,descripcion\n2026-08-05,100,,Gasolina Pemex\n',
        reglas: const [ReglaAprendida(patron: 'pemex', categoriaId: 'auto', contador: 3)],
      );
      expect(datos.movimientos.single.categoriaId, 'auto');
      expect(datos.categoriasAdivinadas, 1);
      expect(datos.sinCategoria, 0);
      expect(datos.categoriasPorCrear, isEmpty);
    });

    test('con el historial de comercios de la cuenta (Nivel 2)', () {
      final datos = importar(
        'fecha,monto,categoria,descripcion\n2026-08-05,100,,OXXO\n',
        historial: const {'oxxo': 'super'},
      );
      expect(datos.movimientos.single.categoriaId, 'super');
    });

    test('un historial que apunta a una categoría que ya no existe se ignora', () {
      final datos = importar(
        'fecha,monto,categoria,descripcion\n2026-08-05,100,,Oxxo\n',
        historial: const {'oxxo': 'borrada'},
      );
      expect(datos.categoriasPorCrear.single.nombre, categoriaSinCategoria);
    });

    test('con lo que enseña el propio archivo', () {
      final datos = importar('fecha,monto,categoria,descripcion\n'
          '2026-08-05,100,,Netflix\n2026-08-06,200,🎵 Suscripciones,Netflix\n');
      expect(datos.movimientos.first.categoriaId, datos.movimientos.last.categoriaId);
      expect(datos.categoriasPorCrear.single.nombre, 'Suscripciones');
      expect(datos.categoriasAdivinadas, 1);
    });

    test('sin descripción ni pistas: "Sin categoría", contado aparte', () {
      final datos = importar('fecha,monto,categoria,descripcion\n2026-08-05,100,,\n2026-08-06,50,,Algo raro\n');
      expect(datos.sinCategoria, 2);
      expect(datos.categoriasAdivinadas, 0);
      expect(datos.categoriasPorCrear.single.nombre, categoriaSinCategoria);
    });

    test('un renglón que no se importa no cuenta como adivinado ni sin categoría', () {
      final datos = importar('fecha,monto,categoria\n2026-08-05,0,\n');
      expect(datos.sinCategoria, 0);
      expect(datos.categoriasAdivinadas, 0);
    });
  });

  group('renglones de instrucciones', () {
    test('se ignoran antes y entre los datos, conservando el número de renglón', () {
      final datos = _ok('# instrucción, con coma\nfecha,monto\n# otra\n2026-08-05,100\nmal,100\n');
      expect(datos.movimientos, hasLength(1));
      expect(datos.renglonesConProblema.single.numeroDeRenglon, 5);
    });

    test('el separador se detecta en el encabezado, no en las instrucciones', () {
      final datos = _ok('# a, b, c, d\nFecha;Monto\n2026-08-05;100\n');
      expect(datos.movimientos.single.monto, const Dinero.pesos(100));
    });

    test('solo instrucciones es un archivo vacío', () {
      final r = previsualizarImportacion(
        contenidoCsv: '# nada\n',
        calculadoraCiclo: _calculadora,
        categoriasExistentes: const [],
      );
      expect(r.esFalla, isTrue);
    });
  });

  group('el plan de cada categoría', () {
    CategoriaVariable variable(Categoria c) => c as CategoriaVariable;

    test('presupuesto, fija con día, necesaria y activa', () {
      final datos = _ok('fecha,monto,categoria,presupuesto,tipo,dia de cobro,necesaria,activa\n'
          '2026-08-05,1,Súper,"6,000.00",Variable,,Sí,Sí\n'
          '2026-08-06,1,Renta,12000,Fija,5,si,no\n');
      expect(variable(datos.categoriasFinales[0]).presupuestoMensualCentavos, const Dinero.pesos(6000));
      expect(datos.categoriasFinales[0].esNecesaria, isTrue);
      final renta = datos.categoriasFinales[1] as CategoriaFija;
      expect(renta.montoFijoCentavos, const Dinero.pesos(12000));
      expect(renta.diaDelCiclo, 5);
      expect(renta.activa, isFalse);
      expect(datos.avisos, isEmpty);
    });

    test('un renglón con fecha y monto vacíos solo declara la categoría', () {
      final datos = _ok('fecha,monto,categoria,presupuesto\n,,🎁 Regalos,500\n');
      expect(datos.movimientos, isEmpty);
      expect(datos.renglonesConProblema, isEmpty);
      expect(datos.categoriasFinales.single.nombre, 'Regalos');
      expect(datos.categoriasFinales.single.emoji, '🎁');
      expect(variable(datos.categoriasFinales.single).presupuestoMensualCentavos, const Dinero.pesos(500));
    });

    test('un renglón sin fecha, sin monto y sin categoría sigue siendo problema', () {
      expect(_ok('fecha,monto,categoria,descripcion\n,,,algo\n').renglonesConProblema, hasLength(1));
    });

    test('vacío conserva el plan de la existente, con su id', () {
      const renta = CategoriaFija(
        id: 'r',
        nombre: 'Renta',
        emoji: '🏠',
        activa: false,
        esNecesaria: true,
        montoFijoCentavos: Dinero.pesos(900),
        diaDelCiclo: 3,
      );
      final datos = _ok('fecha,monto,categoria\n2026-08-05,1,renta\n', categorias: const [renta]);
      final leida = datos.categoriasFinales.single as CategoriaFija;
      expect(leida.id, 'r');
      expect(leida.montoFijoCentavos, const Dinero.pesos(900));
      expect(leida.diaDelCiclo, 3);
      expect(leida.activa, isFalse);
      expect(leida.esNecesaria, isTrue);
      expect(datos.movimientos.single.categoriaId, 'r');
    });

    test('un presupuesto nuevo actualiza la existente', () {
      final datos = _ok(
        'fecha,monto,categoria,presupuesto\n2026-08-05,1,Súper,2500\n',
        categorias: [_categoriaExistente('super', 'Súper')],
      );
      expect(variable(datos.categoriasPorActualizar.single).presupuestoMensualCentavos, const Dinero.pesos(2500));
      expect(datos.categoriasPorCrear, isEmpty);
    });

    test('una variable existente sin presupuesto en el archivo lo conserva', () {
      final datos = _ok(
        'fecha,monto,categoria\n2026-08-05,1,Súper\n',
        categorias: [_categoriaExistente('super', 'Súper')],
      );
      expect(variable(datos.categoriasFinales.single).presupuestoMensualCentavos, const Dinero.pesos(1000));
    });

    test('valores inválidos se ignoran con aviso, sin perder el gasto', () {
      final datos = _ok('fecha,monto,categoria,presupuesto,tipo,dia de cobro,necesaria\n'
          '2026-08-05,1,X,abc,otro,99,quizá\n2026-08-05,2,Y,-5,,,\n');
      expect(datos.movimientos, hasLength(2));
      expect(datos.avisos, hasLength(5));
    });

    test('si dos renglones se contradicen gana el primero, con aviso', () {
      final datos = _ok('fecha,monto,categoria,presupuesto\n2026-08-05,1,X,100\n2026-08-06,1,X,200\n');
      expect(variable(datos.categoriasFinales.single).presupuestoMensualCentavos, const Dinero.pesos(100));
      expect(datos.avisos.single.motivo, contains('no coincide'));
    });

    test('fija sin monto queda variable; sin día usa el 1; ambos con aviso', () {
      final datos = _ok('fecha,monto,categoria,presupuesto,tipo\n'
          '2026-08-05,1,A,,Fija\n2026-08-05,1,B,100,Fijo\n');
      expect(datos.categoriasFinales[0], isA<CategoriaVariable>());
      expect((datos.categoriasFinales[1] as CategoriaFija).diaDelCiclo, 1);
      expect(datos.avisos, hasLength(2));
    });

    test('de existente variable se pasa a fija, y necesaria acepta false', () {
      final datos = _ok(
        'fecha,monto,categoria,tipo,dia de cobro,necesaria,activa\n2026-08-05,1,Súper,Fija,2,false,true\n',
        categorias: [_categoriaExistente('super', 'Súper')],
      );
      final c = datos.categoriasFinales.single as CategoriaFija;
      expect(c.montoFijoCentavos, const Dinero.pesos(1000));
      expect(c.esNecesaria, isFalse);
      expect(c.activa, isTrue);
    });
  });

  group('importar reemplaza', () {
    Movimiento previo(String clientId) => Movimiento(
          id: clientId,
          clientId: clientId,
          fecha: DateTime(2026, 1, 1),
          cicloId: 'ciclo-viejo',
          periodoNatural: '2026-01',
          monto: const Dinero.pesos(5),
          categoriaId: 'super',
          medio: MedioPago.tarjeta,
          descripcion: 'Antes',
          estado: EstadoMovimiento.activo,
          origenCaptura: OrigenCaptura.voz,
          fotoUrl: 'foto',
        );

    ResultadoImportacion importar(String csv) => (previsualizarImportacion(
          contenidoCsv: csv,
          calculadoraCiclo: _calculadora,
          categoriasExistentes: [_categoriaExistente('super', 'Súper'), _categoriaExistente('auto', 'Auto')],
          movimientosExistentes: [previo('a'), previo('b')],
        ) as Exito<ResultadoImportacion>)
            .valor;

    test('cuenta lo que se elimina: lo que no viene en el archivo', () {
      final datos = importar('fecha,monto,categoria,id\n2026-08-05,100,Súper,a\n');
      expect(datos.eliminaDatos, isTrue);
      expect(datos.movimientosPorEliminar, 1);
      expect(datos.categoriasPorEliminar.single.id, 'auto');
      expect(datos.categoriasFinales.single.id, 'super');
    });

    test('sin nada que eliminar no pide confirmar', () {
      final datos = importar('fecha,monto,categoria,id\n2026-08-05,1,Súper,a\n2026-08-05,1,Auto,b\n');
      expect(datos.eliminaDatos, isFalse);
    });

    test('mismo ID: gana el archivo, conservando ciclo, foto y origen si viene vacío', () {
      final m = importar('fecha,monto,categoria,descripcion,id\n2026-08-05,100,Auto,Nueva,a\n').movimientos.single;
      expect(m.monto, const Dinero.pesos(100));
      expect(m.categoriaId, 'auto');
      expect(m.descripcion, 'Nueva');
      expect(m.cicloId, 'ciclo-viejo');
      expect(m.fotoUrl, 'foto');
      expect(m.origenCaptura, OrigenCaptura.voz);
    });

    test('mismo ID con origen en el archivo: se usa el del archivo', () {
      final m = importar('fecha,monto,como se registro,id\n2026-08-05,100,Ticket,a\n').movimientos.single;
      expect(m.origenCaptura, OrigenCaptura.ticket);
    });
  });
}
