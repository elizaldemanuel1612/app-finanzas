import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/core/result.dart';
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
    expect(datos.categoriasPorCrear.single.presupuestoMensualCentavos, const Dinero.cero());
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

  test('sin columna de categoría, usa "Importado"', () {
    final datos = _ok('fecha,monto\n2026-08-05,100\n');
    expect(datos.categoriasPorCrear.single.nombre, 'Importado');
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

    test('una categoría existente con emoji propio no se toca', () {
      final datos = _ok(
        'fecha,monto,categoria,emoji\n2026-08-05,1,Súper,🍎\n',
        categorias: [_categoriaExistente('super', 'Súper')],
      );
      expect(datos.categoriasPorActualizar, isEmpty);
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
}
