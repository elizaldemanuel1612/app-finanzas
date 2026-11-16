import 'package:app_finanzas/core/ciclo.dart';
import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/ia/datos_para_ia.dart';
import 'package:test/test.dart';

// spec-app-finanzas-v2.md §6.5, uso 4: el resumen que lee el asistente.

final _hoy = DateTime(2026, 11, 15, 10);
final _ciclo = const CalculadoraCiclo(12).calcularPara(_hoy);

DatosParaIA _datos({
  List<CategoriaParaIA>? categorias,
  Dinero? pasado,
  List<CuentaParaIA> cuentas = const [],
  Dinero? patrimonio,
  List<ObjetivoParaIA> objetivos = const [],
  DateTime? hoy,
}) =>
    DatosParaIA(
      hoy: hoy ?? _hoy,
      ciclo: _ciclo,
      ingreso: const Dinero.pesos(38500),
      meta: const Dinero.pesos(6000),
      categorias: categorias ??
          const [
            (nombre: 'Súper', gastado: Dinero.pesos(2300), presupuesto: Dinero.pesos(4000), fija: false),
            (nombre: 'Salidas', gastado: Dinero(190050), presupuesto: Dinero.pesos(1500), fija: false),
            (nombre: 'Café', gastado: Dinero.pesos(120), presupuesto: Dinero.cero(), fija: false),
            (nombre: 'Renta', gastado: Dinero.pesos(9000), presupuesto: Dinero.pesos(9000), fija: true),
            (nombre: 'Gimnasio', gastado: Dinero.cero(), presupuesto: Dinero.pesos(700), fija: true),
          ],
      gastadoCicloPasado: pasado,
      cuentas: cuentas,
      patrimonio: patrimonio,
      objetivos: objetivos,
    );

void main() {
  test('el resumen completo, cada cifra con su nombre', () {
    final texto = textoParaIA(_datos(
      pasado: const Dinero.pesos(28400),
      cuentas: const [
        (nombre: 'BBVA', saldo: Dinero.pesos(5200), debe: false),
        (nombre: 'Banamex platino', saldo: Dinero(-340000), debe: true),
      ],
      patrimonio: const Dinero.pesos(1800),
      objetivos: const [(nombre: 'Viaje', meta: Dinero.pesos(20000), llevas: Dinero.pesos(3000))],
    ));
    expect(texto, r'''
Hoy es 15 nov 2026.
Ciclo actual: del 12 nov 2026 al 11 dic 2026; va en el día 4 de 30 y faltan 26 días.
Ingreso del ciclo: $38,500. Meta de apartado (ahorro) del ciclo: $6,000.
Total gastado en el ciclo (todo): $13,320.50.
Gastos variables con presupuesto: $4,200.50 de $5,500; quedan $1,299.50.
Categorías variables (de mayor a menor gasto):
- Súper: gastado $2,300 de $4,000, le quedan $1,700
- Salidas: gastado $1,900.50 de $1,500, se pasó por $400.50
- Café: gastado $120, sin presupuesto
Gastos fijos (pagado de su monto):
- Renta: $9,000 de $9,000
- Gimnasio: $0 de $700 (aún sin pagar)
Ciclo pasado completo, total gastado: $28,400.
Cuentas:
- BBVA: tiene $5,200
- Banamex platino: debe $3,400
Patrimonio (lo que tiene menos lo que debe): $1,800.
Objetivos de ahorro:
- Viaje: lleva $3,000 de $20,000'''
        .trim());
  });

  test('sin presupuestos, sin fijas, sin cuentas: solo lo que hay', () {
    final texto = textoParaIA(_datos(categorias: const [
      (nombre: 'Café', gastado: Dinero.pesos(120), presupuesto: null, fija: false),
    ]));
    expect(texto, isNot(contains('con presupuesto:')));
    expect(texto, isNot(contains('Gastos fijos')));
    expect(texto, isNot(contains('Cuentas:')));
    expect(texto, isNot(contains('Patrimonio')));
    expect(texto, isNot(contains('Ciclo pasado')));
    expect(texto, contains('- Café: gastado \$120, sin presupuesto'));
  });

  test('pasarse en el total, último día y una fija sin monto', () {
    final texto = textoParaIA(_datos(
      hoy: DateTime(2026, 12, 10),
      categorias: const [
        (nombre: 'Salidas', gastado: Dinero.pesos(2000), presupuesto: Dinero.pesos(1500), fija: false),
        (nombre: 'Rara', gastado: Dinero.pesos(10), presupuesto: null, fija: true),
      ],
    ));
    expect(texto, contains(r'Gastos variables con presupuesto: $2,000 de $1,500; se pasó por $500.'));
    expect(texto, contains('falta 1 día'));
    expect(texto, contains(r'- Rara: $10 de $0'));
  });

  test('con muchas categorías, solo las de más gasto', () {
    final texto = textoParaIA(_datos(categorias: [
      for (var i = 0; i < maxCategoriasParaIA + 3; i++)
        (nombre: 'Cat $i', gastado: Dinero.pesos(100 - i), presupuesto: const Dinero.pesos(500), fija: false),
    ]));
    expect(texto, contains('- Cat 0:'));
    expect(texto, isNot(contains('- Cat ${maxCategoriasParaIA + 1}:')));
    expect(texto, contains('- (y 3 más con menos gasto)'));
    expect(reglasConDatos, contains('DATOS'));
  });
}
