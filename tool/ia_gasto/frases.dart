// Frases de prueba para el intérprete de gastos con IA (spec §5.6.3).
// Para volver a medir con Apple Intelligence en una Mac con macOS 26+:
//   dart run tool/ia_gasto/frases.dart > /tmp/entrada.json
//   swiftc -parse-as-library -O tool/ia_gasto/probar_apple.swift -o /tmp/probar
//   /tmp/probar /tmp/entrada.json > test/domain/voz/respuestas_apple.json
// `test/domain/voz/ia_apple_real_test.dart` valida esas respuestas reales
// con `completarConIA`.
import 'dart:convert';

import 'package:app_finanzas/core/money.dart';
import 'package:app_finanzas/domain/modelos/categoria.dart';
import 'package:app_finanzas/domain/modelos/cuenta.dart';
import 'package:app_finanzas/domain/voz/interpretar_gasto.dart';

CategoriaVariable _cat(String id, String nombre) => CategoriaVariable(
      id: id,
      nombre: nombre,
      emoji: '🛒',
      activa: true,
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

/// El contexto de las pruebas con la IA real: categorías y cuentas como las
/// de un usuario típico, hoy domingo 15 de noviembre de 2026.
final contextoDePrueba = ContextoDictado(
  categorias: [
    _cat('super', 'Super/Comida'),
    _cat('salidas', 'Salidas'),
    _cat('gasolina', 'Gasolina'),
    _cat('salud', 'Salud'),
    _cat('limpieza', 'Limpieza'),
    _cat('ropa', 'Ropa'),
    _cat('transporte', 'Transporte'),
    _cat('suscripciones', 'Suscripciones'),
    _cat('regalos', 'Regalos'),
    _cat('mascotas', 'Mascotas'),
  ],
  cuentas: [
    _cuenta('bbva', 'BBVA', TipoCuenta.debito),
    _cuenta('banamex', 'Banamex platino', TipoCuenta.credito),
    _cuenta('efectivo', 'Efectivo', TipoCuenta.efectivo),
    _cuenta('nu', 'Nu', TipoCuenta.credito),
  ],
  cuentaPorOmision: 'bbva',
  hoy: DateTime(2026, 11, 15, 10),
);

/// Cada frase con la categoría que debe quedar (`null`: ninguna).
const frasesDePrueba = <(String, String?)>[
  ('230 en el súper', 'super'),
  ('me gasté como doscientos en unos tacos', 'salidas'),
  ('cargué gasolina 800 pesos', 'gasolina'),
  ('el uber al aeropuerto 350', 'transporte'),
  ('pagué netflix 299', 'suscripciones'),
  ('compré croquetas para el perro 640', 'mascotas'),
  ('fui a la farmacia y gasté 180', 'salud'),
  ('unos tenis de 1,899 en liverpool', 'ropa'),
  ('el regalo de mi mamá 1500 con la nu', 'regalos'),
  ('ayer en el cine gastamos 420', 'salidas'),
  ('cloro y jabón 95 en efectivo', 'limpieza'),
  ('dos cafés de 65', 'salidas'),
  ('el estacionamiento 40', 'transporte'),
  ('spotify 129 con la banamex', 'suscripciones'),
  ('la consulta del dentista 900', 'salud'),
  ('una pizza para la cena 289 el viernes', 'salidas'),
  ('pagué 350 de didi', 'transporte'),
  ('compré fruta y verdura en el mercado 210', 'super'),
  ('la vacuna del gato 450 con la de crédito', 'mascotas'),
  ('la semana pasada unos jeans 799', 'ropa'),
  ('mil doscientos cincuenta en walmart', 'super'),
  ('una cerveza en el bar 120', 'salidas'),
  ('un taxi a la casa 180', 'transporte'),
  ('detergente para la ropa 160', 'limpieza'),
];

void main() {
  final ctx = contextoDePrueba;
  // ignore: avoid_print
  print(const JsonEncoder.withIndent('  ').convert({
    'instrucciones': instruccionesIAGasto,
    'opciones': opcionesIAGasto(ctx),
    'frases': [
      for (final (frase, _) in frasesDePrueba) {'frase': frase, 'mensaje': mensajeIAGasto(frase, ctx)},
    ],
  }));
}
