import '../../core/money.dart';
import '../../core/result.dart';
import '../modelos/categoria.dart';
import '../reglas/monto.dart';

/// Puntos de entrada para crear y editar categorías. Nunca se construye un
/// [CategoriaFija]/[CategoriaVariable] "a mano" fuera de aquí para datos
/// que vienen del usuario: los `assert` del constructor son una red para
/// errores de programación, no validación de entrada — se quitan en
/// builds de release (regla no negociable #1: los montos se validan antes
/// de construir, no se confía en el tipo por sí solo).
Resultado<CategoriaFija> crearCategoriaFija({
  required String id,
  required String nombre,
  required String emoji,
  required Dinero montoFijoCentavos,
  required int diaDelCiclo,
  bool esNecesaria = false,
  bool activa = true,
}) {
  if (id.trim().isEmpty) return const Falla('La categoría necesita un id.');
  if (nombre.trim().isEmpty) return const Falla('La categoría necesita un nombre.');

  final montoValido = validarMontoPositivo(montoFijoCentavos, etiqueta: 'monto fijo');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  if (diaDelCiclo < 1 || diaDelCiclo > 31) {
    return Falla('El día del ciclo debe estar entre 1 y 31 (recibido: $diaDelCiclo).');
  }

  return Exito(CategoriaFija(
    id: id,
    nombre: nombre,
    emoji: emoji,
    activa: activa,
    esNecesaria: esNecesaria,
    montoFijoCentavos: montoFijoCentavos,
    diaDelCiclo: diaDelCiclo,
  ));
}

Resultado<CategoriaVariable> crearCategoriaVariable({
  required String id,
  required String nombre,
  required String emoji,
  required Dinero presupuestoMensualCentavos,
  bool esNecesaria = false,
  bool activa = true,
}) {
  if (id.trim().isEmpty) return const Falla('La categoría necesita un id.');
  if (nombre.trim().isEmpty) return const Falla('La categoría necesita un nombre.');

  final montoValido =
      validarMontoPositivo(presupuestoMensualCentavos, etiqueta: 'presupuesto');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  return Exito(CategoriaVariable(
    id: id,
    nombre: nombre,
    emoji: emoji,
    activa: activa,
    esNecesaria: esNecesaria,
    presupuestoMensualCentavos: presupuestoMensualCentavos,
  ));
}

/// Cuando el monto real de un gasto fijo difiere del declarado, la app
/// pregunta si fue excepción de un mes o si actualiza el monto para los
/// siguientes ciclos — **nunca lo cambia sola** (spec-app-finanzas-v2.md
/// §1.5, app-finanzas-fijos-cierre-v6.html §3).
///
/// Si [actualizarParaSiguientesCiclos] es falso, la categoría regresa sin
/// cambios: el monto distinto de este ciclo vive únicamente en el
/// [Movimiento] correspondiente, no en la categoría.
Resultado<CategoriaFija> actualizarMontoFijo({
  required CategoriaFija categoria,
  required Dinero montoObservado,
  required bool actualizarParaSiguientesCiclos,
}) {
  final montoValido = validarMontoPositivo(montoObservado, etiqueta: 'monto fijo');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  if (!actualizarParaSiguientesCiclos) return Exito(categoria);

  return Exito(CategoriaFija(
    id: categoria.id,
    nombre: categoria.nombre,
    emoji: categoria.emoji,
    activa: categoria.activa,
    esNecesaria: categoria.esNecesaria,
    montoFijoCentavos: montoObservado,
    diaDelCiclo: categoria.diaDelCiclo,
  ));
}

/// Cambia el presupuesto mensual de una categoría variable — usada por
/// edición manual y por rebalanceo (`rebalanceo.dart`, addendum-v3 §2.5).
/// Nunca se acepta un presupuesto en cero o negativo.
Resultado<CategoriaVariable> actualizarPresupuestoVariable({
  required CategoriaVariable categoria,
  required Dinero nuevoPresupuesto,
}) {
  final montoValido = validarMontoPositivo(nuevoPresupuesto, etiqueta: 'presupuesto');
  if (montoValido case Falla(:final mensaje)) return Falla(mensaje);

  return Exito(CategoriaVariable(
    id: categoria.id,
    nombre: categoria.nombre,
    emoji: categoria.emoji,
    activa: categoria.activa,
    esNecesaria: categoria.esNecesaria,
    presupuestoMensualCentavos: nuevoPresupuesto,
  ));
}

/// Activa o desactiva cualquier categoría preservando su tipo (fija o
/// variable) y el resto de sus campos.
Categoria conActiva(Categoria categoria, bool activa) => switch (categoria) {
      CategoriaFija f => CategoriaFija(
          id: f.id,
          nombre: f.nombre,
          emoji: f.emoji,
          activa: activa,
          esNecesaria: f.esNecesaria,
          montoFijoCentavos: f.montoFijoCentavos,
          diaDelCiclo: f.diaDelCiclo,
        ),
      CategoriaVariable v => CategoriaVariable(
          id: v.id,
          nombre: v.nombre,
          emoji: v.emoji,
          activa: activa,
          esNecesaria: v.esNecesaria,
          presupuestoMensualCentavos: v.presupuestoMensualCentavos,
        ),
    };
