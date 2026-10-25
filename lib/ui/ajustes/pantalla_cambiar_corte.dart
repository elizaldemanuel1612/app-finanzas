import 'package:flutter/material.dart';

import '../../data/repositorios/perfil_repositorio.dart';
import '../../domain/ciclo_de_vida/cambio_de_corte.dart';
import '../../domain/modelos/perfil.dart';
import '../comun/formato_fecha.dart';
import '../comun/tema.dart';

/// Cambiar el día de corte sin descuadrar el historial
/// (spec-app-finanzas-v2.md §2.4). La pantalla nunca aplica nada sola: le
/// enseña al usuario las dos formas de hacer la transición — con fechas y
/// duración — y él elige.
class PantallaCambiarCorte extends StatefulWidget {
  final Perfil perfil;
  final PerfilRepositorio perfilRepositorio;

  const PantallaCambiarCorte({
    super.key,
    required this.perfil,
    required this.perfilRepositorio,
  });

  @override
  State<PantallaCambiarCorte> createState() => _PantallaCambiarCorteState();
}

class _PantallaCambiarCorteState extends State<PantallaCambiarCorte> {
  late final DateTime _hoy = DateTime.now();
  late int _dia = widget.perfil.diaCorte;
  int? _opcionElegida;
  bool _guardando = false;

  PropuestaCambioDeCorte get _propuesta =>
      proponerCambioDeCorte(perfil: widget.perfil, diaNuevo: _dia, hoy: _hoy);

  void _cambiarDia(int dia) => setState(() {
        _dia = dia.clamp(1, 31);
        _opcionElegida = null;
      });

  Future<void> _guardar(PropuestaCambioDeCorte propuesta) async {
    final opciones = propuesta.opciones;
    final opcion = propuesta.esMismoDia
        ? null
        : opciones[_opcionElegida ?? opciones.indexWhere((o) => o.recomendada)];
    setState(() => _guardando = true);
    final nuevo = aplicarCambioDeCorte(perfil: widget.perfil, propuesta: propuesta, opcion: opcion);
    await widget.perfilRepositorio.guardar(nuevo);
    if (!mounted) return;
    final mensaje = opcion == null
        ? 'Listo: se canceló el cambio y tu ciclo vuelve a terminar el '
            '${fechaCorta(propuesta.cicloActual.fechaFin)}.'
        : 'Listo: este ciclo termina el ${fechaCorta(opcion.fin)} y desde el '
            '${fechaCorta(opcion.vigenteDesde)} tu corte es el día ${propuesta.diaNuevo}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final propuesta = _propuesta;
    final textos = Theme.of(context).textTheme;
    final pendiente = cambioPendiente(widget.perfil, _hoy);
    final ciclo = propuesta.cicloActual;

    return Scaffold(
      appBar: AppBar(title: const Text('Día de corte')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('¿Qué día empieza tu ciclo?', style: textos.titleMedium),
          const SizedBox(height: 4),
          Text(
            'El día de corte de tu tarjeta, o el 1 si llevas tus cuentas por mes natural.',
            style: textos.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _dia > 1 ? () => _cambiarDia(_dia - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Un día antes',
              ),
              SizedBox(
                width: 96,
                child: Text('Día $_dia', textAlign: TextAlign.center, style: textos.headlineMedium),
              ),
              IconButton(
                onPressed: _dia < 31 ? () => _cambiarDia(_dia + 1) : null,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Un día después',
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: _dia == 1 ? null : () => _cambiarDia(1),
              child: const Text('Usar mes natural (día 1)'),
            ),
          ),
          const SizedBox(height: 8),
          if (pendiente != null)
            _Aviso(
              icono: Icons.schedule,
              texto: 'Ya tienes un cambio programado: desde el '
                  '${fechaCorta(pendiente.vigenteDesde)} tu corte será el día '
                  '${pendiente.diaCorteNuevo}. Si eliges otro día, lo reemplaza.',
            ),
          const SizedBox(height: 12),
          if (propuesta.esMismoDia)
            ..._sinCambio(propuesta, textos)
          else
            ..._opciones(propuesta, textos, ciclo.fechaInicio),
          const SizedBox(height: 16),
          const _Aviso(
            icono: Icons.lock_outline,
            texto: 'Tu historial no cambia: los ciclos cerrados y los gastos que ya '
                'registraste se quedan en el ciclo donde están.',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _guardando || (propuesta.esMismoDia && !propuesta.habiaPendiente)
                ? null
                : () => _guardar(propuesta),
            child: Text(
              _guardando
                  ? 'Guardando…'
                  : !propuesta.esMismoDia
                      ? 'Cambiar al día ${propuesta.diaNuevo}'
                      : propuesta.habiaPendiente
                          ? 'Cancelar el cambio programado'
                          : 'Sin cambios',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sinCambio(PropuestaCambioDeCorte propuesta, TextTheme textos) => [
        Text(
          propuesta.habiaPendiente
              ? 'Es el día que rige hoy. Si cancelas el cambio programado, tu ciclo '
                  'vuelve a ir del ${fechaCorta(propuesta.cicloActual.fechaInicio)} al '
                  '${fechaCorta(propuesta.cicloActual.fechaFin)}.'
              : 'Ese ya es tu día de corte: tu ciclo va del '
                  '${fechaCorta(propuesta.cicloActual.fechaInicio)} al '
                  '${fechaCorta(propuesta.cicloActual.fechaFin)}.',
          style: textos.bodyMedium,
        ),
      ];

  List<Widget> _opciones(PropuestaCambioDeCorte propuesta, TextTheme textos, DateTime inicio) {
    final elegida = _opcionElegida ?? propuesta.opciones.indexWhere((o) => o.recomendada);
    return [
      Text('¿Cómo hacemos el cambio?', style: textos.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Tu ciclo actual empezó el ${fechaCorta(inicio)}. Para pasar al día '
        '${propuesta.diaNuevo} sin mover lo que ya registraste, este ciclo se '
        'acorta o se alarga una sola vez:',
        style: textos.bodySmall,
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < propuesta.opciones.length; i++)
        _TarjetaOpcion(
          opcion: propuesta.opciones[i],
          diaNuevo: propuesta.diaNuevo,
          elegida: i == elegida,
          onTap: () => setState(() => _opcionElegida = i),
        ),
      const SizedBox(height: 8),
      const _Aviso(
        icono: Icons.info_outline,
        texto: 'Tus presupuestos son por ciclo: en un ciclo largo irás más justo y '
            'en uno corto te sobrará. La barra de ritmo sí toma en cuenta los días reales.',
      ),
    ];
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final OpcionTransicion opcion;
  final int diaNuevo;
  final bool elegida;
  final VoidCallback onTap;

  const _TarjetaOpcion({
    required this.opcion,
    required this.diaNuevo,
    required this.elegida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: elegida ? ColoresApp.violetaSuave : ColoresApp.tarjeta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: elegida ? ColoresApp.violeta : ColoresApp.linea),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: ColoresApp.violeta,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Este ciclo termina el ${fechaCorta(opcion.fin)}',
                        style: textos.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${opcion.dias} días en total · el primero con día $diaNuevo '
                        'empieza el ${fechaCorta(opcion.vigenteDesde)}',
                        style: textos.bodySmall,
                      ),
                      if (opcion.recomendada) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Recomendado: el más cercano a un mes',
                          style: textos.labelSmall?.copyWith(color: ColoresApp.violeta),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.violetaSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: ColoresApp.violeta),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
