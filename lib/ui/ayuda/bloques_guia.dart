import 'package:flutter/material.dart';

import '../../domain/rollups/estado_ritmo.dart';
import '../comun/barra_ritmo.dart';
import '../comun/nota_destacada.dart';
import '../comun/tema.dart';
import 'modelo_guia.dart';

/// Renderiza un [BloqueGuia]. El `switch` es exhaustivo a propósito: si se
/// agrega un caso nuevo a `BloqueGuia` en `modelo_guia.dart`, el
/// compilador obliga a dibujarlo aquí.
class BloqueGuiaWidget extends StatelessWidget {
  final BloqueGuia bloque;

  const BloqueGuiaWidget(this.bloque, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return switch (bloque) {
      Subtitulo(:final texto) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(texto, style: theme.titleMedium),
      ),
      Parrafo(:final texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(
          TextSpan(
            style: theme.bodyMedium?.copyWith(color: ColoresApp.medio),
            children: _spansConNegrita(
              texto,
              negrita: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.tinta),
            ),
          ),
        ),
      ),
      Vinetas(:final puntos) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final punto in puntos)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: theme.bodyMedium?.copyWith(color: ColoresApp.medio)),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: theme.bodyMedium?.copyWith(color: ColoresApp.medio),
                          children: _spansConNegrita(
                            punto,
                            negrita: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.tinta),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      Pasos(:final pasos) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < pasos.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: ColoresApp.azulSuave,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: theme.labelSmall?.copyWith(
                          color: ColoresApp.azul,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(pasos[i], style: theme.bodyMedium?.copyWith(color: ColoresApp.medio)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      Nota(:final etiqueta, :final texto, :final tono) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: NotaDestacada(etiqueta: etiqueta, texto: texto, tono: tono),
      ),
      Ejemplo(:final cual, :final pie) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EjemploVivo(cual),
                if (pie != null) ...[
                  const SizedBox(height: 10),
                  Text(pie, style: theme.labelSmall),
                ],
              ],
            ),
          ),
        ),
      ),
    };
  }
}

/// Versión mínima del parser de `**negrita**` de `documento_legal.dart`,
/// copiada a propósito en vez de importada: ese archivo arrastra
/// `url_launcher` y el manejo de links, que la guía no necesita.
List<InlineSpan> _spansConNegrita(String texto, {required TextStyle negrita}) {
  final regex = RegExp(r'\*\*(.+?)\*\*');
  final spans = <InlineSpan>[];
  var ultimo = 0;
  for (final m in regex.allMatches(texto)) {
    if (m.start > ultimo) spans.add(TextSpan(text: texto.substring(ultimo, m.start)));
    spans.add(TextSpan(text: m.group(1), style: negrita));
    ultimo = m.end;
  }
  if (ultimo < texto.length) spans.add(TextSpan(text: texto.substring(ultimo)));
  return spans;
}

class _EjemploVivo extends StatelessWidget {
  final EjemploGuia cual;

  const _EjemploVivo(this.cual);

  @override
  Widget build(BuildContext context) {
    return switch (cual) {
      EjemploGuia.barraVasBien => const BarraRitmo(
        porcentajeUsado: 0.35,
        avanceCiclo: 0.5,
        estado: EstadoRitmo.vaBien,
        descripcion: 'este ejemplo',
      ),
      EjemploGuia.barraExcedido => const BarraRitmo(
        porcentajeUsado: 1.0,
        avanceCiclo: 0.5,
        estado: EstadoRitmo.excedido,
        descripcion: 'este ejemplo',
      ),
      EjemploGuia.barraProyeccion => const BarraRitmo(
        porcentajeUsado: 0.62,
        avanceCiclo: 0.5,
        estado: EstadoRitmo.justo,
        descripcion: 'este ejemplo',
        vaMuyRapido: true,
      ),
      EjemploGuia.tarjetaAtencion => const _TarjetaAtencionEjemplo(),
      EjemploGuia.chipsDeFecha => const _ChipsDeFechaEjemplo(),
      EjemploGuia.deslizarMovimiento => const _DeslizarMovimientoEjemplo(),
    };
  }
}

/// Miniatura del renglón de "Gastos Variables" en Inicio. La
/// pastilla de estado se redibuja aquí con `labelSmall` (12px) en vez de
/// compartirse con `pantalla_inicio.dart` (que usa 11px): un widget común
/// tendría cupo cero de tamaños sueltos en `test/estilos_ui_test.dart` y
/// forzaría subir Inicio a 12px, cambiando cómo se ve esa pantalla por
/// algo que aquí nadie nota.
class _TarjetaAtencionEjemplo extends StatelessWidget {
  const _TarjetaAtencionEjemplo();

  @override
  Widget build(BuildContext context) {
    const estado = EstadoRitmo.excedido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Text('🛒', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Súper',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: colorEstadoRitmo(estado).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                etiquetaEstadoRitmo(estado),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorTextoEstadoRitmo(estado),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const BarraRitmo(
          porcentajeUsado: 1.0,
          avanceCiclo: 0.5,
          estado: estado,
          descripcion: 'Súper, en este ejemplo',
        ),
      ],
    );
  }
}

/// Tres píldoras estáticas — deliberadamente `Container`, no `ChoiceChip`
/// con `onSelected: null`: ese se pinta deshabilitado y gris, y aquí solo
/// se quiere ilustrar cuál chip está activo.
class _ChipsDeFechaEjemplo extends StatelessWidget {
  const _ChipsDeFechaEjemplo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget pildora(String texto, {required bool activa}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activa ? ColoresApp.azul : ColoresApp.azulSuave,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          texto,
          style: theme.labelSmall?.copyWith(
            color: activa ? Colors.white : ColoresApp.azul,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        pildora('Hoy', activa: true),
        pildora('Ayer', activa: false),
        pildora('📅 Otro día', activa: false),
      ],
    );
  }
}

/// Dos renglones ilustrativos del gesto de deslizar en Movimientos — no un
/// `Dismissible` real: ese requiere el gesto de arrastre para verse, algo
/// que una captura estática no puede mostrar.
class _DeslizarMovimientoEjemplo extends StatelessWidget {
  const _DeslizarMovimientoEjemplo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget renglon({
      required Color color,
      required IconData icono,
      required String accion,
      required String detalle,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icono, color: ColoresApp.tinta),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accion, style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(detalle, style: theme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        renglon(
          color: ColoresApp.coralSuave,
          icono: Icons.delete_outline,
          accion: 'Deslizar a la izquierda',
          detalle: 'Elimina el movimiento (lo anula)',
        ),
        renglon(
          color: ColoresApp.verdeSuave,
          icono: Icons.copy_all_outlined,
          accion: 'Deslizar a la derecha',
          detalle: 'Lo duplica con la fecha de hoy',
        ),
      ],
    );
  }
}
