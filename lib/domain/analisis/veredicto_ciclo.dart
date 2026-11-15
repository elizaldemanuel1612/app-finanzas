import '../../core/money.dart';
import '../presupuesto/disponible_por_dia.dart';
import 'reporte_analisis.dart';

enum TonoVeredicto { bien, atencion, pasado, neutro }

/// La respuesta de un vistazo a "¿cómo voy?", para la vista básica de
/// Análisis (spec-app-finanzas-v2.md §5.7). En palabras de addendum-v3 §3.3:
/// dice qué significa para el usuario, sin porcentajes.
final class VeredictoCiclo {
  final TonoVeredicto tono;
  final String titulo;
  final String detalle;

  /// Lo que se puede gastar hoy; `null` si ya no hay nada que repartir.
  final Dinero? disponibleHoy;

  const VeredictoCiclo({
    required this.tono,
    required this.titulo,
    required this.detalle,
    this.disponibleHoy,
  });
}

/// Solo mira las variables: las fijas no se pronostican (regla #9).
VeredictoCiclo calcularVeredicto({required ReporteAnalisis reporte, required DateTime hoy}) {
  final r = reporte;
  final presupuesto = r.presupuestoVariables;
  // Solo lo de las categorías con presupuesto se compara (spec §7.3.6).
  final gastado = r.gastadoConPresupuesto;
  final quedanDias = r.diasRestantes > 0;

  // Un ciclo pasado se cuenta en pasado y sin "hoy puedes gastar".
  final terminado = r.terminado;

  if (!presupuesto.esPositivo) {
    return VeredictoCiclo(
      tono: TonoVeredicto.neutro,
      titulo: terminado ? 'Gastaste ${r.gastado.formateado()} en este ciclo' : 'Llevas ${r.gastado.formateado()} este ciclo',
      detalle: 'Registras sin presupuestos: aquí ves en qué se te va el dinero.',
    );
  }
  if (gastado > presupuesto) {
    return VeredictoCiclo(
      tono: TonoVeredicto.pasado,
      titulo: 'Te pasaste por ${(gastado - presupuesto).formateado()}',
      detalle: quedanDias
          ? 'En lo que queda del ciclo, procura gastar solo en lo indispensable.'
          : 'Para el próximo ciclo, revisa qué categoría se llevó más.',
    );
  }
  if (terminado) {
    return VeredictoCiclo(
      tono: TonoVeredicto.bien,
      titulo: 'Cerraste dentro de lo planeado',
      detalle: 'Te sobraron ${(presupuesto - gastado).formateado()} de tus gastos del día a día.',
    );
  }
  final disponible = calcularDisponiblePorDia(
    presupuestoVariables: presupuesto,
    gastadoVariables: gastado,
    ciclo: r.ciclo,
    hoy: hoy,
  );
  final disponibleHoy = disponible.esPositivo ? disponible : null;

  if (!quedanDias) {
    return VeredictoCiclo(
      tono: TonoVeredicto.bien,
      titulo: 'Cierras dentro de lo planeado',
      detalle: 'Te sobran ${(presupuesto - gastado).formateado()} al terminar hoy.',
      disponibleHoy: disponibleHoy,
    );
  }
  if (r.proyeccionVariables > presupuesto) {
    return VeredictoCiclo(
      tono: TonoVeredicto.atencion,
      titulo: 'Vas un poco rápido',
      detalle: 'A este ritmo te pasarías por '
          '${(r.proyeccionVariables - presupuesto).formateado()}.',
      disponibleHoy: disponibleHoy,
    );
  }
  return VeredictoCiclo(
    tono: TonoVeredicto.bien,
    titulo: 'Vas bien',
    detalle: 'A este ritmo te sobrarían ${(presupuesto - r.proyeccionVariables).formateado()}.',
    disponibleHoy: disponibleHoy,
  );
}
