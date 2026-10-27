import 'package:flutter/material.dart';

import '../../core/ciclo.dart';
import '../../core/money.dart';
import '../../domain/voz/monto_hablado.dart';
import 'formato_fecha.dart';
import 'tema.dart';

/// Ingreso, gasto y diferencia agrupados arriba de Inicio, en ese orden —
/// antes la diferencia vivía hasta el final del `ListView`, exigiendo
/// scroll para ver la cifra más importante (Fase 6). También fusiona la
/// línea de fechas del ciclo con el indicador de días restantes, en vez
/// de un banner aparte.
class TarjetaResumenCiclo extends StatelessWidget {
  final Ciclo ciclo;
  final int diasParaTerminar;
  final Dinero ingreso;
  final String subtituloIngreso;
  final Dinero totalGastado;
  final Dinero disponibleParaInvertir;
  final VoidCallback onTapIngreso;

  const TarjetaResumenCiclo({
    super.key,
    required this.ciclo,
    required this.diasParaTerminar,
    required this.ingreso,
    required this.subtituloIngreso,
    required this.totalGastado,
    required this.disponibleParaInvertir,
    required this.onTapIngreso,
  });

  @override
  Widget build(BuildContext context) {
    final negativo = disponibleParaInvertir.esNegativo;
    return Card(
      child: Column(
        // Estirado: si no, la parte de arriba se encoge a su texto y queda
        // centrada (corrida a la derecha y con poca área para tocar).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTapIngreso,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ciclo del ${fechaCorta(ciclo.fechaInicio)} al '
                    '${fechaCorta(ciclo.fechaFin)} · '
                    '${_textoDiasRestantes(diasParaTerminar)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Este ciclo entró',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: montoEnPalabras(ingreso),
                    excludeSemantics: true,
                    child: Text(
                      ingreso.formateado(),
                      style: Theme.of(context).textTheme.displaySmall,
                      // Acotado, no fijo: mismo criterio que el resto de
                      // las cifras héroe de Inicio (Fase 6, Bloque 4.2).
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: 1.6),
                    ),
                  ),
                  Text(
                    subtituloIngreso,
                    style: TextStyle(color: ColoresApp.medio),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(etiqueta: 'Gastado', monto: totalGastado),
                    ),
                    Expanded(
                      child: _Stat(
                        etiqueta: 'Para invertir',
                        monto: disponibleParaInvertir,
                        color: negativo
                            ? ColoresApp.coralTexto
                            : ColoresApp.verdeTexto,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Apilada en [Column], nunca en [Row]: un monto que crece por escalado de
/// texto del sistema solo hace más alta la tarjeta, nunca desborda de
/// ancho (a diferencia de una etiqueta y un valor lado a lado).
class _Stat extends StatelessWidget {
  final String etiqueta;
  final Dinero monto;
  final Color? color;

  const _Stat({required this.etiqueta, required this.monto, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Semantics(
          label: montoEnPalabras(monto),
          excludeSemantics: true,
          child: Text(
            monto.formateado(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _textoDiasRestantes(int dias) => switch (dias) {
  0 => 'hoy termina',
  1 => 'falta 1 día',
  _ => 'faltan $dias días',
};
